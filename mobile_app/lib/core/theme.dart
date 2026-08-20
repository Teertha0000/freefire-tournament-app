import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors based on the reference gradient
  static const Color primaryCyan = Color(0xFF4AC2F6);
  static const Color secondaryCyan = Color(0xFF86E2F5);
  static const Color deepBlueGlow = Color(0xFF0B1F4A);
  
  // Background & Surface
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color surfaceGrey = Color(0xFF15151A); // Slightly bluish dark grey
  
  // Text Colors
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFA1A1AA);

  // Reusable Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, secondaryCyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundBlack,
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryCyan,
        surface: surfaceGrey,
        background: backgroundBlack,
      ),
      fontFamily: 'Outfit', // Continuing to use Outfit as per previous rules
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
