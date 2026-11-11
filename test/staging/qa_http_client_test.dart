import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'qa_http_client.dart';

void main() {
  test(
    'cerrar el cliente cancela un cuerpo pendiente y libera recursos',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      final headers = Completer<void>();
      final subscription = server.listen((request) async {
        request.response.write('[');
        await request.response.flush();
        await release.future;
        try {
          await request.response.close();
        } catch (_) {
          /* cierre esperado */
        }
      });
      final events = <Map<String, Object>>[];
      final client = QaHttpClient(
        record: (event) {
          events.add(event);
          if (event['event'] == 'headers' && !headers.isCompleted) {
            headers.complete();
          }
        },
      );
      try {
        final pending = client.send(
          http.Request(
            'GET',
            Uri.parse('http://127.0.0.1:${server.port}/fixture'),
          ),
        );
        final rejected = expectLater(
          pending,
          throwsA(
            anyOf(
              isA<http.RequestAbortedException>(),
              isA<http.ClientException>(),
            ),
          ),
        );
        await headers.future.timeout(const Duration(seconds: 2));
        client.close();
        await rejected.timeout(const Duration(seconds: 2));
        expect(client.activeRequests, 0);
        expect(events.any((event) => event['event'] == 'released'), isTrue);
      } finally {
        client.close();
        release.complete();
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );
  test(
    'HTTP 200 con cuerpo incompleto termina por deadline y libera la petición',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      final events = <Map<String, Object>>[];
      final subscription = server.listen((request) async {
        request.response.statusCode = 200;
        request.response.write('[{"id":');
        await request.response.flush();
        await release.future;
        try {
          await request.response.close();
        } catch (_) {
          /* abortado por el cliente */
        }
      });
      final client = QaHttpClient(
        record: events.add,
        deadline: const Duration(milliseconds: 300),
      );
      try {
        await expectLater(
          client.send(
            http.Request(
              'GET',
              Uri.parse('http://127.0.0.1:${server.port}/fixture'),
            ),
          ),
          throwsA(
            isA<TimeoutException>().having(
              (e) => e.message,
              'phase',
              contains('body'),
            ),
          ),
        );
        expect(
          events.any((e) => e['event'] == 'headers' && e['status'] == 200),
          isTrue,
        );
        expect(
          events.singleWhere((e) => e['event'] == 'deadline')['phase'],
          'body',
        );
        expect(events.any((e) => e['event'] == 'body_completed'), isFalse);
        expect(client.activeRequests, 0);
      } finally {
        client.close();
        release.complete();
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );
  test('respuesta fragmentada se completa y la evidencia no guarda contenidos ni headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.write('[1,');
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      request.response.write('2]');
      await request.response.close();
    });
    final events = <Map<String, Object>>[];
    final client = QaHttpClient(record: events.add);
    try {
      final request = http.Request(
        'GET',
        Uri.parse('http://127.0.0.1:${server.port}/fixture?private=value'),
      )..headers['Authorization'] = 'synthetic-private-marker';
      final response = await http.Response.fromStream(
        await client.send(request),
      );
      expect(response.body, '[1,2]');
      expect(
        events.any((e) => e['event'] == 'body_completed' && e['bytes'] == 5),
        isTrue,
      );
      expect(events.toString(), isNot(contains('synthetic-private-marker')));
      expect(events.toString(), isNot(contains('private=value')));
      expect(client.activeRequests, 0);
    } finally {
      client.close();
      await server.close(force: true);
      await subscription.cancel();
    }
  });
  test('rechaza destinos no autorizados antes de abrir red', () async {
    final events = <Map<String, Object>>[];
    final client = QaHttpClient(record: events.add);
    try {
      await expectLater(
        client.send(
          http.Request('GET', Uri.parse('https://example.invalid/fixture')),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'motivo',
            'QA_HOST_NOT_ALLOWED',
          ),
        ),
      );
      expect(events, isEmpty);
      expect(client.activeRequests, 0);
    } finally {
      client.close();
    }
  });
}
