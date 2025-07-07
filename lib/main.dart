// lib/main.dart (VERSÃO CORRIGIDA E ADAPTADA PARA GEOVIGILÂNCIA)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Importações do Projeto
import 'package:geovigilancia/pages/menu/home_page.dart';
import 'package:geovigilancia/pages/menu/login_page.dart';
import 'package:geovigilancia/pages/menu/equipe_page.dart';
import 'package:geovigilancia/providers/map_provider.dart';
import 'package:geovigilancia/providers/team_provider.dart';
import 'package:geovigilancia/controller/login_controller.dart';
// Import da nova página de campanhas
import 'package:geovigilancia/pages/campanhas/lista_campanhas_page.dart'; // <<< CORREÇÃO DE CAMINHO
import 'package:geovigilancia/pages/menu/splash_page.dart';
import 'package:geovigilancia/providers/license_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: ErrorScreen(
          message: 'Falha ao inicializar o Firebase:\n${e.toString()}',
          onRetry: () => main(),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginController()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => TeamProvider()),
        ChangeNotifierProvider(create: (_) => LicenseProvider())
      ],
      child: MaterialApp(
        title: 'GeoVigilância',
        debugShowCheckedModeBanner: false,
        theme: _buildThemeData(Brightness.light),
        darkTheme: _buildThemeData(Brightness.dark),
        
        initialRoute: '/', 
        
        routes: {
          '/': (context) => const SplashPage(),
          
          '/auth_check': (context) {
            return Consumer<LoginController>(
              builder: (context, loginController, child) {
                if (!loginController.isInitialized) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (loginController.isLoggedIn) {
                  return const EquipePage();
                } else {
                  return const LoginPage();
                }
              },
            );
          },
          
          '/equipe': (context) => const EquipePage(),
          '/home': (context) => const HomePage(title: 'GeoVigilância'), // Nenhuma mudança necessária aqui se a classe for 'HomePage'
          '/lista_campanhas': (context) => const ListaCampanhasPage(title: 'Minhas Campanhas'),
        },
        
        navigatorObservers: [MapProvider.routeObserver],
        
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            debugPrint('Erro de Flutter capturado: ${details.exception}');
            return ErrorScreen(
              message: 'Ocorreu um erro inesperado.\nPor favor, reinicie o aplicativo.',
              onRetry: null,
            );
          };
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!,
          );
        },
      ),
    );
  }

  ThemeData _buildThemeData(Brightness brightness) {
    final baseColor = brightness == Brightness.light ? const Color(0xFF0D47A1) : Colors.blue.shade800;
    final secondaryColor = Colors.amber.shade700;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: brightness,
        primary: baseColor,
        secondary: secondaryColor,
        error: Colors.red.shade800,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light ? baseColor : Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: baseColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      // <<< CORREÇÃO AQUI >>>
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(color: brightness == Brightness.light ? baseColor : Colors.white, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: brightness == Brightness.light ? baseColor : Colors.white),
        bodyLarge: TextStyle(color: brightness == Brightness.light ? Colors.black87 : Colors.white70),
        bodyMedium: TextStyle(color: brightness == Brightness.light ? Colors.black54 : Colors.white60),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: baseColor, width: 2.0),
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  // <<< CORREÇÃO AQUI: 'const' removido >>>
  ErrorScreen({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 60),
              const SizedBox(height: 20),
              Text(
                'Application Error',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              if (onRetry != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary, // Agora isso funciona
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRetry,
                  child: const Text('Tentar Novamente'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}