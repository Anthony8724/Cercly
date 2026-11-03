import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../categorias/models/categoria_model.dart';
import '../../categorias/models/subcategoria_model.dart';
import '../../categorias/services/categoria_publica_service.dart';
import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../establecimientos/services/establecimiento_publico_service.dart';
import '../../preferencias/models/preferencias_usuario.dart';
import '../../preferencias/services/preferencias_usuario_service.dart';
import '../../preferencias/services/recomendador_establecimientos.dart';
import '../models/ubicacion_usuario.dart';
import '../services/consentimiento_ubicacion.dart';
import '../services/ubicacion_service.dart';

class ExplorarController extends ChangeNotifier {
  ExplorarController({
    EstablecimientoCercanoRepository? establecimientoService,
    CategoriaPublicaRepository? categoriaService,
    UbicacionService? ubicacionService,
    PreferenciasUsuarioService? preferenciasService,
  }) : _establecimientoService =
           establecimientoService ?? EstablecimientoPublicoService(),
       _establecimientosPublicos = establecimientoService == null
           ? EstablecimientoPublicoService()
           : establecimientoService is EstablecimientoPublicoService
           ? establecimientoService
           : null,
       _categoriaService = categoriaService ?? CategoriaPublicaService(),
       _ubicacionService = ubicacionService ?? GeolocatorUbicacionService(),
       _preferenciasService =
           preferenciasService ?? PreferenciasUsuarioService();

  static const radiosDisponibles = <int>[500, 1000, 2000, 5000, 10000];

  final EstablecimientoCercanoRepository _establecimientoService;
  final CategoriaPublicaRepository _categoriaService;
  final UbicacionService _ubicacionService;
  final EstablecimientoPublicoService? _establecimientosPublicos;
  final PreferenciasUsuarioService _preferenciasService;

  EstadoUbicacion estadoUbicacion = EstadoUbicacion.inicial;
  UbicacionUsuario? ubicacion;
  String? mensajeUbicacion;
  List<CategoriaModel> categorias = const [];
  List<SubcategoriaModel> subcategorias = const [];
  List<EstablecimientoPublicoModel> establecimientos = const [];
  List<EstablecimientoPublicoModel> recomendados = const [];
  PreferenciasUsuario preferencias = const PreferenciasUsuario();
  String? categoriaId;
  String? subcategoriaId;
  String busqueda = '';
  int radioMetros = 5000;
  bool soloPromociones = false;
  bool cargandoTaxonomia = false;
  bool cargandoResultados = false;
  bool hayMasResultados = false;
  String? errorResultados;

  static const int _tamanoPagina = 20;
  static const Duration _esperaBusqueda = Duration(milliseconds: 450);
  int _versionConsulta = 0;
  Timer? _temporizadorBusqueda;
  bool _restaurandoUbicacion = false;
  bool _disposed = false;
  DateTime? _ultimaActualizacionUbicacion;

  Future<void> inicializar() async {
    await cargarCategorias();
    try {
      try {
        await _preferenciasService.sincronizarPendientes();
      } on PreferenciasConflictException {
        // Se conserva el borrador local, pero no se pisa una revisión remota nueva.
      }
      preferencias = await _preferenciasService.cargar();
      if (await ConsentimientoUbicacion.estaAceptado()) {
        await restaurarUbicacionConsentida();
      }
      await cargarRecomendaciones();
    } catch (_) {
      // La búsqueda general no depende de la sincronización de preferencias.
    }
    if (ubicacion == null) await buscar();
  }

  Future<void> cargarRecomendaciones() async {
    if (_disposed) return;
    final service = _establecimientosPublicos;
    if (service == null ||
        (preferencias.categoriasIds.isEmpty &&
            !preferencias.priorizarPromociones)) {
      recomendados = const [];
      notifyListeners();
      return;
    }
    try {
      final candidates = await service.listarCandidatosRecomendacion(
        categoriasIds: preferencias.categoriasIds,
        incluirPromociones: preferencias.priorizarPromociones,
      );
      if (_disposed) return;
      recomendados = const RecomendadorEstablecimientos().recomendar(
        establecimientos: candidates,
        preferencias: preferencias,
        latitud: ubicacion?.latitud,
        longitud: ubicacion?.longitud,
      );
    } catch (_) {
      recomendados = const [];
    }
    notifyListeners();
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

    final resultado = await _ubicacionService.obtenerUbicacion(
      solicitarPermiso: true,
    );
    estadoUbicacion = resultado.estado;
    ubicacion = resultado.ubicacion;
    mensajeUbicacion = resultado.mensaje;
    if (ubicacion != null) {
      try {
        await ConsentimientoUbicacion.aceptar();
      } catch (_) {
        // La búsqueda solicitada por el usuario no depende de guardar el opt-in.
      }
    } else if (resultado.estado == EstadoUbicacion.permisoDenegado ||
        resultado.estado == EstadoUbicacion.permisoDenegadoPermanentemente) {
      await ConsentimientoUbicacion.revocar();
    }
    notifyListeners();

    if (ubicacion != null) {
      await buscar();
      await cargarRecomendaciones();
    }
  }

  /// Reacquire el punto actual sin volver a pedir permisos.
  /// Solo se ejecuta después de un consentimiento previo en Cercly y un
  /// permiso que Android todavía concede.
  Future<void> restaurarUbicacionConsentida({bool alReanudar = false}) async {
    if (_disposed ||
        _restaurandoUbicacion ||
        !await ConsentimientoUbicacion.estaAceptado()) {
      return;
    }
    final ultima = _ultimaActualizacionUbicacion;
    if (alReanudar &&
        ultima != null &&
        DateTime.now().difference(ultima) < const Duration(minutes: 1)) {
      return;
    }

    _restaurandoUbicacion = true;
    try {
      final resultado = await _ubicacionService.obtenerUbicacion(
        solicitarPermiso: false,
      );
      if (_disposed) return;
      _ultimaActualizacionUbicacion = DateTime.now();
      final ubicacionAnterior = ubicacion;
      if (resultado.estado == EstadoUbicacion.disponible &&
          resultado.ubicacion != null) {
        estadoUbicacion = EstadoUbicacion.disponible;
        ubicacion = resultado.ubicacion;
        mensajeUbicacion = null;
        notifyListeners();
        await buscar();
        if (_disposed) return;
        await cargarRecomendaciones();
        return;
      }

      estadoUbicacion = resultado.estado;
      mensajeUbicacion = resultado.mensaje;
      final permisoRevocado =
          resultado.estado == EstadoUbicacion.permisoDenegado ||
          resultado.estado == EstadoUbicacion.permisoDenegadoPermanentemente;
      if (permisoRevocado) ubicacion = null;
      notifyListeners();
      if (permisoRevocado && ubicacionAnterior != null && alReanudar) {
        // Sin permiso se vuelve al catálogo general; no se reutiliza una
        // coordenada vieja para una consulta de cercanía.
        await buscar();
        if (_disposed) return;
        await cargarRecomendaciones();
      }
    } catch (_) {
      if (_disposed) return;
      estadoUbicacion = EstadoUbicacion.error;
      mensajeUbicacion =
          'No pudimos actualizar la ubicación. Inténtalo de nuevo.';
      notifyListeners();
    } finally {
      _restaurandoUbicacion = false;
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

  void cambiarBusqueda(String valor) {
    if (busqueda == valor) return;
    busqueda = valor;
    _temporizadorBusqueda?.cancel();
    notifyListeners();

    _temporizadorBusqueda = Timer(_esperaBusqueda, () {
      buscar();
    });
  }

  Future<void> limpiarBusqueda() async {
    if (busqueda.isEmpty) return;
    _temporizadorBusqueda?.cancel();
    busqueda = '';
    notifyListeners();
    await buscar();
  }

  Future<void> buscar({bool reiniciar = true}) async {
    final posicion = ubicacion;
    if (!reiniciar && cargandoResultados) return;

    final versionConsulta = ++_versionConsulta;

    cargandoResultados = true;
    if (reiniciar) errorResultados = null;
    notifyListeners();

    try {
      final desplazamiento = reiniciar ? 0 : establecimientos.length;
      final nuevos = posicion == null
          ? await _establecimientoService.listar(
              categoriaId: categoriaId,
              busqueda: busqueda,
              soloPromociones: soloPromociones,
              limite: _tamanoPagina,
              desplazamiento: desplazamiento,
            )
          : await _establecimientoService.buscarCercanos(
              latitud: posicion.latitud,
              longitud: posicion.longitud,
              radioMetros: radioMetros,
              categoriaId: categoriaId,
              subcategoriaIds: subcategoriaId == null
                  ? null
                  : [subcategoriaId!],
              soloPromociones: soloPromociones,
              busqueda: busqueda,
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

  @override
  void dispose() {
    _disposed = true;
    _versionConsulta++;
    _temporizadorBusqueda?.cancel();
    super.dispose();
  }
}
