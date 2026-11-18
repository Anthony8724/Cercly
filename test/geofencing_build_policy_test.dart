import 'package:cercly/features/notificaciones/services/production_geofencing_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const staging = bool.fromEnvironment('CERCLY_STAGING');

  test('solo Staging habilita el servicio de geofencing del build', () async {
    const channel = MethodChannel('test/build-geofencing-policy');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return <String, Object>{'available': true};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    expect(ProductionGeofencingService.enabledBuild, staging);
    final service = ProductionGeofencingService(channel: channel);
    final status = await service.status();
    expect(status.isNotEmpty, staging);
    expect(calls.length, staging ? 1 : 0);
  });
}
