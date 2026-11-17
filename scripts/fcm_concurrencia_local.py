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
      insert into public.fcm_installations(installation_id,user_id,fcm_installation_id,platform,authorized_session_id) values
       ('d8400000-0000-4000-8000-000000000001','d8100000-0000-4000-8000-000000000001','fid-race-device-one-0001','android','d8100000-0000-4000-8000-000000000001'),
       ('d8400000-0000-4000-8000-000000000002','d8100000-0000-4000-8000-000000000001','fid-race-device-two-0002','android','d8100000-0000-4000-8000-000000000001');
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
               0::double precision,0::double precision,20::double precision,now(),0::smallint,'d8100000-0000-4000-8000-000000000001'::uuid);
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
      20::double precision,now(),0::smallint,'d8100000-0000-4000-8000-000000000001'::uuid); commit;""")
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

    # An old FCM UNREGISTERED response cannot disable a freshly rotated token.
    sql("""delete from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';
      update public.fcm_installations set active=true,fcm_installation_id='fid-race-old-token-0001'
      where installation_id='d8400000-0000-4000-8000-000000000001';
      begin; set local role service_role;
      select count(*) from public.reservar_promocion_push_reciente(
      'd8100000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',
      'd8500000-0000-4000-8000-000000000098',0::float8,0::float8,20::float8,now(),0::smallint,'d8100000-0000-4000-8000-000000000001'::uuid); commit;
      update public.fcm_installations set fcm_installation_id='fid-race-new-token-0001',fcm_token_generation=gen_random_uuid()
      where installation_id='d8400000-0000-4000-8000-000000000001';
      begin; set local role service_role;
      select public.finalizar_reserva_promocion_push(
       (select id from public.promotion_push_reservations where event_id='d8500000-0000-4000-8000-000000000098'),
       'invalid_token',null); commit;""")
    state = sql("""select active::text||':'||fcm_installation_id from public.fcm_installations
      where installation_id='d8400000-0000-4000-8000-000000000001';""").strip()
    if state != 'true:fid-race-new-token-0001':
        raise RuntimeError('STALE_TOKEN_RESPONSE_DISABLED_NEW_TOKEN:' + state)
    print('FCM old invalid_token after rotation: new token remains active PASS', flush=True)

    # Re-registration with identical token also has a new authorization generation.
    sql("""delete from public.promotion_push_reservations where user_id='d8100000-0000-4000-8000-000000000001';
      begin; set local role service_role;
      select count(*) from public.reservar_promocion_push_reciente(
      'd8100000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',
      'd8500000-0000-4000-8000-000000000097',0::float8,0::float8,20::float8,now(),0::smallint,
      'd8100000-0000-4000-8000-000000000001'::uuid); commit;
      update public.fcm_installations set fcm_token_generation=gen_random_uuid()
      where installation_id='d8400000-0000-4000-8000-000000000001';
      begin; set local role service_role;
      select public.finalizar_reserva_promocion_push(
       (select id from public.promotion_push_reservations where event_id='d8500000-0000-4000-8000-000000000097'),
       'invalid_token',null); commit;""")
    if sql("select active::text from public.fcm_installations where installation_id='d8400000-0000-4000-8000-000000000001';").strip()!='true':
        raise RuntimeError('STALE_GENERATION_DISABLED_REREGISTRATION')
    print('FCM old invalid_token after same-token registration: new generation active PASS',flush=True)

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
                 20::double precision,now(),0::smallint,'d8100000-0000-4000-8000-000000000001'::uuid); commit;"""
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
            'd8500000-0000-4000-8000-000000000020',0::float8,0::float8,20::float8,now(),0::smallint,'d8100000-0000-4000-8000-000000000001'::uuid);"""
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

    # Retirement holds the per-installation lock while an older transaction
    # waits. When it resumes its still-live JWT must not reactivate the row.
    uid='d8100000-0000-4000-8000-000000000001'
    other_session='d8100000-0000-4000-8000-000000000002'
    inst='d8400000-0000-4000-8000-000000000090'
    sql(f"insert into auth.sessions(id,user_id) values('{other_session}','{uid}');")
    auth_sql=f"set local role authenticated; select set_config('request.jwt.claim.sub','{uid}',true); select set_config('request.jwt.claims','{{\"session_id\":\"{uid}\"}}',true);"
    retire=f"begin; set application_name='cercly-fcm-retire-race'; {auth_sql} select public.retirar_mi_instalacion_fcm('{inst}'); select pg_sleep(2); commit;"
    old_register=f"begin; {auth_sql} select public.registrar_mi_instalacion_fcm('{inst}','fid-old-late-request-0001','android'); commit;"
    with ThreadPoolExecutor(max_workers=1) as pool:
        future=pool.submit(sql,retire)
        for _ in range(100):
            if sql("select count(*) from pg_stat_activity where application_name='cercly-fcm-retire-race' and wait_event='PgSleep';").strip()=='1': break
            if future.done(): raise RuntimeError('FCM_RETIRE_FAILED')
            time.sleep(.05)
        else: raise RuntimeError('FCM_RETIRE_BARRIER_TIMEOUT')
        late=execute(old_register)
        future.result(timeout=10)
    if late.returncode==0 or '42501' not in late.stderr.decode():
        raise RuntimeError('OLD_REGISTER_NOT_REJECTED')
    state=sql(f"select active::text from public.fcm_installations where installation_id='{inst}';").strip()
    if state!='false': raise RuntimeError('RETIRED_FCM_INSTALLATION_ACTIVE')
    print('FCM retire before late old registration: rejected; inactive PASS',flush=True)

    # A new authenticated session can explicitly reactivate the same install;
    # the old session remains tombstoned even after that activation.
    new_auth=f"set local role authenticated; select set_config('request.jwt.claim.sub','{uid}',true); select set_config('request.jwt.claims','{{\"session_id\":\"{other_session}\"}}',true);"
    sql(f"begin; {new_auth} select public.registrar_mi_instalacion_fcm('{inst}','fid-new-session-token-0001','android'); commit;")
    stale=execute(old_register)
    if stale.returncode==0: raise RuntimeError('OLD_SESSION_REACTIVATED_AFTER_NEW_SESSION')
    state=sql(f"select active::text||':'||authorized_session_id::text from public.fcm_installations where installation_id='{inst}';").strip()
    if state!='true:'+other_session: raise RuntimeError('NEW_SESSION_REGISTRATION_NOT_PRESERVED')
    sql(f"begin; {new_auth} select public.retirar_mi_instalacion_fcm('{inst}'); commit;")
    if sql(f"select active::text from public.fcm_installations where installation_id='{inst}';").strip()!='false':
        raise RuntimeError('REGISTER_FIRST_RETIRE_LAST_STILL_ACTIVE')
    print('FCM new session allowed; register then retire leaves inactive PASS',flush=True)

    # Recovery after offline logout: a new session for the same user retires
    # both its own authority and the session that last owned the installation.
    offline_inst='d8400000-0000-4000-8000-000000000091'
    sql(f"begin; {auth_sql} select public.registrar_mi_instalacion_fcm('{offline_inst}','fid-offline-old-token-001','android'); commit;")
    sql(f"begin; {new_auth} select public.retirar_mi_instalacion_fcm('{offline_inst}'); commit;")
    late_offline=execute(f"begin; {auth_sql} select public.registrar_mi_instalacion_fcm('{offline_inst}','fid-offline-old-token-002','android'); commit;")
    if late_offline.returncode==0: raise RuntimeError('OFFLINE_OLD_SESSION_REACTIVATED')
    if sql(f"select active::text from public.fcm_installations where installation_id='{offline_inst}';").strip()!='false':
        raise RuntimeError('OFFLINE_CLEANUP_NOT_INACTIVE')
    print('FCM offline cleanup by new session rejects old session PASS',flush=True)

    # Deleting the session blocks both registration and the service-role reserve.
    sql(f"delete from auth.sessions where id='{other_session}';")
    denied=execute(f"begin; {new_auth} select public.registrar_mi_instalacion_fcm('{inst}','fid-expired-session-0001','android'); commit;")
    if denied.returncode==0: raise RuntimeError('DELETED_SESSION_REGISTERED')
    reserved=sql(f"begin; set local role service_role; select count(*) from public.reservar_promocion_push_reciente('{uid}','{inst}','d8500000-0000-4000-8000-000000000099',0::float8,0::float8,20::float8,now(),0::smallint,'{other_session}'); commit;")
    if [x for x in reserved.splitlines() if x in ('0','1')]!=['0']: raise RuntimeError('DELETED_SESSION_RESERVED')
    print('FCM deleted session: registration and evaluation rejected PASS',flush=True)

    # A token refresh racing a confirmed retirement cannot recreate the row.
    refresh_inst='d8400000-0000-4000-8000-000000000092'
    sql(f"begin; {auth_sql} select public.registrar_mi_instalacion_fcm('{refresh_inst}','fid-refresh-before-retire-0001','android'); commit;")
    refresh_retire=f"begin; set application_name='cercly-fcm-refresh-retire'; {auth_sql} select public.retirar_mi_instalacion_fcm('{refresh_inst}'); select pg_sleep(2); commit;"
    refresh_request=f"begin; {auth_sql} select public.registrar_mi_instalacion_fcm('{refresh_inst}','fid-refresh-after-retire-0002','android'); commit;"
    with ThreadPoolExecutor(max_workers=1) as pool:
        future=pool.submit(sql,refresh_retire)
        for _ in range(100):
            if sql("select count(*) from pg_stat_activity where application_name='cercly-fcm-refresh-retire' and wait_event='PgSleep';").strip()=='1': break
            if future.done(): raise RuntimeError('FCM_REFRESH_RETIRE_FAILED')
            time.sleep(.05)
        else: raise RuntimeError('FCM_REFRESH_BARRIER_TIMEOUT')
        denied_refresh=execute(refresh_request)
        future.result(timeout=10)
    if denied_refresh.returncode==0: raise RuntimeError('LATE_TOKEN_REFRESH_REGISTERED')
    state=sql(f"select active::text||':'||(fcm_installation_id is null)::text from public.fcm_installations where installation_id='{refresh_inst}';").strip()
    if state!='false:true': raise RuntimeError('LATE_TOKEN_REFRESH_LEFT_ASSOCIATION')
    print('FCM refresh after retirement: rejected; token detached PASS',flush=True)

    # Pre-send check fails once a confirmed logout retires the installation.
    delivery_inst='d8400000-0000-4000-8000-000000000093'
    delivery_event='d8500000-0000-4000-8000-000000000093'
    sql(f"delete from public.promotion_push_reservations where user_id='{uid}'; begin; {auth_sql} select public.registrar_mi_instalacion_fcm('{delivery_inst}','fid-pre-send-check-token-0001','android'); commit;")
    sql(f"begin; set local role service_role; select count(*) from public.reservar_promocion_push_reciente('{uid}','{delivery_inst}','{delivery_event}',0::float8,0::float8,20::float8,now(),0::smallint,'{uid}'); commit;")
    rid=sql(f"select id from public.promotion_push_reservations where event_id='{delivery_event}';").strip()
    if not rid: raise RuntimeError('PRE_SEND_FIXTURE_NO_RESERVATION')
    def preflight():
        output=sql(f"begin; set local role service_role; select public.entrega_fcm_autorizada('{rid}','{uid}'); commit;")
        values=[line for line in output.splitlines() if line in ('t','f')]
        if len(values)!=1: raise RuntimeError('PRE_SEND_UNEXPECTED_RESULT')
        return values[0]
    if preflight()!='t': raise RuntimeError('VALID_PRE_SEND_REJECTED')
    sql(f"begin; {auth_sql} select public.retirar_mi_instalacion_fcm('{delivery_inst}'); commit;")
    if preflight()!='f': raise RuntimeError('RETIRED_RESERVATION_STILL_SENDABLE')
    print('FCM pre-send check stops a retired reservation PASS',flush=True)
