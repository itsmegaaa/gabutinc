import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'controllers/form_laporan_controller.dart';
import 'data/repositories/laporan_repository.dart';
import 'controllers/user_provider.dart';
import 'controllers/laporan_controller.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/portal/home_screen.dart';
import 'controllers/theme_controller.dart';

// ============================================================================
// MAIN FUNCTION
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 40 * 1024 * 1024,
  );

  final themeCtrl = ThemeController();
  await themeCtrl.muatDariPrefs();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: themeCtrl),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        Provider(create: (_) => LaporanRepository()),
        ChangeNotifierProvider(
          create: (ctx) =>
              LaporanController(repo: ctx.read<LaporanRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              FormLaporanController(repo: context.read<LaporanRepository>()),
        )
      ],
      child: const MyApp(),
    ),
  );
}

// ============================================================================
// APP ROOT WIDGET
// ============================================================================
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();

    return MaterialApp(
      title: 'SIRA',
      debugShowCheckedModeBanner: false,
      themeMode: themeCtrl.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Tema Terang (Sesuai Panduan UI)
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // bgColor
        primaryColor: const Color(0xFF0F172A), // navyColor
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F172A),
          secondary: Color(0xFFD4AF37), // goldColor
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),

      // Tema Gelap (Sesuai Panduan UI)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // darkBg
        primaryColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0F172A),
          secondary: Color(0xFFD4AF37),
          surface: Color(0xFF1E1E1E), // darkSurface
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF1E1E1E),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),

      home: const AuthGate(),
    );
  }
}

// ============================================================================
// AUTH GATE
// ============================================================================
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD4AF37), // goldColor
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
