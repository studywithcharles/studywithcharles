// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'firebase_options.dart';
import 'config.dart'; // new helper (see below)

import 'package:studywithcharles/features/onboarding/presentation/welcome_screen.dart';
import 'package:studywithcharles/features/onboarding/presentation/signup_screen.dart';
import 'package:studywithcharles/features/onboarding/presentation/login_screen.dart';
import 'package:studywithcharles/features/home/presentation/main_screen.dart';

/// Supabase client
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // On non-web, load .env (mobile/desktop). On web we will use --dart-define values.
    if (!kIsWeb) {
      await dotenv.load(fileName: '.env');
    }

    // Prepare Firebase initialization
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Resolve Supabase config:
    final supabaseUrl = kIsWeb
        ? Config.supabaseUrlFromDartDefine
        : dotenv.env['SUPABASE_URL'];
    final supabaseAnon = kIsWeb
        ? Config.supabaseAnonKeyFromDartDefine
        : dotenv.env['SUPABASE_ANON_KEY'];

    // If missing on web or mobile, show a friendly error instead of crashing.
    if (supabaseUrl == null ||
        supabaseUrl.isEmpty ||
        supabaseAnon == null ||
        supabaseAnon.isEmpty) {
      // Print to console for debugging
      debugPrint(
        'ERROR: Supabase configuration is missing. '
        'supabaseUrl="$supabaseUrl", supabaseAnon="${supabaseAnon != null ? "present" : "null"}"',
      );

      // Launch a tiny error app so the user sees a friendly message instead of white screen
      runApp(
        ConfigErrorApp(
          message:
              'Supabase configuration is missing.\n\nFor web: build with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\nFor mobile: add SUPABASE_URL & SUPABASE_ANON_KEY to your .env file.',
        ),
      );
      return;
    }

    // Initialize Supabase
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnon);

    // Link Firebase auth -> Supabase headers (keeps Supabase requests authorized)
    fb_auth.FirebaseAuth.instance.idTokenChanges().listen((user) async {
      final token = await user?.getIdToken();
      Supabase.instance.client.headers.update(
        'Authorization',
        (value) => 'Bearer ${token ?? ''}',
        ifAbsent: () => 'Bearer ${token ?? ''}',
      );
    });

    runApp(const StudyWithCharlesApp());
  } catch (e, st) {
    // If anything unexpected happens during startup, show a friendly error screen
    debugPrint('Startup error: $e\n$st');
    runApp(
      ConfigErrorApp(
        message:
            'Startup error: $e\n\nCheck the browser console (F12) for details.',
      ),
    );
  }
}

class StudyWithCharlesApp extends StatelessWidget {
  const StudyWithCharlesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study With Charles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black54,
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white70,
        ),
      ),
      home: StreamBuilder<fb_auth.User?>(
        stream: AuthService.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            );
          }
          if (snapshot.hasData) {
            return const MainScreen();
          }
          return const WelcomeScreen();
        },
      ),
      routes: {
        SignupScreen.routeName: (ctx) => const SignupScreen(),
        LoginScreen.routeName: (ctx) => const LoginScreen(),
      },
    );
  }
}

/// Small app that shows an initialization/configuration error instead of a white screen.
class ConfigErrorApp extends StatelessWidget {
  final String message;
  const ConfigErrorApp({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Config error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Configuration error'),
          backgroundColor: Colors.black,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
