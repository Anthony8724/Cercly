import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sky_theme.dart';

abstract class SkyPreferenceStore {
  Future<String?> getMode();
  Future<void> setMode(String value);
  Future<bool?> getDecorationsEnabled();
  Future<void> setDecorationsEnabled(bool value);
}

class DeviceSkyPreferenceStore implements SkyPreferenceStore {
  DeviceSkyPreferenceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const modeKey = 'cercly_sky_mode';
  static const decorationsKey = 'cercly_sky_decorations_enabled';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getMode() => _preferences.getString(modeKey);
  @override
  Future<void> setMode(String value) => _preferences.setString(modeKey, value);
  @override
  Future<bool?> getDecorationsEnabled() => _preferences.getBool(decorationsKey);
  @override
  Future<void> setDecorationsEnabled(bool value) =>
      _preferences.setBool(decorationsKey, value);
}

class SkyController extends ChangeNotifier with WidgetsBindingObserver {
  SkyController({SkyPreferenceStore? store, DateTime Function()? clock})
    : _store = store ?? DeviceSkyPreferenceStore(),
      _clock = clock ?? DateTime.now {
    _environment = skyEnvironmentAt(_clock());
  }

  final SkyPreferenceStore _store;
  final DateTime Function() _clock;
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _foreground = true;
  int _revision = 0;
  SkyMode _mode = SkyMode.automatico;
  late SkyEnvironment _environment;
  bool _decorationsEnabled = true;

  SkyMode get mode => _mode;
  SkyEnvironment get environment => _environment;
  bool get decorationsEnabled => _decorationsEnabled;
  SkyPalette get palette =>
      SkyPalette.forEnvironment(_environment)
          .copyWith(decorationsEnabled: _decorationsEnabled);

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final revision = _revision;
    try {
      final storedMode = await _store.getMode();
      final storedDecorations = await _store.getDecorationsEnabled();
      if (_disposed) return;
      if (revision == _revision) {
        final previousMode = _mode;
        final previousDecorations = _decorationsEnabled;
        _mode =
            SkyMode.values
                .where((value) => value.name == storedMode)
                .firstOrNull ??
            SkyMode.automatico;
        _decorationsEnabled = storedDecorations ?? true;
        if (previousMode != _mode ||
            previousDecorations != _decorationsEnabled) {
          notifyListeners();
        }
      }
    } catch (_) {
      // El tema automático sigue funcionando aunque el almacenamiento falle.
    }
    if (_disposed) return;
    refresh();
  }

  void refresh() {
    final next = _mode.environment ?? skyEnvironmentAt(_clock());
    if (next != _environment) {
      _environment = next;
      notifyListeners();
    }
    _schedule();
  }

  Future<void> selectMode(SkyMode mode) async {
    _revision++;
    final previous = _mode;
    _mode = mode;
    if (previous != mode) notifyListeners();
    refresh();
    await _store.setMode(mode.name);
  }

  Future<void> setDecorationsEnabled(bool enabled) async {
    _revision++;
    _decorationsEnabled = enabled;
    notifyListeners();
    await _store.setDecorationsEnabled(enabled);
  }

  void _schedule() {
    _timer?.cancel();
    if (!_started || !_foreground || _mode != SkyMode.automatico) return;
    // Comprueba hora y zona horaria cada 30 s como máximo. No hay animaciones.
    _timer = Timer(const Duration(seconds: 30), refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      refresh();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class SkyScope extends InheritedNotifier<SkyController> {
  const SkyScope({
    required SkyController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static SkyController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkyScope>()?.notifier;
}
