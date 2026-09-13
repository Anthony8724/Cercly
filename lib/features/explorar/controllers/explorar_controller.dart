import 'package:flutter/foundation.dart';

import '../../categorias/models/categoria_model.dart';
import '../../categorias/models/subcategoria_model.dart';
import '../../categorias/services/categoria_publica_service.dart';
import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../establecimientos/services/establecimiento_publico_service.dart';
import '../models/ubicacion_usuario.dart';
import '../services/ubicacion_service.dart';

class ExplorarController extends ChangeNotifier {
  ExplorarController({
    EstablecimientoPublicoService? establecimientoService,
    CategoriaPublicaService? categoriaService,
    UbicacionService? ubicacionService,
  }) : _establecimientoService =
           establecimientoService ?? EstablecimientoPublicoService(),
       _categoriaService = categoriaService ?? CategoriaPublicaService(),
       _ubicacionService = ubicacionService ?? GeolocatorUbicacionService();

  static const radiosDisponibles = <int>[500, 1000, 2000, 5000, 10000];

  final EstablecimientoPublicoService _establecimientoService;
  final CategoriaPublicaService _categoriaService;
  final UbicacionService _ubicacionService;

  EstadoUbicacion estadoUbicacion = EstadoUbicacion.inicial;
  UbicacionUsuario? ubicacion;
  String? mensajeUbicacion;
  List<CategoriaModel> categorias = const [];
  List<SubcategoriaModel> subcategorias = const [];
  List<EstablecimientoPublicoModel> establecimientos = const [];
  String? categoriaId;
  String? subcategoriaId;
  int radioMetros = 5000;
  bool soloPromociones = false;
  bool cargandoTaxonomia = false;
  bool cargandoResultados = false;
  bool hayMasResultados = false;
  String? errorResultados;

  static const int _tamanoPagina = 20;
  int _versionConsulta = 0;

  Future<void> inicializar() async {
    await Future.wait([cargarCategorias(), solicitarUbicacion()]);
  }

  Future<void> cargarCategorias() async {
    cargandoTaxonomia = true;
    notifyListeners();
    try {
      categorias = await _categoriaService.listarCategorias();
    } catch (_) {
      categorias = const [];
    } finally {
      cargandoTaxonomia = false;
      notifyListeners();
    }
  }

  Future<void> solicitarUbicacion() async {
    estadoUbicacion = EstadoUbicacion.cargando;
    mensajeUbicacion = null;
    notifyListeners();

    final resultado = await _ubicacionService.obtenerUbicacion();
    estadoUbicacion = resultado.estado;
    ubicacion = resultado.ubicacion;
    mensajeUbicacion = resultado.mensaje;
    notifyListeners();

    if (ubicacion != null) {
      await buscar();
    }
  }

  Future<void> cambiarRadio(int nuevoRadio) async {
    if (radioMetros == nuevoRadio) return;
    radioMetros = nuevoRadio;
    notifyListeners();
    await buscar();
  }

  Future<void> cambiarCategoria(String? nuevaCategoriaId) async {
    if (categoriaId == nuevaCategoriaId) return;
    categoriaId = nuevaCategoriaId;
    subcategoriaId = null;
    subcategorias = const [];
    notifyListeners();

    if (nuevaCategoriaId != null) {
      cargandoTaxonomia = true;
      notifyListeners();
      try {
        subcategorias = await _categoriaService.listarSubcategorias(
          nuevaCategoriaId,
        );
      } catch (_) {
        subcategorias = const [];
      } finally {
        cargandoTaxonomia = false;
        notifyListeners();
      }
    }

    await buscar();
  }

  Future<void> cambiarSubcategoria(String? nuevaSubcategoriaId) async {
    if (subcategoriaId == nuevaSubcategoriaId) return;
    subcategoriaId = nuevaSubcategoriaId;
    notifyListeners();
    await buscar();
  }

  Future<void> cambiarSoloPromociones(bool valor) async {
    if (soloPromociones == valor) return;
    soloPromociones = valor;
    notifyListeners();
    await buscar();
  }

  Future<void> buscar({bool reiniciar = true}) async {
    final posicion = ubicacion;
    if (posicion == null || (!reiniciar && cargandoResultados)) return;

    final versionConsulta = ++_versionConsulta;

    cargandoResultados = true;
    if (reiniciar) errorResultados = null;
    notifyListeners();

    try {
      final desplazamiento = reiniciar ? 0 : establecimientos.length;
      final nuevos = await _establecimientoService.buscarCercanos(
        latitud: posicion.latitud,
        longitud: posicion.longitud,
        radioMetros: radioMetros,
        categoriaId: categoriaId,
        subcategoriaIds: subcategoriaId == null ? null : [subcategoriaId!],
        soloPromociones: soloPromociones,
        limite: _tamanoPagina,
        desplazamiento: desplazamiento,
      );
      if (versionConsulta != _versionConsulta) return;
      establecimientos = reiniciar ? nuevos : [...establecimientos, ...nuevos];
      hayMasResultados = nuevos.length == _tamanoPagina;
    } catch (_) {
      if (versionConsulta != _versionConsulta) return;
      errorResultados =
          'No pudimos cargar los establecimientos. Revisa tu conexión.';
    } finally {
      if (versionConsulta == _versionConsulta) {
        cargandoResultados = false;
        notifyListeners();
      }
    }
  }

  Future<void> cargarMas() => buscar(reiniciar: false);

  Future<bool> abrirAjustesUbicacion() =>
      _ubicacionService.abrirAjustesUbicacion();

  Future<bool> abrirAjustesAplicacion() =>
      _ubicacionService.abrirAjustesAplicacion();
}
