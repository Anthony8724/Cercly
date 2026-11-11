"""Concurrencia real, solo sobre el contenedor sintético nuevo del arnés local."""
from concurrent.futures import ThreadPoolExecutor
import threading


def verificar_concurrencia(execute):
    prefix='b8700000-0000-0000-0000-'
    def uid(i):return prefix+str(i).zfill(12)
    def checked(query):
        r=execute(query)
        if r.returncode:raise RuntimeError('Error en fixture SQL local de concurrencia')
        return r.stdout.decode().strip()
    checked("insert into auth.users(id,email,raw_user_meta_data) select ('"+prefix+"'||lpad(i::text,12,'0'))::uuid,'concurrencia-'||i||'@cercly.test','{}' from generate_series(1,3)i; update public.usuarios set rol='administrador' where id='"+uid(1)+"';")
    for distinct in (False,True):
        business=uid(11 if distinct else 10)
        checked(f"insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable) select '{business}','{uid(2)}',id,'Original','Dirección',0.8,-77.7,'aprobado',true from public.categorias where activa order by id limit 1; insert into public.miembros_establecimiento(establecimiento_id,usuario_id) values('{business}','{uid(3)}');")
        ids=[uid(31),uid(32)] if distinct else [uid(30),uid(30)]
        for i,sid in enumerate(dict.fromkeys(ids)):
            checked(f"begin; set local role authenticated; select set_config('request.jwt.claim.sub','{uid(2+i)}',true); insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos) values('{sid}',auth.uid(),'{business}','correccion','',jsonb_build_object('cambios',jsonb_build_object('nombre',jsonb_build_object('anterior','Original','nuevo','Propuesto {i}')))); commit;")
        barrier=threading.Barrier(2)
        def approve(sid):
            barrier.wait(timeout=10)
            return execute(f"begin; set local role authenticated; select set_config('request.jwt.claim.sub','{uid(1)}',true); select public.aplicar_correccion_establecimiento('{sid}','Revisión de concurrencia sintética'); select pg_sleep(0.3); commit;")
        with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(approve,ids))
        if sorted(r.returncode==0 for r in results)!=[False,True]:raise RuntimeError('Concurrencia: debe existir una única aprobación')
        failed=next(r for r in results if r.returncode)
        if b'P0001' not in failed.stderr:raise RuntimeError('Concurrencia: rechazo no corresponde a validación SQL')
        counts=checked(f"select (select count(*) from public.correcciones_aplicadas where establecimiento_id='{business}')||':'||(select count(*) from public.solicitudes_establecimientos where establecimiento_id='{business}' and estado='aprobada')||':'||(select count(*) from public.solicitudes_establecimientos where establecimiento_id='{business}' and estado='pendiente');")
        if counts!=('1:1:1' if distinct else '1:1:0'):raise RuntimeError('Concurrencia: auditoría/estado inconsistente')
        print(('Propuestas distintas del mismo negocio' if distinct else 'Doble aprobación de la misma solicitud')+': 1 aplicada / 1 rechazada; auditoría única PASS',flush=True)
