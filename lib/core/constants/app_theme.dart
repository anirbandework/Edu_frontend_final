
// lib/core/constants/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Font Families
  static const String bauhausFontFamily = 'BauhausStd-Medium';
  static const String interFontFamily = 'Inter';

  // Primary Colors - Based on your green theme
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  // Extended Color Palette (Green-based alternatives to your indigo theme)
  static const Color greenPrimary = Color(0xFF2E7D32);    
  static const Color greenSecondary = Color(0xFF388E3C);  
  static const Color greenLight = Color(0xFF66BB6A);      
  static const Color green50 = Color(0xFFF1F8E9);        
  static const Color green100 = Color(0xFFDCEDC8);

  // Surface Colors - Based on your glass morphism theme
  static const Color surfacePrimary = Color.fromRGBO(255, 255, 255, 0.95);
  static const Color surfaceSecondary = Color.fromRGBO(249, 250, 251, 0.8);
  static const Color surfaceOverlay = Color.fromRGBO(0, 0, 0, 0.5);
  
  // Background
  static const Color backgroundPrimary = Color(0xFFF8FAFC);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);
  
  // Neutral Colors
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [greenPrimary, greenSecondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientHover = LinearGradient(
    colors: [greenSecondary, greenLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient glassGreenGradient = LinearGradient(
    colors: [
      Color.fromRGBO(46, 125, 50, 0.1),
      Color.fromRGBO(56, 142, 60, 0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // NEW: Additional gradient variations for different use cases
  static const LinearGradient subtleGreenGradient = LinearGradient(
    colors: [
      Color.fromRGBO(46, 125, 50, 0.05),
      Color.fromRGBO(56, 142, 60, 0.02),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient verticalGradient = LinearGradient(
    colors: [greenPrimary, greenSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows - Larger and more prominent
  static const BoxShadow greenShadow = BoxShadow(
    color: Color.fromRGBO(46, 125, 50, 0.12),
    offset: Offset(0, 8),
    blurRadius: 20,
    spreadRadius: -3,
  );

  static const BoxShadow greenShadowLg = BoxShadow(
    color: Color.fromRGBO(46, 125, 50, 0.18),
    offset: Offset(0, 16),
    blurRadius: 32,
    spreadRadius: -10,
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.1),
    offset: Offset(0, 3),
    blurRadius: 6,
    spreadRadius: -1,
  );

  static const BoxShadow glassShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.25),
    offset: Offset(0, 20),
    blurRadius: 40,
    spreadRadius: -10,
  );

  // NEW: Additional shadow variations - Enhanced
  static const BoxShadow microShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.06),
    offset: Offset(0, 2),
    blurRadius: 4,
    spreadRadius: 0,
  );

  static const BoxShadow hoverShadow = BoxShadow(
    color: Color.fromRGBO(46, 125, 50, 0.25),
    offset: Offset(0, 12),
    blurRadius: 28,
    spreadRadius: -6,
  );

  // Border Radius - Increased sizes
  static const BorderRadius borderRadius6 = BorderRadius.all(Radius.circular(6));
  static const BorderRadius borderRadius8 = BorderRadius.all(Radius.circular(8));
  static const BorderRadius borderRadius12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius borderRadius16 = BorderRadius.all(Radius.circular(16));
  static const BorderRadius borderRadius18 = BorderRadius.all(Radius.circular(18));
  static const BorderRadius borderRadius20 = BorderRadius.all(Radius.circular(20));
  static const BorderRadius borderRadius24 = BorderRadius.all(Radius.circular(24));
  static const BorderRadius borderRadius32 = BorderRadius.all(Radius.circular(32));

  // Text Styles - Significantly larger sizes
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,  // Was 24
    fontWeight: FontWeight.bold,
    color: neutral900,
    height: 1.2,
    fontFamily: bauhausFontFamily,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,  // Was 18
    fontWeight: FontWeight.w600,
    color: neutral900,
    height: 1.3,
    fontFamily: bauhausFontFamily,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,  // Was 16
    fontWeight: FontWeight.w600,
    color: neutral900,
    height: 1.4,
    fontFamily: bauhausFontFamily,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,  // Was 14
    fontWeight: FontWeight.w400,
    color: neutral700,
    height: 1.5,
    fontFamily: interFontFamily,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,  // Was 12
    fontWeight: FontWeight.w400,
    color: neutral600,
    height: 1.5,
    fontFamily: interFontFamily,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,  // Was 10
    fontWeight: FontWeight.w400,
    color: neutral500,
    height: 1.4,
    fontFamily: interFontFamily,
  );

  // NEW: Extra small text for micro elements - Still larger
  static const TextStyle bodyMicro = TextStyle(
    fontSize: 12,  // Was 8
    fontWeight: FontWeight.w400,
    color: neutral500,
    height: 1.3,
    fontFamily: interFontFamily,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 18,  // Was 14
    fontWeight: FontWeight.w500,
    color: neutral900,
    height: 1.4,
    fontFamily: bauhausFontFamily,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 16,  // Was 12
    fontWeight: FontWeight.w500,
    color: neutral800,
    height: 1.4,
    fontFamily: bauhausFontFamily,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 14,  // Was 10
    fontWeight: FontWeight.w500,
    color: neutral700,
    height: 1.4,
    fontFamily: bauhausFontFamily,
  );

  // Button Styles - Much larger padding and text
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: greenPrimary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),  // Was 12, 8
    shape: const RoundedRectangleBorder(borderRadius: borderRadius12),
    elevation: 0,
    textStyle: const TextStyle(
      fontSize: 16,  // Was 12
      fontWeight: FontWeight.w500,
      fontFamily: bauhausFontFamily,
    ),
    shadowColor: Colors.transparent,
  );

  static ButtonStyle get primaryButtonHoverStyle => ElevatedButton.styleFrom(
    backgroundColor: greenSecondary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: const RoundedRectangleBorder(borderRadius: borderRadius12),
    elevation: 3,
    shadowColor: greenPrimary.withValues(alpha: 0.3),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: bauhausFontFamily,
    ),
  );

  static ButtonStyle get outlineButtonStyle => OutlinedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: greenPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: const RoundedRectangleBorder(borderRadius: borderRadius12),
    side: const BorderSide(color: greenPrimary, width: 2),  // Increased width
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: bauhausFontFamily,
    ),
  );

  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: greenPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),  // Was 8, 6
    shape: const RoundedRectangleBorder(borderRadius: borderRadius12),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: bauhausFontFamily,
    ),
  );

  // NEW: Additional button variants - Larger
  static ButtonStyle get smallButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: greenPrimary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),  // Was 8, 4
    shape: const RoundedRectangleBorder(borderRadius: borderRadius8),
    elevation: 0,
    textStyle: const TextStyle(
      fontSize: 14,  // Was 10
      fontWeight: FontWeight.w500,
      fontFamily: bauhausFontFamily,
    ),
    minimumSize: const Size(0, 36),  // Was 24
  );

  static ButtonStyle get chipButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: green50,
    foregroundColor: greenPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),  // Was 6, 2
    shape: const RoundedRectangleBorder(borderRadius: borderRadius8),
    elevation: 0,
    textStyle: const TextStyle(
      fontSize: 12,  // Was 9
      fontWeight: FontWeight.w500,
      fontFamily: bauhausFontFamily,
    ),
    minimumSize: const Size(0, 28),  // Was 20
  );

  // Card Styles - Larger radius and padding
  static BoxDecoration get glassCardDecoration => BoxDecoration(
    color: surfacePrimary,
    borderRadius: borderRadius16,  // Was borderRadius10
    border: Border.all(
      color: neutral200.withValues(alpha: 0.5),
      width: 0.8,  // Slightly thicker
    ),
    boxShadow: const [cardShadow],
  );

  static BoxDecoration get glassCardDecorationHover => BoxDecoration(
    color: surfacePrimary,
    borderRadius: borderRadius16,
    border: Border.all(
      color: greenPrimary.withValues(alpha: 0.3),
      width: 1.5,  // Thicker
    ),
    boxShadow: const [greenShadow, cardShadow],
  );

  // NEW: Additional card variations - Enhanced
  static BoxDecoration get microCardDecoration => BoxDecoration(
    color: surfacePrimary,
    borderRadius: borderRadius8,  // Was borderRadius6
    border: Border.all(
      color: neutral200.withValues(alpha: 0.3),
      width: 0.8,
    ),
    boxShadow: const [microShadow],
  );

  static BoxDecoration get compactCardDecoration => BoxDecoration(
    color: surfacePrimary,
    borderRadius: borderRadius12,  // Was borderRadius8
    border: Border.all(
      color: neutral200.withValues(alpha: 0.4),
      width: 0.8,
    ),
    boxShadow: const [cardShadow],
  );

  // Input Decoration - Larger padding and text
  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: neutral50,
    border: const OutlineInputBorder(
      borderRadius: borderRadius12,  // Was borderRadius8
      borderSide: BorderSide(color: neutral300),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: borderRadius12,
      borderSide: BorderSide(color: neutral300),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: borderRadius12,
      borderSide: BorderSide(color: greenPrimary, width: 2),  // Thicker
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: borderRadius12,
      borderSide: BorderSide(color: error, width: 1.5),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: borderRadius12,
      borderSide: BorderSide(color: error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),  // Was 12, 8
    hintStyle: bodyMedium.copyWith(color: neutral400),
    labelStyle: labelMedium,
  );

  // App Bar Theme - Larger text
  static AppBarTheme get appBarTheme => const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,  // Was 16
      fontWeight: FontWeight.w600,
      color: Colors.white,
      fontFamily: bauhausFontFamily,
    ),
    iconTheme: IconThemeData(color: Colors.white, size: 26),  // Was 20
    actionsIconTheme: IconThemeData(color: Colors.white, size: 26),
  );

  // Bottom Navigation Bar Theme - Larger text and icons
  static BottomNavigationBarThemeData get bottomNavTheme => BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: greenPrimary,
    unselectedItemColor: neutral400,
    type: BottomNavigationBarType.fixed,
    elevation: 6,  // Increased
    selectedLabelStyle: labelSmall.copyWith(fontWeight: FontWeight.w600, fontSize: 12),  // Was 9
    unselectedLabelStyle: labelSmall.copyWith(fontSize: 12),
  );

  // Chip Theme - Larger
  static ChipThemeData get chipTheme => ChipThemeData(
    backgroundColor: green50,
    selectedColor: greenPrimary,
    disabledColor: neutral100,
    labelStyle: labelSmall.copyWith(fontSize: 12),  // Was 9
    secondaryLabelStyle: labelSmall.copyWith(color: Colors.white, fontSize: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),  // Was 6, 2
    shape: const RoundedRectangleBorder(borderRadius: borderRadius8),
    side: BorderSide.none,
  );

  // Card Theme - Larger margins and radius
  static CardThemeData get cardTheme => CardThemeData(
    color: Colors.white,
    elevation: 2,  // Increased
    shadowColor: neutral900.withValues(alpha: 0.1),
    shape: const RoundedRectangleBorder(borderRadius: borderRadius12),  // Was borderRadius8
    margin: const EdgeInsets.all(6),  // Was 4
  );

  // Main Light Theme - Updated with larger elements
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: interFontFamily,
    
    colorScheme: ColorScheme.fromSeed(
      seedColor: greenPrimary,
      brightness: Brightness.light,
      primary: greenPrimary,
      secondary: greenSecondary,
      surface: Colors.white,
      background: backgroundPrimary,
      error: error,
    ),
    
    scaffoldBackgroundColor: backgroundPrimary,
    appBarTheme: appBarTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlineButtonStyle),
    textButtonTheme: TextButtonThemeData(style: textButtonStyle),
    cardTheme: cardTheme,
    inputDecorationTheme: inputDecorationTheme,
    bottomNavigationBarTheme: bottomNavTheme,
    chipTheme: chipTheme,
    
    textTheme: const TextTheme(
      headlineLarge: headingLarge,
      headlineMedium: headingMedium,
      headlineSmall: headingSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
      titleLarge: TextStyle(
        fontSize: 24,  // Was 18
        fontWeight: FontWeight.bold,
        color: neutral900,
        fontFamily: bauhausFontFamily,
      ),
      titleMedium: TextStyle(
        fontSize: 18,  // Was 14
        fontWeight: FontWeight.w600,
        color: neutral900,
        fontFamily: bauhausFontFamily,
      ),
      titleSmall: TextStyle(
        fontSize: 16,  // Was 12
        fontWeight: FontWeight.w500,
        color: neutral800,
        fontFamily: bauhausFontFamily,
      ),
    ),
    
    iconTheme: const IconThemeData(color: neutral600, size: 26),  // Was 20
    primaryIconTheme: const IconThemeData(color: Colors.white, size: 26),
    
    dividerTheme: const DividerThemeData(
      color: neutral200,
      thickness: 0.8,  // Slightly thicker
      space: 2,  // More space
    ),
    
    snackBarTheme: SnackBarThemeData(
      backgroundColor: neutral800,
      contentTextStyle: bodyMedium.copyWith(color: Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: borderRadius12),
      behavior: SnackBarBehavior.floating,
    ),
    
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: borderRadius18),  // Was borderRadius12
      titleTextStyle: headingSmall,
      contentTextStyle: bodyMedium,
    ),
    
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),  // Was 16
      ),
    ),
    
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
      indicatorColor: Colors.white,
      labelStyle: labelMedium.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: labelMedium,
    ),
    
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: greenPrimary,
      linearTrackColor: green50,
      circularTrackColor: green50,
    ),
    
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return greenPrimary;
        }
        return neutral400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return greenPrimary.withValues(alpha: 0.5);
        }
        return neutral300;
      }),
    ),
    
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return greenPrimary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: borderRadius8),  // Was borderRadius6
    ),
    
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return greenPrimary;
        }
        return neutral400;
      }),
    ),
    
    sliderTheme: SliderThemeData(
      activeTrackColor: greenPrimary,
      inactiveTrackColor: green50,
      thumbColor: greenPrimary,
      overlayColor: greenPrimary.withValues(alpha: 0.2),
      valueIndicatorColor: greenPrimary,
      valueIndicatorTextStyle: labelSmall.copyWith(color: Colors.white),
    ),
    
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),  // Was 12, 4
      shape: RoundedRectangleBorder(borderRadius: borderRadius12),
      titleTextStyle: labelLarge,
      subtitleTextStyle: bodyMedium,
    ),
  );

  // Utility Methods - Same as before
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'completed':
      case 'active':
        return success;
      case 'warning':
      case 'pending':
        return warning;
      case 'error':
      case 'failed':
      case 'inactive':
        return error;
      case 'info':
      case 'processing':
        return info;
      default:
        return neutral500;
    }
  }

  static BoxDecoration getGlassDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? surfacePrimary,
      borderRadius: borderRadius ?? AppTheme.borderRadius16,  // Was borderRadius10
      border: border ?? Border.all(
        color: neutral200.withValues(alpha: 0.5),
        width: 0.8,
      ),
      boxShadow: const [cardShadow],
    );
  }

  // NEW: Enhanced decoration methods - Larger
  static BoxDecoration getMicroDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? surfacePrimary,
      borderRadius: borderRadius ?? AppTheme.borderRadius8,  // Was borderRadius6
      border: border ?? Border.all(
        color: neutral200.withValues(alpha: 0.3),
        width: 0.8,
      ),
      boxShadow: const [microShadow],
    );
  }

  static BoxDecoration getCompactDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? surfacePrimary,
      borderRadius: borderRadius ?? AppTheme.borderRadius12,  // Was borderRadius8
      border: border ?? Border.all(
        color: neutral200.withValues(alpha: 0.4),
        width: 0.8,
      ),
      boxShadow: const [cardShadow],
    );
  }

  static LinearGradient getGradient({
    List<Color>? colors,
    AlignmentGeometry? begin,
    AlignmentGeometry? end,
  }) {
    return LinearGradient(
      colors: colors ?? [greenPrimary, greenSecondary],
      begin: begin ?? Alignment.centerLeft,
      end: end ?? Alignment.centerRight,
    );
  }

  // Typography utility methods - Larger defaults
  static TextStyle getBauhausStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: bauhausFontFamily,
      fontSize: fontSize ?? 18,  // Was 14
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? neutral900,
      height: height ?? 1.4,
    );
  }

  static TextStyle getInterStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: interFontFamily,
      fontSize: fontSize ?? 16,  // Was 12
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? neutral700,
      height: height ?? 1.5,
    );
  }

  // NEW: Quick access methods for common patterns - Larger values
  static EdgeInsets get paddingMicro => const EdgeInsets.all(4);  // Was 2
  static EdgeInsets get paddingTiny => const EdgeInsets.all(6);   // Was 4
  static EdgeInsets get paddingSmall => const EdgeInsets.all(12); // Was 8
  static EdgeInsets get paddingMedium => const EdgeInsets.all(18); // Was 12
  static EdgeInsets get paddingLarge => const EdgeInsets.all(24);  // Was 16

  static EdgeInsets get marginMicro => const EdgeInsets.all(4);   // Was 2
  static EdgeInsets get marginTiny => const EdgeInsets.all(6);    // Was 4
  static EdgeInsets get marginSmall => const EdgeInsets.all(12);  // Was 8
  static EdgeInsets get marginMedium => const EdgeInsets.all(18); // Was 12
  
  // Icon size constants for easy reference - Larger sizes
  static const double iconMicro = 16;   // Was 12
  static const double iconSmall = 20;   // Was 16
  static const double iconMedium = 26;  // Was 20
  static const double iconLarge = 32;   // Was 24
  static const double iconXLarge = 38;  // Was 28
}
