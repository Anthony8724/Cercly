// Solo infraestructura de aceptación: no forma parte del cliente distribuido.
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class _RealNetwork extends HttpOverrides {
  HttpClient open() => super.createHttpClient(null);
}

/// Acota cabeceras Y cuerpo; un 200 no acredita que terminó su recepción.
/// Emite únicamente metadatos técnicos, nunca headers, query, cuerpo ni sesión.
class QaHttpClient extends http.BaseClient {
  QaHttpClient({
    required this.record,
    this.deadline = const Duration(seconds: 15),
    Set<String> allowedHosts = const {'127.0.0.1'},
  }) : allowedHosts = Set.unmodifiable(allowedHosts),
       _client = IOClient(_RealNetwork().open());

  final void Function(Map<String, Object>) record;
  final Duration deadline;
  final Set<String> allowedHosts;
  final http.Client _client;
  final _active = <Completer<void>>{};
  var _serial = 0;

  int get activeRequests => _active.length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is! http.Request) throw StateError('QA_REQUEST_TYPE_REJECTED');
    if (!allowedHosts.contains(request.url.host)) {
      throw StateError('QA_HOST_NOT_ALLOWED');
    }
    final id = ++_serial;
    final cancel = Completer<void>();
    _active.add(cancel);
    var expired = false;
    var phase = 'headers';
    final watch = Stopwatch()..start();
    void event(String kind, [Map<String, Object> more = const {}]) => record({
      'request': id,
      'event': kind,
      'method': request.method,
      'path': request.url.path,
      'elapsed_ms': watch.elapsedMilliseconds,
      ...more,
    });
    final timer = Timer(deadline, () {
      expired = true;
      if (!cancel.isCompleted) cancel.complete();
    });
    try {
      event('started');
      final bounded =
          http.AbortableRequest(
              request.method,
              request.url,
              abortTrigger: Future.any<void>([
                cancel.future,
                if (request is http.AbortableRequest &&
                    request.abortTrigger != null)
                  request.abortTrigger!,
              ]),
            )
            ..headers.addAll(request.headers)
            ..bodyBytes = request.bodyBytes
            ..followRedirects = false
            ..persistentConnection = request.persistentConnection;
      final response = await _client.send(bounded);
      phase = 'body';
      event('headers', {'status': response.statusCode});
      final bytes = await response.stream.toBytes();
      event('body_completed', {
        'status': response.statusCode,
        'bytes': bytes.length,
      });
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: request,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
    } catch (error) {
      event(expired ? 'deadline' : 'failed', {
        'phase': phase,
        'kind': error.runtimeType.toString(),
      });
      if (expired) {
        throw TimeoutException('QA_HTTP_DEADLINE phase=$phase', deadline);
      }
      rethrow;
    } finally {
      timer.cancel();
      _active.remove(cancel);
      event('released');
    }
  }

  @override
  void close() {
    for (final request in _active.toList()) {
      if (!request.isCompleted) request.complete();
    }
    _client.close();
  }
}
