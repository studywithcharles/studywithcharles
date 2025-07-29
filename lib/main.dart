// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'firebase_options.dart';

import 'package:studywithcharles/features/onboarding/presentation/welcome_screen.dart';
import 'package:studywithcharles/features/onboarding/presentation/signup_screen.dart';
import 'package:studywithcharles/features/onboarding/presentation/login_screen.dart';
import 'package:studywithcharles/features/home/presentation/main_screen.dart';

/// Supabase client
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  AuthService.instance.authStateChanges().listen((firebaseUser) async {
    if (firebaseUser != null) {
      final token = await firebaseUser.getIdToken();
      if (token != null) {
        try {
          await supabase.auth.setSession(token);
        } catch (e) {
          // You can add logging here if you want
        }
      }
    } else {
      await supabase.auth.signOut();
    }
  });

  runApp(const StudyWithCharlesApp());
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
      // DEFINITIVE FIX: The routes map should ONLY contain screens that we
      // navigate to by name. WelcomeScreen and MainScreen are now handled
      // by the logic in the 'home' property above.
      routes: {
        SignupScreen.routeName: (ctx) => const SignupScreen(),
        LoginScreen.routeName: (ctx) => const LoginScreen(),
      },
    );
  }
}
