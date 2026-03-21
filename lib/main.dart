import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/db/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientação vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializar base de dados local
  await DatabaseHelper.instance.init();

  runApp(const ProviderScope(child: SgcApp()));
}
