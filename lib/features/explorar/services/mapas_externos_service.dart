import 'package:url_launcher/url_launcher.dart';

typedef AbrirUri = Future<bool> Function(Uri uri);

class MapasExternosService {
  MapasExternosService({AbrirUri? abrirUri})
    : _abrirUri = abrirUri ?? _abrirExternamente;

  final AbrirUri _abrirUri;

  Future<bool> comoLlegar({required double latitud, required double longitud}) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitud,$longitud',
    });

    return _abrirUri(uri);
  }

  static Future<bool> _abrirExternamente(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
