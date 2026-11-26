import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef UgcRpc = Future<dynamic> Function(
  String nombre,
  Map<String, dynamic> parametros,
);

class UgcService {
  UgcService({UgcRpc? rpc}) : _rpc = rpc ?? _real;
  final UgcRpc _rpc;
  static final cambios = ValueNotifier<int>(0);
  static Future<dynamic> _real(
    String nombre,
    Map<String, dynamic> parametros,
  ) => Supabase.instance.client.rpc(nombre, params: parametros);

  Future<Map<String, dynamic>> normas() async =>
      Map<String, dynamic>.from(await _rpc('ugc_normas_publicacion', {}));
  Future<void> aceptar(Map<String, dynamic> normas) async {
    await _rpc('ugc_aceptar_normas', {
      'p_version': normas['version'],
      'p_huella': normas['huella'],
    });
  }

  Future<String> denunciar(
    String tipo,
    String id,
    String motivo,
    String detalle,
  ) async {
    if (detalle.length > 500) throw ArgumentError('Máximo 500 caracteres.');
    return await _rpc('ugc_denunciar', {
      'p_tipo': tipo,
      'p_objetivo_id': id,
      'p_motivo': motivo,
      'p_detalle': detalle,
    }) as String;
  }

  Future<void> bloquear(String tipo, String id) async {
    await _rpc('ugc_bloquear_responsable', {
      'p_tipo': tipo,
      'p_objetivo_id': id,
    });
    cambios.value++;
  }

  Future<List<Map<String, dynamic>>> bloqueos() async =>
      List<Map<String, dynamic>>.from(await _rpc('ugc_mis_bloqueos', {}));
  Future<void> desbloquear(String id) async {
    await _rpc('ugc_desbloquear', {'p_bloqueado_id': id});
    cambios.value++;
  }

  Future<List<Map<String, dynamic>>> denuncias({String? estado}) async =>
      List<Map<String, dynamic>>.from(
        await _rpc(
          estado == null ? 'ugc_mis_denuncias' : 'ugc_denuncias_admin',
          estado == null ? {} : {'p_estado': estado},
        ),
      );
  Future<void> revisar(String id, String estado, String motivo) async {
    await _rpc('ugc_revisar_denuncia', {
      'p_denuncia_id': id,
      'p_estado': estado,
      'p_motivo': motivo,
    });
    cambios.value++;
  }

  Future<Map<String, dynamic>> contexto(String id) async {
    final data = Map<String, dynamic>.from(
      await _rpc('ugc_contexto_denuncia', {'p_denuncia_id': id}),
    );
    final ruta = data['ruta'];
    if (ruta is String && ruta.isNotEmpty) {
      data['url'] = await Supabase.instance.client.storage
          .from(data['bucket'] as String)
          .createSignedUrl(ruta, 300);
    }
    return data;
  }
}
