import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../services/account_capabilities.dart';

class AccountModeScope extends InheritedWidget {
  const AccountModeScope({
    required this.capabilities,
    required this.selected,
    required this.select,
    required this.refresh,
    required super.child,
    super.key,
  });

  final AccountCapabilities capabilities;
  final AccountMode selected;
  final Future<void> Function(AccountMode) select;
  final Future<void> Function() refresh;

  static AccountModeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountModeScope>();

  @override
  bool updateShouldNotify(AccountModeScope oldWidget) =>
      capabilities != oldWidget.capabilities || selected != oldWidget.selected;
}

class AccountModeSelector extends StatelessWidget {
  const AccountModeSelector({this.compact = false, super.key});

  final bool compact;

  static String label(AccountMode mode) => switch (mode) {
    AccountMode.usuario => 'Usuario',
    AccountMode.propietario => 'Propietario',
    AccountMode.administracion => 'Administración',
  };

  @override
  Widget build(BuildContext context) {
    final scope = AccountModeScope.maybeOf(context);
    if (scope == null || scope.capabilities.availableModes.length < 2) {
      return const SizedBox.shrink();
    }
    final sky = SkyPalette.of(context);
    return PopupMenuButton<AccountMode?>(
      key: const Key('selector-modos-cuenta'),
      tooltip: 'Cambiar modo de Cercly',
      onSelected: (mode) {
        if (mode == null) {
          scope.refresh();
        } else {
          scope.select(mode);
        }
      },
      itemBuilder: (_) => [
        for (final mode in scope.capabilities.availableModes)
          PopupMenuItem<AccountMode?>(
            value: mode,
            child: Row(
              children: [
                if (scope.selected == mode) const Icon(Icons.check, size: 18),
                if (scope.selected == mode) const SizedBox(width: 8),
                Text(label(mode)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<AccountMode?>(
          value: null,
          child: Text('Actualizar permisos'),
        ),
      ],
      child: compact
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.swap_horiz_rounded, color: sky.interactive),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: sky.surface,
                border: Border.all(color: sky.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: sky.interactive),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Modo: ${label(scope.selected)}',
                      style: TextStyle(
                        color: sky.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: sky.interactive),
                ],
              ),
            ),
    );
  }
}
