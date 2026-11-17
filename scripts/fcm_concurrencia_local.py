"""Concurrent FCM reservation regression; caller supplies disposable DB only."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import time


def verificar_concurrencia_fcm(execute):
    def sql(query):
        result = execute(query)
        if result.returncode:
            raise RuntimeError('FCM_CONCURRENCY_SQL_FAILED')
        return result.stdout.decode()

    sql("""
      insert into auth.users(id,email,raw_user_meta_data) values
       ('d8100000-0000-4000-8000-000000000001','fcm-race@cercly.test','{}');
      insert into auth.sessions(id,user_id) values ('d8100000-0000-4000-8000-000000000001','d8100000-0000-4000-8000-000000000001');
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

    sql("""begin; set local role service_role;
      select count(*) from public.reservar_promocion_push_reciente(
      'd8100000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',
      'd8500000-0000-4000-8000-000000000099',0::double precision,0::double precision,
      20::double precision,now(),0::smallint); commit;""")
    barrier = Barrier(2)
    def finish(status):
        barrier.wait(timeout=10)
        sql(f"""begin; set local role service_role;
          select public.finalizar_reserva_promocion_push(
          (select id from public.promotion_push_reservations where event_id='d8500000-0000-4000-8000-000000000099'),
          '{status}',null); commit;""")
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(finish, ('sent', 'invalid_token')))
    state = sql("""select r.status||':'||i.active::text
       from public.promotion_push_reservations r
       join public.fcm_installations i on i.installation_id=r.installation_id
       where r.event_id='d8500000-0000-4000-8000-000000000099';""").strip()
    if state not in ('sent:true', 'invalid_token:false'):
        raise RuntimeError('FCM_CONCURRENT_FINALIZATION_INCONSISTENT:' + state)
    print('FCM competing finalizations:', state, 'PASS', flush=True)

    # Both entry points must use one ledger and one per-user transaction lock.
    sql("""delete from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';
      update public.fcm_installations set active=true where user_id='d8100000-0000-4000-8000-000000000001';""")
    sql("""begin; set local role authenticated;
      select set_config('request.jwt.claim.sub','d8100000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"session_id":"d8100000-0000-4000-8000-000000000001"}',true);
      select public.configurar_mis_alertas_geofencing(true,true); commit;""")
    for reverse in (False, True):
        barrier = Barrier(2)
        def cross(channel):
            barrier.wait(timeout=10)
            if channel == 'fcm':
                query="""begin; set local role service_role;
                 select count(*) from public.reservar_promocion_push_reciente(
                 'd8100000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',
                 'd8500000-0000-4000-8000-000000000010',0::double precision,0::double precision,
                 20::double precision,now(),0::smallint); commit;"""
            else:
                query="""begin; set local role authenticated;
                 select set_config('request.jwt.claim.sub','d8100000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"session_id":"d8100000-0000-4000-8000-000000000001"}',true);
                 select count(*) from public.reservar_promocion_geofencing(
                 'd8300000-0000-4000-8000-000000000001','d8500000-0000-4000-8000-000000000011',
                 0::double precision,0::double precision,20::double precision,now(),0::smallint); commit;"""
            out = sql(query)
            values = [line for line in out.splitlines() if line in ('0', '1')]
            if len(values) != 1:
                raise RuntimeError('CROSS_CHANNEL_UNEXPECTED_RESULT')
            return int(values[0])
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(cross, ('geofencing','fcm') if reverse else ('fcm','geofencing')))
        if sorted(results) != [0,1]:
            raise RuntimeError('CROSS_CHANNEL_DUPLICATE:' + str(results))
        rows=sql("select channel from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';").strip()
        if rows not in ('fcm','geofencing'):
            raise RuntimeError('CROSS_CHANNEL_LEDGER_INVALID')
        print('FCM vs geofencing, two devices:', rows, '1/2 reserved PASS', flush=True)
        sql("delete from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';")

    # Hold the winning transaction open after reservation; the other channel
    # must wait and then observe the committed shared ledger.
    def forced_query(channel, hold):
        prefix="begin; set application_name='cercly-cross-channel-race'; "
        if channel == 'fcm':
            body="""set local role service_role; select count(*) from public.reservar_promocion_push_reciente(
            'd8100000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',
            'd8500000-0000-4000-8000-000000000020',0::float8,0::float8,20::float8,now(),0::smallint);"""
        else:
            body="""set local role authenticated;
            select set_config('request.jwt.claim.sub','d8100000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"session_id":"d8100000-0000-4000-8000-000000000001"}',true);
            select count(*) from public.reservar_promocion_geofencing(
            'd8300000-0000-4000-8000-000000000001','d8500000-0000-4000-8000-000000000021',
            0::float8,0::float8,20::float8,now(),0::smallint);"""
        return prefix+body+('select pg_sleep(2);' if hold else '')+'commit;'

    def extract_count(output):
        values=[line for line in output.splitlines() if line in ('0','1')]
        if len(values)!=1: raise RuntimeError('FORCED_RACE_UNEXPECTED_RESULT')
        return int(values[0])

    for winner, loser in (('fcm','geofencing'),('geofencing','fcm')):
        with ThreadPoolExecutor(max_workers=1) as pool:
            future=pool.submit(sql,forced_query(winner,True))
            for _ in range(100):
                ready=sql("select count(*) from pg_stat_activity where application_name='cercly-cross-channel-race' and wait_event='PgSleep';").strip()
                if ready=='1': break
                if future.done(): raise RuntimeError('FORCED_WINNER_FAILED')
                time.sleep(.05)
            else: raise RuntimeError('FORCED_RACE_BARRIER_TIMEOUT')
            losing=sql(forced_query(loser,False))
            winning=future.result(timeout=10)
        if extract_count(winning)!=1 or extract_count(losing)!=0:
            raise RuntimeError('FORCED_RACE_INCORRECT_WINNER')
        sql("delete from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';")
        print('FCM vs geofencing, forced winner:',winner,'PASS',flush=True)

    barrier = Barrier(2)
    def geo_attempt(index):
        barrier.wait(timeout=10)
        output=sql(f"""begin; set local role authenticated;
          select set_config('request.jwt.claim.sub','d8100000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{{"session_id":"d8100000-0000-4000-8000-000000000001"}}',true);
          select count(*) from public.reservar_promocion_geofencing(
          'd8300000-0000-4000-8000-000000000001','d8500000-0000-4000-8000-{30+index:012d}',
          0::float8,0::float8,20::float8,now(),0::smallint); commit;""")
        return extract_count(output)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(geo_attempt,(1,2)))
    if sorted(results)!=[0,1]: raise RuntimeError('GEOFENCE_RACE_DUPLICATE')
    sql("delete from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';")
    print('Two simultaneous geofencing events: 1/2 reserved PASS',flush=True)

    revocation="""begin; set application_name='cercly-geo-revocation'; set local role authenticated;
      select set_config('request.jwt.claim.sub','d8100000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"session_id":"d8100000-0000-4000-8000-000000000001"}',true);
      select public.configurar_mis_alertas_geofencing(false,false); select pg_sleep(2); commit;"""
    with ThreadPoolExecutor(max_workers=1) as pool:
        future=pool.submit(sql,revocation)
        for _ in range(100):
            ready=sql("select count(*) from pg_stat_activity where application_name='cercly-geo-revocation' and wait_event='PgSleep';").strip()
            if ready=='1': break
            if future.done(): raise RuntimeError('REVOCATION_TRANSACTION_FAILED')
            time.sleep(.05)
        else: raise RuntimeError('REVOCATION_BARRIER_TIMEOUT')
        denied=sql(forced_query('geofencing',False))
        future.result(timeout=10)
    if extract_count(denied)!=0: raise RuntimeError('REVOKED_GEOFENCE_RESERVED')
    print('Concurrent geofencing consent revocation: blocked PASS',flush=True)
