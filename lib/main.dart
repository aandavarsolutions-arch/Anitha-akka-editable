import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/data_provider.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'providers/billing_provider.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => BillingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aandavar Solutions',
      debugShowCheckedModeBanner: false,
      theme: JarvisTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
