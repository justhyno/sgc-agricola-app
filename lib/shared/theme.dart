import 'package:flutter/material.dart';

const kVerde       = Color(0xFF1A6E3C);
const kVerdeClaro  = Color(0xFF1A3C20);
const kVerdeLight  = Color(0xFFf0fdf4);
const kBorda       = Color(0xFFe5e7eb);
const kCinza       = Color(0xFF6b7280);

const kApiBaseUrl  = 'https://tka.cil.temporary.site/api/v1';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kVerde,
    primary: kVerde,
    secondary: kVerdeClaro,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kVerde,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kVerde,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kVerde, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  ),
  cardTheme: CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: kBorda),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  ),
  scaffoldBackgroundColor: const Color(0xFFF8FFFE),
  fontFamily: 'Roboto',
);
