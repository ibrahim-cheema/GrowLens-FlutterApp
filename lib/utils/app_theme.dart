import 'package:flutter/material.dart';

class AppTheme {
  // Your custom color palette
  static const Color primaryLight = Color(0xFFEEFB8F); // Light lime green
  static const Color primary = Color(0xFF8FB25C);      // Medium green
  static const Color primaryDark = Color(0xFF447804);  // Dark green
  static const Color accent = Color(0xFF346E05);       // Deep green
  static const Color background = Color(0xFF243C07);   // Dark forest green

  // Light Theme - SIMPLIFIED VERSION
  static final lightTheme = ThemeData(
    useMaterial3: false,

    // Primary Colors
    primaryColor: primary,
    primaryColorDark: primaryDark,
    primaryColorLight: primaryLight,

    // Background Colors
    scaffoldBackgroundColor: Colors.white,

    // App Bar
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.black54,
      ),
    ),
  );

  // Dark Theme - SIMPLIFIED VERSION
  static final darkTheme = ThemeData(
    useMaterial3: false,

    // Primary Colors
    primaryColor: primary,

    // Background Colors
    scaffoldBackgroundColor: background,

    // Brightness
    brightness: Brightness.dark,

    // App Bar
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      elevation: 0,
    ),
  );
}