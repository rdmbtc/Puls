import 'package:flutter/material.dart';

// ── Semantic palette ──────────────────────────────────────────────────────────
class PulsColors {
  // Brand — vibrant indigo throughout
  static const indigo = Color(0xFF4F46E5);
  static const indigoLight = Color(0xFFEEF2FF);
  static const indigoDark = Color(0xFF3730A3);

  // Semantic — muted editorial market colors
  static const green = Color(0xFF2D8A56);       // forest green (YES)
  static const greenLight = Color(0xFFF0F7F3);
  static const red = Color(0xFFC0392B);          // terracotta (NO)
  static const redLight = Color(0xFFFDF2F1);
  static const amber = Color(0xFFC9A96E);        // warm gold
  static const amberLight = Color(0xFFFAF6EE);

  // Neutrals (warm gray — editorial)
  static const gray50 = Color(0xFFFAFAF7);
  static const gray100 = Color(0xFFF5F4EF);
  static const gray200 = Color(0xFFEDEDEB);
  static const gray300 = Color(0xFFD8D8D4);
  static const gray400 = Color(0xFF9A9A94);
  static const gray500 = Color(0xFF5A5A5A);
  static const gray700 = Color(0xFF3A3A3A);
  static const gray900 = Color(0xFF1A1A1A);

  // Dark mode — neutral charcoal darks (de-slop, no indigo tint)
  static const dark50 = Color(0xFF0D1117);       // neutral charcoal-black
  static const dark100 = Color(0xFF161B22);       // card surface
  static const dark200 = Color(0xFF21262D);       // raised surface / border
  static const dark300 = Color(0xFF30363D);       // strong border
  static const dark400 = Color(0xFF6E7681);       // subtle text
  static const dark500 = Color(0xFF7D8694);       // muted text
  static const dark600 = Color(0xFFAEB6C2);       // secondary text
  static const dark900 = Color(0xFFF0F3F8);       // primary text

  // Font families
  static const fontDisplay = 'Playfair Display';
  static const fontSans = 'DM Sans';

  // Tabular figures for numbers — applied to price/win-rate/amount text
  static const tabularFigures = [FontFeature.tabularFigures()];
}

// ── Theme extension ───────────────────────────────────────────────────────────
@immutable
class PulsThemeColors extends ThemeExtension<PulsThemeColors> {
  const PulsThemeColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.brand,
    required this.brandSubtle,
    required this.yes,
    required this.no,
    required this.yesBg,
    required this.noBg,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color brand;
  final Color brandSubtle;
  final Color yes;
  final Color no;
  final Color yesBg;
  final Color noBg;

  @override
  PulsThemeColors copyWith({
    Color? bg, Color? surface, Color? surfaceRaised,
    Color? border, Color? borderStrong,
    Color? text, Color? textMuted, Color? textSubtle,
    Color? brand, Color? brandSubtle,
    Color? yes, Color? no, Color? yesBg, Color? noBg,
  }) => PulsThemeColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    textSubtle: textSubtle ?? this.textSubtle,
    brand: brand ?? this.brand,
    brandSubtle: brandSubtle ?? this.brandSubtle,
    yes: yes ?? this.yes,
    no: no ?? this.no,
    yesBg: yesBg ?? this.yesBg,
    noBg: noBg ?? this.noBg,
  );

  @override
  PulsThemeColors lerp(ThemeExtension<PulsThemeColors>? other, double t) {
    if (other is! PulsThemeColors) return this;
    return PulsThemeColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      yes: Color.lerp(yes, other.yes, t)!,
      no: Color.lerp(no, other.no, t)!,
      yesBg: Color.lerp(yesBg, other.yesBg, t)!,
      noBg: Color.lerp(noBg, other.noBg, t)!,
    );
  }
}

extension PulsThemeX on BuildContext {
  PulsThemeColors get puls => Theme.of(this).extension<PulsThemeColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── Theme builder ─────────────────────────────────────────────────────────────
class PulsTheme {
  // ── Light: White + Indigo ──────────────────────────────────────────────
  static const _light = PulsThemeColors(
    bg: Color(0xFFFAFAF7),           // warm off-white canvas
    surface: Color(0xFFFFFFFF),       // pure white cards
    surfaceRaised: Color(0xFFF5F4EF), // warm elevated
    border: Color(0xFFEDEDEB),        // warm border
    borderStrong: Color(0xFFD8D8D4),
    text: Color(0xFF1A1A1A),          // rich black text
    textMuted: Color(0xFF5A5A5A),     // warm gray
    textSubtle: Color(0xFF9A9A94),    // light warm gray
    brand: Color(0xFF4F46E5),         // ★ vibrant indigo
    brandSubtle: Color(0xFFEEF2FF),   // ★ light indigo wash
    yes: Color(0xFF2D8A56),           // forest green
    no: Color(0xFFC0392B),            // terracotta red
    yesBg: Color(0xFFF0F7F3),         // light green wash
    noBg: Color(0xFFFDF2F1),          // light red wash
  );

  // ── Dark: Black + Indigo ──────────────────────────────────────────────
  static const _dark = PulsThemeColors(
    bg: Color(0xFF0D1117),            // neutral charcoal-black (de-slop, no indigo tint)
    surface: Color(0xFF161B22),        // neutral card
    surfaceRaised: Color(0xFF21262D),  // neutral raised
    border: Color(0xFF21262D),         // neutral border
    borderStrong: Color(0xFF30363D),   // neutral strong border
    text: Color(0xFFF0F3F8),           // neutral near-white
    textMuted: Color(0xFFAEB6C2),      // neutral muted
    textSubtle: Color(0xFF7D8694),     // neutral subtle
    brand: Color(0xFF818CF8),          // ★ lighter indigo for dark
    brandSubtle: Color(0xFF1E1B4B),    // ★ deep indigo subtle
    yes: Color(0xFF4ADE80),            // ★ bright green for dark bg
    no: Color(0xFFF87171),             // ★ bright red for dark bg
    yesBg: Color(0xFF14332A),          // ★ dark green surface
    noBg: Color(0xFF331A1A),           // ★ dark red surface
  );

  static ThemeData light() => _build(Brightness.light, _light);
  static ThemeData dark() => _build(Brightness.dark, _dark);

  static ThemeData _build(Brightness brightness, PulsThemeColors t) {
    final isLight = brightness == Brightness.light;
    const displayFont = PulsColors.fontDisplay;
    const bodyFont = PulsColors.fontSans;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.bg,
      extensions: [t],
      fontFamily: bodyFont,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          color: t.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: t.text, size: 22),
      ),
      cardTheme: CardThemeData(
        color: t.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.brand, width: 1.5),
        ),
        hintStyle: TextStyle(fontFamily: bodyFont, color: t.textSubtle, fontSize: 14),
        labelStyle: TextStyle(fontFamily: bodyFont, color: t.textMuted),
        prefixStyle: TextStyle(fontFamily: bodyFont, color: t.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceRaised,
        contentTextStyle: TextStyle(fontFamily: bodyFont, color: t.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: isLight ? const Color(0xFF4F46E5) : const Color(0xFF818CF8),
        onPrimary: Colors.white,
        secondary: t.brand,
        onSecondary: Colors.white,
        surface: t.surface,
        onSurface: t.text,
        surfaceContainerHighest: t.surfaceRaised,
        error: PulsColors.red,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        // Serif display — Playfair Display
        displaySmall: TextStyle(
          fontFamily: displayFont,
          color: t.text, fontSize: 30, fontWeight: FontWeight.w700,
          height: 1.12, letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontFamily: displayFont,
          color: t.text, fontSize: 22, fontWeight: FontWeight.w700,
          height: 1.2, letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontFamily: displayFont,
          color: t.text, fontSize: 18, fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        // Sans body — DM Sans
        titleMedium: TextStyle(
          fontFamily: bodyFont,
          color: t.text, fontSize: 15, fontWeight: FontWeight.w600,
          fontFeatures: PulsColors.tabularFigures,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFont,
          color: t.text, fontSize: 15, height: 1.6,
          fontFeatures: PulsColors.tabularFigures,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          color: t.textMuted, fontSize: 13, height: 1.5,
          fontFeatures: PulsColors.tabularFigures,
        ),
        labelLarge: TextStyle(
          fontFamily: bodyFont,
          color: t.text, fontSize: 14, fontWeight: FontWeight.w600,
          fontFeatures: PulsColors.tabularFigures,
        ),
        labelSmall: TextStyle(
          fontFamily: bodyFont,
          color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          fontFeatures: PulsColors.tabularFigures,
        ),
      ),
      // Soft shadow for cards — indigo-tinted
      shadowColor: isLight
          ? const Color(0xFF4F46E5).withValues(alpha: 0.06)
          : const Color(0xFF4F46E5).withValues(alpha: 0.3),
    );
  }
}

// ── Shared card decoration ────────────────────────────────────────────────────
BoxDecoration cardDecoration(PulsThemeColors t, {double radius = 16}) =>
    BoxDecoration(
      color: t.surfaceRaised,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: t.border),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
