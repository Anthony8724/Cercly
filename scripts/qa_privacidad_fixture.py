"""SQL de preparación del historial QA; nunca conecta ni ejecuta al importar.

Solo reutiliza identidades sintéticas del ensayo local. La publicación autorizada
ocurre dentro de la misma transacción que la despublicación y el historial.
No crea cuentas, cambia roles, activa guardas ni modifica reglas del servidor.
"""
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID, uuid5

LOCAL_CONTEXT = 'disposable-postgres'
PUBLISHED_MARKER = '-- QA_FIXTURE_PUBLISHED_IN_TRANSACTION'
APPLIED_MARKER = '-- QA_FIXTURE_CORRECTION_APPLIED'


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


@dataclass(frozen=True)
class Identity:
    id: str
    created_at: str

    def __post_init__(self):
        object.__setattr__(self, 'id', str(UUID(self.id)))
        stamp = datetime.fromisoformat(self.created_at.replace('Z', '+00:00'))
        if stamp.tzinfo is None:
            raise ValueError('QA_IDENTITY_TIMESTAMP_REQUIRES_TIMEZONE')


@dataclass(frozen=True)
class Fixture:
    run_id: str
    business_id: str
    reviewer: Identity
    holder: Identity
    simple_holder: Identity
    original_name: str
    context: str = LOCAL_CONTEXT

    def __post_init__(self):
        object.__setattr__(self, 'run_id', str(UUID(self.run_id)))
        object.__setattr__(self, 'business_id', str(UUID(self.business_id)))
        if self.context != LOCAL_CONTEXT:
            raise ValueError('LOCAL_ONLY')
        identities = {x.id for x in self.identities}
        if len(identities) != 3 or self.business_id in identities:
            raise ValueError('THREE_DISTINCT_QA_IDENTITIES_REQUIRED')
        if not self.original_name.startswith('[QA PRIVACIDAD] ') or len(self.original_name) > 120:
            raise ValueError('EXACT_QA_FIXTURE_NAME_REQUIRED')

    @property
    def identities(self):
        return (self.reviewer, self.holder, self.simple_holder)

    @property
    def applied_request(self):
        return str(uuid5(UUID(self.run_id), self.business_id + ':privacy-history-applied'))

    @property
    def pending_request(self):
        return str(uuid5(UUID(self.run_id), self.business_id + ':privacy-history-pending'))

    @property
    def corrected_name(self):
        return '[QA PRIVACIDAD] Nombre revisado ' + self.run_id[:8]


def actor_sql(identity):
    """Reproduce el actor autenticado con una sesión EXISTENTE, no la fabrica.

    Solo para el ejecutor SQL local con sesiones sintéticas. Nunca devuelve un JWT.
    """
    uid = literal(identity.id)
    return f"""RESET ROLE;
DO $actor$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',{uid},true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',{uid},
  'role','authenticated','session_id',(select id from auth.sessions
   where user_id={uid} order by created_at desc,id limit 1))::text,true);
 IF NOT cercly_account_private.sesion_reciente({uid}) THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='QA_RECENT_EXISTING_SESSION_REQUIRED';
 END IF;
END $actor$;
SET LOCAL ROLE authenticated;
"""


def prepare_history_sql(fixture, *, temporary_publication_authorized=False):
    """Devuelve UNA transacción; exige autorización explícita para prepararla.

    No habilita cuentas ni concede permisos. Si ya hay historial, rechaza la
    repetición antes de publicar; un fallo revierte también las auditorías nuevas.
    """
    if temporary_publication_authorized is not True:
        raise PermissionError('QA_TEMPORARY_PUBLICATION_NOT_AUTHORIZED')
    f = fixture
    run, business = literal(f.run_id), literal(f.business_id)
    reviewer, holder = literal(f.reviewer.id), literal(f.holder.id)
    ids = ','.join(literal(x.id) for x in f.identities)
    attestation = ','.join(f'({literal(x.id)}::uuid,{literal(x.created_at)}::timestamptz)'
                           for x in f.identities)
    applied, pending = literal(f.applied_request), literal(f.pending_request)
    return f"""BEGIN;
SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='45s';
DO $guard$ BEGIN
 IF current_user<>'postgres' OR current_database()<>'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='QA_FIXTURE_EXECUTOR_REJECTED';
 END IF;
 PERFORM 1 FROM auth.users WHERE id IN ({ids}) ORDER BY id FOR KEY SHARE;
 PERFORM 1 FROM public.usuarios WHERE id IN ({ids}) ORDER BY id FOR SHARE;
 PERFORM 1 FROM cercly_account_private.sujetos_qa_supresion
  WHERE usuario_id IN ({ids}) ORDER BY usuario_id FOR SHARE;
 IF (SELECT count(*) FROM auth.users a JOIN (VALUES {attestation}) v(id,created_at)
  ON a.id=v.id AND a.created_at=v.created_at
  WHERE (a.banned_until IS NULL OR a.banned_until<=clock_timestamp())
   AND a.raw_app_meta_data->'cercly_qa_privacidad'=
    jsonb_build_object('autorizada',true,'ensayo_id',{run})
   AND cercly_account_private.sujeto_qa_autorizado(a.id,{run}))<>3 THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='QA_FIXTURE_SUBJECT_ATTESTATION_FAILED';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE id={reviewer} AND rol='administrador')
  OR EXISTS(SELECT 1 FROM public.usuarios WHERE id IN ({holder},{literal(f.simple_holder.id)})
    AND rol='administrador') THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='QA_FIXTURE_ROLES_NOT_READY';
 END IF;
 PERFORM 1 FROM public.establecimientos WHERE id={business} FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.establecimientos WHERE id={business}
  AND propietario_id={reviewer} AND nombre={literal(f.original_name)}
  AND estado='aprobado' AND NOT publicable) THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='QA_FIXTURE_PRIVATE_STATE_MISMATCH';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.miembros_establecimiento
  WHERE establecimiento_id={business} AND usuario_id={holder} AND activo) THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='QA_FIXTURE_MEMBERSHIP_NOT_READY';
 END IF;
 IF EXISTS(SELECT 1 FROM public.solicitudes_establecimientos
  WHERE establecimiento_id={business} OR id IN ({applied},{pending}))
  OR EXISTS(SELECT 1 FROM public.correcciones_aplicadas WHERE establecimiento_id={business})
  OR EXISTS(SELECT 1 FROM public.auditoria_moderacion_establecimientos WHERE establecimiento_id={business}) THEN
  RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='QA_HISTORY_ALREADY_PRESENT';
 END IF;
END $guard$;
{actor_sql(f.reviewer)}
SELECT public.moderar_estado_establecimiento({business},'aprobado',true);
{PUBLISHED_MARKER}
{actor_sql(f.holder)}
INSERT INTO public.solicitudes_establecimientos
 (id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
VALUES ({applied},{holder},{business},'correccion','Texto exclusivamente ficticio del ensayo',
 jsonb_build_object('cambios',jsonb_build_object('nombre',jsonb_build_object(
  'anterior',{literal(f.original_name)},'nuevo',{literal(f.corrected_name)}))));
{actor_sql(f.reviewer)}
SELECT public.aplicar_correccion_establecimiento({applied},'Revisión ficticia de privacidad');
{APPLIED_MARKER}
{actor_sql(f.holder)}
INSERT INTO public.solicitudes_establecimientos
 (id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
VALUES ({pending},{holder},{business},'correccion','Texto ficticio pendiente de privacidad',
 jsonb_build_object('cambios',jsonb_build_object('nombre',jsonb_build_object(
  'anterior',{literal(f.corrected_name)},'nuevo','[QA PRIVACIDAD] Propuesta pendiente'))));
{actor_sql(f.reviewer)}
SELECT public.moderar_estado_establecimiento({business},'aprobado',false);
RESET ROLE;
DO $verify$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.establecimientos WHERE id={business}
   AND NOT publicable AND nombre={literal(f.corrected_name)})
  OR (SELECT count(*) FROM public.solicitudes_establecimientos WHERE establecimiento_id={business})<>2
  OR NOT EXISTS(SELECT 1 FROM public.solicitudes_establecimientos WHERE id={applied} AND estado='aprobada')
  OR NOT EXISTS(SELECT 1 FROM public.solicitudes_establecimientos WHERE id={pending} AND estado='pendiente')
  OR (SELECT count(*) FROM public.correcciones_aplicadas WHERE establecimiento_id={business})<>1
  OR (SELECT count(*) FROM public.auditoria_moderacion_establecimientos WHERE establecimiento_id={business})<>2 THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='QA_HISTORY_FINAL_STATE_MISMATCH';
 END IF;
END $verify$;
COMMIT;
"""
