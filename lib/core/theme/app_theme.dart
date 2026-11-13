import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// FemaleRider brand palette.
abstract final class AppColors {
  static const crimson = Color(0xFFC8102E);
  static const deepRed = Color(0xFF7A0A12);
  static const crimsonDark = Color(0xFFA00D25);
  static const rose = Color(0xFFF7D6DC);
  static const roseSoft = Color(0xFFFCEFF1);
  static const roseAccent = Color(0xFFE8798A);

  static const ink = Color(0xFF16161A);
  static const inkSoft = Color(0xFF3A3A42);
  static const muted = Color(0xFF6E6E78);
  static const subtle = Color(0xFF9A9AA3);
  static const line = Color(0xFFE9E7EA);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F6F8);
  static const field = Color(0xFFF3F2F5);

  /// Driver mode header / accents.
  static const night = Color(0xFF141418);
  static const nightSoft = Color(0xFF23232A);
  static const nightLine = Color(0xFF34343D);

  static const success = Color(0xFF1E8E5A);
  static const successSoft = Color(0xFFE3F5EC);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFDF3E1);
  static const danger = Color(0xFFD92D20);
  static const dangerSoft = Color(0xFFFDE8E7);
  static const info = Color(0xFF2563EB);
  static const infoSoft = Color(0xFFE8EFFD);

  static const brandGradient = LinearGradient(
    colors: [crimson, deepRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const driverGradient = LinearGradient(
    colors: [Color(0xFF23232A), night],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// 4-pt spacing scale.
abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;

  static final card = BorderRadius.circular(lg);
  static final input = BorderRadius.circular(md);
  static final button = BorderRadius.circular(md);
  static const sheet = BorderRadius.vertical(top: Radius.circular(xl));
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0F16161A), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A16161A), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x2416161A), blurRadius: 30, offset: Offset(0, 12)),
  ];
  static const brand = [
    BoxShadow(color: Color(0x40C8102E), blurRadius: 20, offset: Offset(0, 8)),
  ];
}

/// Typography scale (system font: Roboto / SF Pro), tuned for a dense mobile UI.
abstract final class AppText {
  static const display = TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8, color: AppColors.ink);
  static const h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5, color: AppColors.ink);
  static const h2 = TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3, color: AppColors.ink);
  static const h3 = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.1, color: AppColors.ink);
  static const title = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35, color: AppColors.ink);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45, color: AppColors.inkSoft);
  static const bodySm = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.muted);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0.1, color: AppColors.inkSoft);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: AppColors.muted);
  static const overline = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 1.2, color: AppColors.muted);
  static const money = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.6, color: AppColors.ink, fontFeatures: [FontFeature.tabularFigures()]);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.crimson,
    primary: AppColors.crimson,
    onPrimary: Colors.white,
    secondary: AppColors.deepRed,
    onSecondary: Colors.white,
    tertiary: AppColors.roseAccent,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    brightness: Brightness.light,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.light);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.copyWith(
      displaySmall: AppText.display,
      headlineMedium: AppText.h1,
      headlineSmall: AppText.h2,
      titleLarge: AppText.h3,
      titleMedium: AppText.title,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.bodySm,
      labelLarge: AppText.label.copyWith(fontSize: 15),
      labelMedium: AppText.label,
      labelSmall: AppText.caption,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: AppText.h3,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card, side: const BorderSide(color: AppColors.line)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.crimson,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.subtle,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: AppColors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.crimson,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 16),
      hintStyle: AppText.body.copyWith(color: AppColors.subtle),
      labelStyle: AppText.body.copyWith(color: AppColors.muted),
      floatingLabelStyle: AppText.label.copyWith(color: AppColors.crimson),
      border: OutlineInputBorder(borderRadius: AppRadius.input, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.input, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.input, borderSide: const BorderSide(color: AppColors.crimson, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: AppRadius.input, borderSide: const BorderSide(color: AppColors.danger, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: AppRadius.input, borderSide: const BorderSide(color: AppColors.danger, width: 1.6)),
      errorStyle: AppText.caption.copyWith(color: AppColors.danger),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.roseSoft,
      side: const BorderSide(color: AppColors.line),
      labelStyle: AppText.label,
      secondaryLabelStyle: AppText.label.copyWith(color: AppColors.crimson),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      checkmarkColor: AppColors.crimson,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.line,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      titleTextStyle: AppText.h3,
      contentTextStyle: AppText.body,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.body.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 2),
      iconColor: AppColors.inkSoft,
      titleTextStyle: AppText.title,
      subtitleTextStyle: AppText.bodySm,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.crimson : AppColors.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.crimson : Colors.transparent),
      side: const BorderSide(color: AppColors.subtle, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.crimson, linearTrackColor: AppColors.rose),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.crimson,
      inactiveTrackColor: AppColors.rose,
      thumbColor: AppColors.crimson,
      overlayColor: Color(0x22C8102E),
      trackHeight: 6,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.roseSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(AppText.caption),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.crimson,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.crimson,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      dividerColor: AppColors.line,
    ),
    // Android uses the modern fade-forwards transition; iOS keeps the platform default (Cupertino).
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      ...const PageTransitionsTheme().builders,
      TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
