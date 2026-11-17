"""Concurrent FCM reservation regression; caller supplies disposable DB only."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier


def verificar_concurrencia_fcm(execute):
    def sql(query):
        result = execute(query)
        if result.returncode:
            raise RuntimeError('FCM_CONCURRENCY_SQL_FAILED')
        return result.stdout.decode()

    sql("""
      insert into auth.users(id,email,raw_user_meta_data) values
       ('d8100000-0000-4000-8000-000000000001','fcm-race@cercly.test','{}');
      insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
       select 'd8200000-0000-4000-8000-000000000001','d8100000-0000-4000-8000-000000000001',id,
       'FCM concurrency','Synthetic',0,0,'aprobado',true from public.categorias where activa limit 1;
      insert into public.promociones(id,establecimiento_id,titulo,descripcion,fecha_inicio,fecha_fin,radio_alerta_metros,activa)
       values('d8300000-0000-4000-8000-000000000001','d8200000-0000-4000-8000-000000000001',
       'Synthetic','',now()-interval '1 hour',now()+interval '1 day',1500,true);
      insert into public.push_preferences(user_id,enabled,consented_at,location_consent_at)
       values('d8100000-0000-4000-8000-000000000001',true,now(),now());
      insert into public.fcm_installations(installation_id,user_id,fcm_installation_id,platform) values
       ('d8400000-0000-4000-8000-000000000001','d8100000-0000-4000-8000-000000000001','fid-race-device-one-0001','android'),
       ('d8400000-0000-4000-8000-000000000002','d8100000-0000-4000-8000-000000000001','fid-race-device-two-0002','android');
    """)
    for same_event in (True, False):
        barrier = Barrier(2)

        def attempt(index):
            event = 1 if same_event else index
            barrier.wait(timeout=10)
            out = sql(f"""begin; set local role service_role;
              select count(*) from public.reservar_promocion_push_reciente(
               'd8100000-0000-4000-8000-000000000001',
               'd8400000-0000-4000-8000-{index:012d}',
               'd8500000-0000-4000-8000-{event:012d}',
               0::double precision,0::double precision,20::double precision,now(),0::smallint);
              commit;""")
            values = [line for line in out.splitlines() if line in ('0', '1')]
            if len(values) != 1:
                raise RuntimeError('FCM_CONCURRENCY_UNEXPECTED_RESULT')
            return int(values[0])

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(attempt, (1, 2)))
        if sorted(results) != [0, 1]:
            raise RuntimeError(f'FCM_CONCURRENCY_DUPLICATE:{results}')
        count = sql("select count(*) from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';")
        if count.strip() != '1':
            raise RuntimeError('FCM_CONCURRENCY_RESERVATION_COUNT')
        sql("delete from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';")
        print('FCM two-device race:', 'same event' if same_event else 'different events', '1/2 reserved PASS', flush=True)
