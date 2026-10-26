import 'package:flutter/material.dart';

enum SkyEnvironment { amanecer, dia, atardecer, noche }

enum SkyMode { automatico, amanecer, dia, atardecer, noche }

extension SkyModeLabel on SkyMode {
  String get label => switch (this) {
    SkyMode.automatico => 'Automático',
    SkyMode.amanecer => 'Amanecer',
    SkyMode.dia => 'Día',
    SkyMode.atardecer => 'Atardecer',
    SkyMode.noche => 'Noche',
  };

  SkyEnvironment? get environment => switch (this) {
    SkyMode.automatico => null,
    SkyMode.amanecer => SkyEnvironment.amanecer,
    SkyMode.dia => SkyEnvironment.dia,
    SkyMode.atardecer => SkyEnvironment.atardecer,
    SkyMode.noche => SkyEnvironment.noche,
  };
}

SkyEnvironment skyEnvironmentAt(DateTime localTime) {
  final minute = localTime.hour * 60 + localTime.minute;
  if (minute >= 5 * 60 && minute < 8 * 60) {
    return SkyEnvironment.amanecer;
  }
  if (minute >= 8 * 60 && minute < 16 * 60 + 30) {
    return SkyEnvironment.dia;
  }
  if (minute >= 16 * 60 + 30 && minute < 19 * 60) {
    return SkyEnvironment.atardecer;
  }
  return SkyEnvironment.noche;
}

@immutable
class SkyPalette extends ThemeExtension<SkyPalette> {
  const SkyPalette({
    required this.environment,
    required this.headerStart,
    required this.headerMiddle,
    required this.headerEnd,
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.soft,
    this.decorationsEnabled = true,
  });

  final SkyEnvironment environment;
  final Color headerStart, headerMiddle, headerEnd;
  final Color primary, accent, background, surface, text, muted, border, soft;
  final bool decorationsEnabled;

  Color get onPrimary => Colors.white;
  Color get onSurface => text;
  Color get interactive =>
      environment == SkyEnvironment.noche ? accent : primary;
  Color get outline => border;
  Color get inputFill => environment == SkyEnvironment.noche ? soft : surface;
  Color get selectedSurface => soft;
  Color get error => environment == SkyEnvironment.noche
      ? const Color(0xFFFFB4AB)
      : const Color(0xFFB3261E);
  Color get success => environment == SkyEnvironment.noche
      ? const Color(0xFF9EE5B8)
      : const Color(0xFF167347);
  Color get warning => environment == SkyEnvironment.noche
      ? const Color(0xFFFFD08A)
      : const Color(0xFF9A5A00);

  LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerStart, headerMiddle, headerEnd],
  );

  static SkyPalette of(BuildContext context) =>
      Theme.of(context).extension<SkyPalette>() ??
      forEnvironment(SkyEnvironment.dia);

  static SkyPalette forEnvironment(SkyEnvironment value) => switch (value) {
    SkyEnvironment.amanecer => const SkyPalette(
      environment: SkyEnvironment.amanecer,
      headerStart: Color(0xFF454674),
      headerMiddle: Color(0xFF695981),
      headerEnd: Color(0xFF8B6075),
      primary: Color(0xFF58447E),
      accent: Color(0xFF9C526C),
      background: Color(0xFFFAF7FC),
      surface: Color(0xFFFEFBFF),
      text: Color(0xFF292139),
      muted: Color(0xFF60556C),
      border: Color(0xFFE8DDEB),
      soft: Color(0xFFF1EAF6),
    ),
    SkyEnvironment.dia => const SkyPalette(
      environment: SkyEnvironment.dia,
      headerStart: Color(0xFF16466F),
      headerMiddle: Color(0xFF1D638F),
      headerEnd: Color(0xFF327494),
      primary: Color(0xFF145987),
      accent: Color(0xFF157386),
      background: Color(0xFFF4FAFE),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF172B41),
      muted: Color(0xFF526777),
      border: Color(0xFFDCEAF2),
      soft: Color(0xFFEAF5FC),
    ),
    SkyEnvironment.atardecer => const SkyPalette(
      environment: SkyEnvironment.atardecer,
      headerStart: Color(0xFF5C315F),
      headerMiddle: Color(0xFF814064),
      headerEnd: Color(0xFF9A4D55),
      primary: Color(0xFF853C61),
      accent: Color(0xFFAA4B37),
      background: Color(0xFFFFF8F7),
      surface: Color(0xFFFFFCFB),
      text: Color(0xFF382336),
      muted: Color(0xFF725B68),
      border: Color(0xFFF0DEE3),
      soft: Color(0xFFFAEDF0),
    ),
    SkyEnvironment.noche => const SkyPalette(
      environment: SkyEnvironment.noche,
      headerStart: Color(0xFF111C3E),
      headerMiddle: Color(0xFF273260),
      headerEnd: Color(0xFF3B3D70),
      primary: Color(0xFF5864AD),
      accent: Color(0xFFB49CE8),
      background: Color(0xFF0D1731),
      surface: Color(0xFF192645),
      text: Color(0xFFF2F3FF),
      muted: Color(0xFFC0C8E2),
      border: Color(0xFF40517A),
      soft: Color(0xFF27365B),
    ),
  };

  @override
  SkyPalette copyWith({bool? decorationsEnabled}) => SkyPalette(
    environment: environment,
    headerStart: headerStart,
    headerMiddle: headerMiddle,
    headerEnd: headerEnd,
    primary: primary,
    accent: accent,
    background: background,
    surface: surface,
    text: text,
    muted: muted,
    border: border,
    soft: soft,
    decorationsEnabled: decorationsEnabled ?? this.decorationsEnabled,
  );

  @override
  SkyPalette lerp(ThemeExtension<SkyPalette>? other, double t) {
    if (other is! SkyPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return SkyPalette(
      environment: t < .5 ? environment : other.environment,
      headerStart: mix(headerStart, other.headerStart),
      headerMiddle: mix(headerMiddle, other.headerMiddle),
      headerEnd: mix(headerEnd, other.headerEnd),
      primary: mix(primary, other.primary),
      accent: mix(accent, other.accent),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      border: mix(border, other.border),
      soft: mix(soft, other.soft),
      decorationsEnabled: t < .5
          ? decorationsEnabled
          : other.decorationsEnabled,
    );
  }
}

ThemeData skyTheme(SkyPalette palette) {
  final night = palette.environment == SkyEnvironment.noche;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: night ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.accent,
        surface: palette.surface,
        onSurface: palette.text,
        surfaceContainerHighest: palette.soft,
        outline: palette.border,
        error: palette.error,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    dividerColor: palette.border,
    extensions: [palette],
    iconTheme: IconThemeData(color: palette.interactive),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.headerStart,
      foregroundColor: palette.onPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.inputFill,
      labelStyle: TextStyle(color: palette.muted),
      hintStyle: TextStyle(color: palette.muted),
      prefixIconColor: palette.muted,
      suffixIconColor: palette.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.interactive,
        backgroundColor: palette.surface,
        side: BorderSide(color: palette.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.interactive),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: palette.text, fontSize: 15),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: palette.surface),
    popupMenuTheme: PopupMenuThemeData(color: palette.surface),
    listTileTheme: ListTileThemeData(
      iconColor: palette.interactive,
      textColor: palette.text,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      selectedColor: palette.selectedSurface,
      labelStyle: TextStyle(color: palette.text),
      side: BorderSide(color: palette.border),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.soft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.interactive
              : palette.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? palette.text
              : palette.muted,
        ),
      ),
    ),
  );
}
