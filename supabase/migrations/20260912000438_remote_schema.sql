SET local check_function_bodies = off;

CREATE TABLE "public"."categorias" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "nombre"         character varying(80)    NOT NULL,
  "icono"          character varying(50)    NOT NULL,
  "activa"         boolean                  NOT NULL DEFAULT true,
  "orden"          integer                  NOT NULL DEFAULT 0,
  "creado_en"      timestamp with time zone NOT NULL DEFAULT now(),
  "actualizado_en" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "categorias_nombre_key" UNIQUE (nombre),
  CONSTRAINT "categorias_orden_check" CHECK ((orden >= 0)),
  CONSTRAINT "categorias_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."categorias"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."establecimientos" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "propietario_id"   uuid                     NOT NULL,
  "categoria_id"     uuid                     NOT NULL,
  "nombre"           character varying(120)   NOT NULL,
  "descripcion"      character varying(1000)  NOT NULL DEFAULT ''::character varying,
  "direccion"        character varying(250)   NOT NULL,
  "latitud"          double precision         NOT NULL,
  "longitud"         double precision         NOT NULL,
  "telefono_publico" character varying(20)    NOT NULL DEFAULT ''::character varying,
  "zona_horaria"     character varying(50)    NOT NULL DEFAULT 'America/Guayaquil'::character varying,
  "creado_en"        timestamp with time zone NOT NULL DEFAULT now(),
  "actualizado_en"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "establecimientos_direccion_check" CHECK (((char_length(TRIM(BOTH FROM direccion)) >= 1) AND (char_length(TRIM(BOTH FROM direccion)) <= 250))),
  CONSTRAINT "establecimientos_latitud_check" CHECK (((latitud >= ('-90'::integer)::double precision) AND (latitud <= (90)::double precision))),
  CONSTRAINT "establecimientos_longitud_check" CHECK (((longitud >= ('-180'::integer)::double precision) AND (longitud <= (180)::double precision))),
  CONSTRAINT "establecimientos_nombre_check" CHECK (((char_length(TRIM(BOTH FROM nombre)) >= 2) AND (char_length(TRIM(BOTH FROM nombre)) <= 120))),
  CONSTRAINT "establecimientos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."establecimientos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."fotos_establecimiento" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "establecimiento_id" uuid                     NOT NULL,
  "ruta_storage"       text                     NOT NULL,
  "es_portada"         boolean                  NOT NULL DEFAULT false,
  "orden"              smallint                 NOT NULL DEFAULT 0,
  "creado_en"          timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "fotos_establecimiento_establecimiento_id_ruta_storage_key" UNIQUE (establecimiento_id, ruta_storage),
  CONSTRAINT "fotos_establecimiento_orden_check" CHECK (((orden >= 0) AND (orden <= 4))),
  CONSTRAINT "fotos_establecimiento_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."fotos_establecimiento"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."horarios_establecimiento" (
  "id"                      bigint   GENERATED ALWAYS AS IDENTITY NOT NULL,
  "establecimiento_id"      uuid     NOT NULL,
  "dia_semana"              smallint NOT NULL,
  "apertura_minutos"        smallint NOT NULL,
  "cierre_minutos"          smallint NOT NULL,
  "cierra_al_dia_siguiente" boolean  NOT NULL DEFAULT false,
  CONSTRAINT "horarios_establecimiento_apertura_minutos_check" CHECK (((apertura_minutos >= 0) AND (apertura_minutos <= 1439))),
  CONSTRAINT "horarios_establecimiento_check" CHECK (((((cierre_minutos +
CASE
    WHEN cierra_al_dia_siguiente THEN 1440
    ELSE 0
END) - apertura_minutos) >= 1) AND (((cierre_minutos +
CASE
    WHEN cierra_al_dia_siguiente THEN 1440
    ELSE 0
END) - apertura_minutos) <= 1440))),
  CONSTRAINT "horarios_establecimiento_cierre_minutos_check" CHECK (((cierre_minutos >= 0) AND (cierre_minutos <= 1439))),
  CONSTRAINT "horarios_establecimiento_dia_semana_check" CHECK (((dia_semana >= 1) AND (dia_semana <= 7))),
  CONSTRAINT "horarios_establecimiento_establecimiento_id_dia_semana_aper_key" UNIQUE (establecimiento_id, dia_semana, apertura_minutos),
  CONSTRAINT "horarios_establecimiento_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."horarios_establecimiento"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."promociones" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "establecimiento_id"  uuid                     NOT NULL,
  "titulo"              character varying(120)   NOT NULL,
  "descripcion"         character varying(1000)  NOT NULL DEFAULT ''::character varying,
  "imagen_ruta_storage" text,
  "fecha_inicio"        timestamp with time zone NOT NULL,
  "fecha_fin"           timestamp with time zone NOT NULL,
  "radio_alerta_metros" integer                  NOT NULL DEFAULT 100,
  "activa"              boolean                  NOT NULL DEFAULT true,
  "creado_en"           timestamp with time zone NOT NULL DEFAULT now(),
  "actualizado_en"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "promociones_check" CHECK ((fecha_fin > fecha_inicio)),
  CONSTRAINT "promociones_pkey" PRIMARY KEY (id),
  CONSTRAINT "promociones_radio_alerta_metros_check" CHECK (((radio_alerta_metros >= 10) AND (radio_alerta_metros <= 5000))),
  CONSTRAINT "promociones_titulo_check" CHECK (((char_length(TRIM(BOTH FROM titulo)) >= 2) AND (char_length(TRIM(BOTH FROM titulo)) <= 120)))
);

ALTER TABLE "public"."promociones"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."solicitudes_establecimientos" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "solicitante_id"     uuid                     NOT NULL,
  "establecimiento_id" uuid                     NOT NULL,
  "mensaje"            character varying(1000)  NOT NULL DEFAULT ''::character varying,
  "motivo_respuesta"   character varying(1000)  NOT NULL DEFAULT ''::character varying,
  "creado_en"          timestamp with time zone NOT NULL DEFAULT now(),
  "actualizado_en"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "solicitudes_establecimientos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."solicitudes_establecimientos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."usuarios" (
  "id"        uuid                     NOT NULL,
  "nombre"    character varying(80)    NOT NULL,
  "creado_en" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "usuarios_nombre_check" CHECK (((char_length(TRIM(BOTH FROM nombre)) >= 2) AND (char_length(TRIM(BOTH FROM nombre)) <= 80))),
  CONSTRAINT "usuarios_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."usuarios"
  ENABLE ROW LEVEL SECURITY;

CREATE TYPE "public"."estado_establecimiento" AS ENUM (
  'pendiente',
  'aprobado',
  'rechazado'
);

ALTER TABLE "public"."establecimientos"
  ADD COLUMN "estado" public.estado_establecimiento NOT NULL DEFAULT 'pendiente'::public.estado_establecimiento;

CREATE TYPE "public"."estado_solicitud" AS ENUM (
  'pendiente',
  'aprobada',
  'rechazada'
);

ALTER TABLE "public"."solicitudes_establecimientos"
  ADD COLUMN "estado" public.estado_solicitud NOT NULL DEFAULT 'pendiente'::public.estado_solicitud;

CREATE TYPE "public"."rol_usuario" AS ENUM (
  'usuario',
  'propietario',
  'administrador'
);

ALTER TABLE "public"."usuarios"
  ADD COLUMN "rol" public.rol_usuario NOT NULL DEFAULT 'usuario'::public.rol_usuario;

CREATE TYPE "public"."tipo_solicitud_establecimiento" AS ENUM (
  'reclamar',
  'acceso',
  'correccion'
);

ALTER TABLE "public"."solicitudes_establecimientos"
  ADD COLUMN "tipo" public.tipo_solicitud_establecimiento NOT NULL DEFAULT 'reclamar'::public.tipo_solicitud_establecimiento;

CREATE OR REPLACE FUNCTION public.actualizar_fecha_modificacion()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
  new.actualizado_en := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.convertir_en_propietario()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  update public.usuarios
  set rol = 'propietario'
  where id = new.propietario_id
    and rol = 'usuario';

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.crear_perfil_nuevo_usuario()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  nombre_nuevo text;
begin
  nombre_nuevo := trim(
    coalesce(
      new.raw_user_meta_data ->> 'nombre',
      split_part(new.email, '@', 1),
      'Usuario'
    )
  );

  if char_length(nombre_nuevo) < 2 then
    nombre_nuevo := 'Usuario';
  end if;

  insert into public.usuarios (
    id,
    nombre,
    rol
  )
  values (
    new.id,
    left(nombre_nuevo, 80),
    'usuario'
  );

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.es_administrador()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (
    select 1
    from public.usuarios
    where id = auth.uid()
      and rol = 'administrador'
  );
$function$;

CREATE OR REPLACE FUNCTION public.proteger_establecimiento()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
  if auth.uid() = old.propietario_id
     and not public.es_administrador() then

    if new.propietario_id <> old.propietario_id then
      raise exception 'No puedes cambiar el propietario';
    end if;

    if new.estado <> old.estado then
      raise exception 'Solo un administrador puede cambiar el estado';
    end if;

    if new.creado_en <> old.creado_en then
      raise exception 'No puedes cambiar la fecha de creación';
    end if;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.proteger_promocion()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
  if not public.es_administrador()
     and new.establecimiento_id <> old.establecimiento_id then
    raise exception 'No puedes trasladar la promoción';
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.proteger_rol_usuario()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
  if auth.uid() = old.id
     and new.rol = 'administrador'
     and old.rol <> 'administrador' then
    raise exception 'No puedes convertirte en administrador';
  end if;

  return new;
end;
$function$;

ALTER TABLE "public"."establecimientos"
  ADD CONSTRAINT "establecimientos_categoria_id_fkey" FOREIGN KEY (categoria_id) REFERENCES public.categorias(id) ON DELETE RESTRICT;

ALTER TABLE "public"."fotos_establecimiento"
  ADD CONSTRAINT "fotos_establecimiento_establecimiento_id_fkey" FOREIGN KEY (establecimiento_id) REFERENCES public.establecimientos(id) ON DELETE CASCADE;

ALTER TABLE "public"."horarios_establecimiento"
  ADD CONSTRAINT "horarios_establecimiento_establecimiento_id_fkey" FOREIGN KEY (establecimiento_id) REFERENCES public.establecimientos(id) ON DELETE CASCADE;

ALTER TABLE "public"."promociones"
  ADD CONSTRAINT "promociones_establecimiento_id_fkey" FOREIGN KEY (establecimiento_id) REFERENCES public.establecimientos(id) ON DELETE CASCADE;

ALTER TABLE "public"."solicitudes_establecimientos"
  ADD CONSTRAINT "solicitudes_establecimientos_establecimiento_id_fkey" FOREIGN KEY (establecimiento_id) REFERENCES public.establecimientos(id) ON DELETE CASCADE;

ALTER TABLE "public"."usuarios"
  ADD CONSTRAINT "usuarios_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."establecimientos"
  ADD CONSTRAINT "establecimientos_propietario_id_fkey" FOREIGN KEY (propietario_id) REFERENCES public.usuarios(id) ON DELETE RESTRICT;

ALTER TABLE "public"."solicitudes_establecimientos"
  ADD CONSTRAINT "solicitudes_establecimientos_solicitante_id_fkey" FOREIGN KEY (solicitante_id) REFERENCES public.usuarios(id) ON DELETE RESTRICT;

CREATE INDEX establecimientos_categoria_estado_idx ON public.establecimientos USING btree (categoria_id, estado);

CREATE INDEX establecimientos_propietario_idx ON public.establecimientos USING btree (propietario_id);

CREATE UNIQUE INDEX fotos_orden_unico ON public.fotos_establecimiento USING btree (establecimiento_id, orden);

CREATE INDEX promociones_establecimiento_idx ON public.promociones USING btree (establecimiento_id);

CREATE INDEX promociones_vigencia_idx ON public.promociones USING btree (activa, fecha_inicio, fecha_fin);

CREATE UNIQUE INDEX solicitud_pendiente_unica ON public.solicitudes_establecimientos USING btree (solicitante_id, establecimiento_id, tipo)
  WHERE (estado = 'pendiente'::public.estado_solicitud);

CREATE INDEX solicitudes_solicitante_idx ON public.solicitudes_establecimientos USING btree (solicitante_id);

CREATE UNIQUE INDEX una_portada_por_establecimiento ON public.fotos_establecimiento USING btree (establecimiento_id)
  WHERE (es_portada = true);

CREATE TRIGGER crear_perfil_despues_del_registro
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.crear_perfil_nuevo_usuario();

CREATE TRIGGER categorias_actualizar_fecha
  BEFORE UPDATE ON public.categorias
  FOR EACH ROW
  EXECUTE FUNCTION public.actualizar_fecha_modificacion();

CREATE TRIGGER convertir_en_propietario_trigger
  AFTER INSERT ON public.establecimientos
  FOR EACH ROW
  EXECUTE FUNCTION public.convertir_en_propietario();

CREATE TRIGGER establecimientos_actualizar_fecha
  BEFORE UPDATE ON public.establecimientos
  FOR EACH ROW
  EXECUTE FUNCTION public.actualizar_fecha_modificacion();

CREATE TRIGGER proteger_establecimiento_trigger
  BEFORE UPDATE ON public.establecimientos
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_establecimiento();

CREATE TRIGGER promociones_actualizar_fecha
  BEFORE UPDATE ON public.promociones
  FOR EACH ROW
  EXECUTE FUNCTION public.actualizar_fecha_modificacion();

CREATE TRIGGER proteger_promocion_trigger
  BEFORE UPDATE ON public.promociones
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_promocion();

CREATE TRIGGER solicitudes_actualizar_fecha
  BEFORE UPDATE ON public.solicitudes_establecimientos
  FOR EACH ROW
  EXECUTE FUNCTION public.actualizar_fecha_modificacion();

CREATE TRIGGER proteger_rol_usuario_trigger
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_rol_usuario();

CREATE POLICY "administrador gestiona categorias" ON "public"."categorias"
  FOR ALL
  TO "authenticated"
  USING (public.es_administrador())
  WITH CHECK (public.es_administrador());

CREATE POLICY "publico lee categorias activas" ON "public"."categorias"
  FOR SELECT
  TO "anon", "authenticated"
  USING (((activa = true) OR public.es_administrador()));

CREATE POLICY "lectura de establecimientos" ON "public"."establecimientos"
  FOR SELECT
  TO "anon", "authenticated"
  USING (((estado = 'aprobado'::public.estado_establecimiento) OR (propietario_id = auth.uid()) OR public.es_administrador()));

CREATE POLICY "propietario crea establecimiento pendiente" ON "public"."establecimientos"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((propietario_id = auth.uid()) AND (estado = 'pendiente'::public.estado_establecimiento)));

CREATE POLICY "propietario o administrador actualiza establecimiento" ON "public"."establecimientos"
  FOR UPDATE
  TO "authenticated"
  USING (((propietario_id = auth.uid()) OR public.es_administrador()))
  WITH CHECK (((propietario_id = auth.uid()) OR public.es_administrador()));

CREATE POLICY "propietario o administrador elimina establecimiento" ON "public"."establecimientos"
  FOR DELETE
  TO "authenticated"
  USING (((propietario_id = auth.uid()) OR public.es_administrador()));

CREATE POLICY "lectura de fotos visibles" ON "public"."fotos_establecimiento"
  FOR SELECT
  TO "anon", "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE
    ((e.id = fotos_establecimiento.establecimiento_id) AND ((e.estado = 'aprobado'::public.estado_establecimiento) OR (e.propietario_id = auth.uid()) OR
    public.es_administrador())))));

CREATE POLICY "propietario gestiona fotos" ON "public"."fotos_establecimiento"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = fotos_establecimiento.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = fotos_establecimiento.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))));

CREATE POLICY "lectura de horarios visibles" ON "public"."horarios_establecimiento"
  FOR SELECT
  TO "anon", "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE
    ((e.id = horarios_establecimiento.establecimiento_id) AND ((e.estado = 'aprobado'::public.estado_establecimiento) OR (e.propietario_id = auth.uid()) OR
    public.es_administrador())))));

CREATE POLICY "propietario gestiona horarios" ON "public"."horarios_establecimiento"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = horarios_establecimiento.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = horarios_establecimiento.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))));

CREATE POLICY "lectura de promociones" ON "public"."promociones"
  FOR SELECT
  TO "anon", "authenticated"
  USING ((((activa = true) AND ((now() >= fecha_inicio) AND (now() <= fecha_fin)) AND (EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = promociones.establecimiento_id) AND (e.estado = 'aprobado'::public.estado_establecimiento))))) OR (EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = promociones.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador()))))));

CREATE POLICY "propietario actualiza promociones" ON "public"."promociones"
  FOR UPDATE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = promociones.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = promociones.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))));

CREATE POLICY "propietario crea promociones" ON "public"."promociones"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = promociones.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))));

CREATE POLICY "propietario elimina promociones" ON "public"."promociones"
  FOR DELETE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = promociones.establecimiento_id) AND ((e.propietario_id = auth.uid()) OR public.es_administrador())))));

CREATE POLICY "administrador responde solicitudes" ON "public"."solicitudes_establecimientos"
  FOR UPDATE
  TO "authenticated"
  USING (public.es_administrador())
  WITH CHECK (public.es_administrador());

CREATE POLICY "lectura de solicitudes relacionadas" ON "public"."solicitudes_establecimientos"
  FOR SELECT
  TO "authenticated"
  USING (((solicitante_id = auth.uid()) OR public.es_administrador() OR (EXISTS ( SELECT 1
   FROM public.establecimientos e
  WHERE ((e.id = solicitudes_establecimientos.establecimiento_id) AND (e.propietario_id = auth.uid()))))));

CREATE POLICY "usuario crea su solicitud pendiente" ON "public"."solicitudes_establecimientos"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((solicitante_id = auth.uid()) AND (estado = 'pendiente'::public.estado_solicitud) AND ((motivo_respuesta)::text = ''::text)));

CREATE POLICY "usuario elimina solicitud pendiente" ON "public"."solicitudes_establecimientos"
  FOR DELETE
  TO "authenticated"
  USING ((public.es_administrador() OR ((solicitante_id = auth.uid()) AND (estado = 'pendiente'::public.estado_solicitud))));

CREATE POLICY "usuario actualiza su perfil" ON "public"."usuarios"
  FOR UPDATE
  TO "authenticated"
  USING (((id = auth.uid()) OR public.es_administrador()))
  WITH CHECK (((id = auth.uid()) OR public.es_administrador()));

CREATE POLICY "usuario lee su perfil" ON "public"."usuarios"
  FOR SELECT
  TO "authenticated"
  USING (((id = auth.uid()) OR public.es_administrador()));

CREATE POLICY "lectura de imagenes de establecimientos" ON "storage"."objects"
  FOR SELECT
  TO "anon", "authenticated"
  USING (((bucket_id = 'establecimientos-imagenes'::text) AND ((EXISTS ( SELECT 1
   FROM (public.fotos_establecimiento f
     JOIN public.establecimientos e ON ((e.id = f.establecimiento_id)))
  WHERE ((f.ruta_storage = objects.name) AND (e.estado = 'aprobado'::public.estado_establecimiento)))) OR ((storage.foldername(name))[1] = (auth.uid())::text) OR
    public.es_administrador())));

CREATE POLICY "lectura de imagenes de promociones" ON "storage"."objects"
  FOR SELECT
  TO "anon", "authenticated"
  USING (((bucket_id = 'promociones-imagenes'::text) AND ((EXISTS ( SELECT 1
   FROM (public.promociones p
     JOIN public.establecimientos e ON ((e.id = p.establecimiento_id)))
  WHERE
    ((p.imagen_ruta_storage = objects.name) AND (p.activa = true) AND ((now() >= p.fecha_inicio) AND (now() <= p.fecha_fin)) AND (e.estado =
    'aprobado'::public.estado_establecimiento)))) OR ((storage.foldername(name))[1] = (auth.uid())::text) OR public.es_administrador())));

CREATE POLICY "propietario actualiza imagenes de establecimientos" ON "storage"."objects"
  FOR UPDATE
  TO "authenticated"
  USING (((bucket_id = 'establecimientos-imagenes'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR public.es_administrador())))
  WITH CHECK (((bucket_id = 'establecimientos-imagenes'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR public.es_administrador())));

CREATE POLICY "propietario actualiza imagenes de promociones" ON "storage"."objects"
  FOR UPDATE
  TO "authenticated"
  USING (((bucket_id = 'promociones-imagenes'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR public.es_administrador())))
  WITH CHECK (((bucket_id = 'promociones-imagenes'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR public.es_administrador())));

CREATE POLICY "propietario elimina imagenes de establecimientos" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING (((bucket_id = 'establecimientos-imagenes'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR public.es_administrador())));

CREATE POLICY "propietario elimina imagenes de promociones" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING (((bucket_id = 'promociones-imagenes'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR public.es_administrador())));

CREATE POLICY "propietario sube imagenes de establecimientos" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((bucket_id = 'establecimientos-imagenes'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

CREATE POLICY "propietario sube imagenes de promociones" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((bucket_id = 'promociones-imagenes'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

GRANT EXECUTE ON FUNCTION "public"."actualizar_fecha_modificacion"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."convertir_en_propietario"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."crear_perfil_nuevo_usuario"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."es_administrador"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."es_administrador"() TO "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."proteger_establecimiento"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."proteger_promocion"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."proteger_rol_usuario"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categorias" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."establecimientos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."fotos_establecimiento" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."horarios_establecimiento" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."promociones" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
  ON TABLE "public"."solicitudes_establecimientos"
  TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."usuarios" TO "anon";

REVOKE ALL ("nombre") ON TABLE "public"."usuarios" FROM "authenticated";

GRANT UPDATE ("nombre") ON TABLE "public"."usuarios" TO "authenticated";

REVOKE ALL ON TABLE "public"."usuarios" FROM "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."usuarios" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."usuarios" TO "postgres", "service_role";

GRANT USAGE ON TYPE "public"."estado_establecimiento" TO "postgres";

GRANT USAGE ON TYPE "public"."estado_solicitud" TO "postgres";

GRANT USAGE ON TYPE "public"."rol_usuario" TO "postgres";

GRANT USAGE ON TYPE "public"."tipo_solicitud_establecimiento" TO "postgres";

