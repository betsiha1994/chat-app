import 'package:flutter/material.dart';

// 🌈 COLORS
const Color primaryColor = Color(0xFF6C63FF); // Main purple
const Color backgroundColor = Color(0xFFF8F8FC); // Light background
const Color accentColor = Color(0xFF8C8C9E); // Subtext
const Color messageSentColor = Color(0xFF6C63FF); // My messages
const Color messageReceivedColor = Color(0xFFECEBFF); // Other messages

// 🖋️ THEME
final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
  scaffoldBackgroundColor: backgroundColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: TextStyle(color: accentColor),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      borderSide: BorderSide.none,
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF1E1E2D)),
    bodySmall: TextStyle(color: accentColor),
  ),
  useMaterial3: true,
);
