import 'package:flutter/material.dart';

// ── Semantic palette ──────────────────────────────────────────────────────────
class PulsColors {
  // ── Brand — anchored on the LOGO (neon pulse: mint → pink on dark navy) ──
  static const brandPink = Color(0xFFEC4899);      // primary brand (light)
  static const brandPinkDark = Color(0xFFF472B6);  // primary brand (dark)
  static const brandMint = Color(0xFF2DD4BF);      // gradient partner / teal accent
  static const brandWashLight = Color(0xFFFCE7F3); // pink wash (light surfaces)
  static const brandWashDark = Color(0xFF3B0A2A);  // deep plum (dark surfaces)

  // The signature "pulse" gradient (mint → pink), straight from the logo.
  static const pulseGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF34E5C0), Color(0xFFF65FA9)],
  );

  // Back-compat aliases (old code referenced indigo*) — now brand pink.
  static const indigo = brandPink;
  static const indigoLight = brandWashLight;
  static const indigoDark = Color(0xFFBE185D);

  // Semantic — prediction market YES (teal/mint) / NO (red)
  static const green = Color(0xFF14B8A6);        // teal-green (YES)
  static const greenLight = Color(0xFFE6FAF6);
  static const red = Color(0xFFEF4444);          // clean red (NO)
  static const redLight = Color(0xFFFEECEC);
  static const amber = Color(0xFFF59E0B);        // warm gold
  static const amberLight = Color(0xFFFEF6E7);

  // Neutrals (cool — shared undertone across light & dark)
  static const gray50 = Color(0xFFFAFBFD);
  static const gray100 = Color(0xFFF4F6FA);
  static const gray200 = Color(0xFFE8EBF1);
  static const gray300 = Color(0xFFD6DBE5);
  static const gray400 = Color(0xFF9AA2B5);
  static const gray500 = Color(0xFF56607A);
  static const gray700 = Color(0xFF323A4D);
  static const gray900 = Color(0xFF0E1422);

  // Dark mode — deep navy (echoes the logo background)
  static const dark50 = Color(0xFF0A0E1A);       // navy-black canvas
  static const dark100 = Color(0xFF121829);       // card surface
  static const dark200 = Color(0xFF1B2236);       // raised surface
  static const dark300 = Color(0xFF303B54);       // strong border
  static const dark400 = Color(0xFF5E6A85);       // subtle text
  static const dark500 = Color(0xFF7C88A3);       // muted text
  static const dark600 = Color(0xFF9AA6C0);       // secondary text
  static const dark900 = Color(0xFFEAF0FF);       // primary text

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
  // ── Light: cool white + brand pink / mint ──────────────────────────────
  static const _light = PulsThemeColors(
    bg: Color(0xFFFAFBFD),            // cool off-white canvas
    surface: Color(0xFFFFFFFF),       // pure white cards
    surfaceRaised: Color(0xFFF4F6FA), // cool elevated
    border: Color(0xFFE8EBF1),        // cool border
    borderStrong: Color(0xFFD6DBE5),
    text: Color(0xFF0E1422),          // ink (cool near-black)
    textMuted: Color(0xFF56607A),     // cool gray
    textSubtle: Color(0xFF9AA2B5),    // light cool gray
    brand: Color(0xFFEC4899),         // ★ brand pink (from logo)
    brandSubtle: Color(0xFFFCE7F3),   // ★ light pink wash
    yes: Color(0xFF14B8A6),           // teal-green (YES, from logo mint)
    no: Color(0xFFEF4444),            // clean red (NO)
    yesBg: Color(0xFFE6FAF6),         // light teal wash
    noBg: Color(0xFFFEECEC),          // light red wash
  );

  // ── Dark: navy (logo background) + brand pink / mint ───────────────────
  static const _dark = PulsThemeColors(
    bg: Color(0xFF0A0E1A),            // deep navy-black (echoes logo)
    surface: Color(0xFF121829),        // navy card
    surfaceRaised: Color(0xFF1B2236),  // navy raised
    border: Color(0xFF222B40),         // navy border
    borderStrong: Color(0xFF303B54),   // navy strong border
    text: Color(0xFFEAF0FF),           // cool near-white
    textMuted: Color(0xFF9AA6C0),      // cool muted
    textSubtle: Color(0xFF5E6A85),     // cool subtle
    brand: Color(0xFFF472B6),          // ★ brand pink (lighter for dark)
    brandSubtle: Color(0xFF3B0A2A),    // ★ deep plum subtle
    yes: Color(0xFF2DD4BF),            // ★ bright mint for dark bg
    no: Color(0xFFF87171),             // ★ bright red for dark bg
    yesBg: Color(0xFF0E2E2A),          // ★ dark teal surface
    noBg: Color(0xFF3B1620),           // ★ dark red surface
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
        primary: isLight ? const Color(0xFFEC4899) : const Color(0xFFF472B6),
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
          ? const Color(0xFF0E1422).withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.4),
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
          color: const Color(0xFF0E1422).withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
