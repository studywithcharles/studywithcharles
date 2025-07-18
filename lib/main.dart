// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'package:studywithcharles/features/onboarding/presentation/welcome_screen.dart';
import 'package:studywithcharles/features/onboarding/presentation/signup_screen.dart';
import 'package:studywithcharles/features/onboarding/presentation/login_screen.dart';
import 'package:studywithcharles/features/home/presentation/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Explicitly point to the .env in your project root:
  await dotenv.load(fileName: '.env');

  // 2) Firebase init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3) Supabase init
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black54,
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white70,
        ),
      ),
      initialRoute: WelcomeScreen.routeName,
      routes: {
        WelcomeScreen.routeName: (ctx) => const WelcomeScreen(),
        SignupScreen.routeName: (ctx) => const SignupScreen(),
        LoginScreen.routeName: (ctx) => const LoginScreen(),
        MainScreen.routeName: (ctx) => const MainScreen(),
      },
    );
  }
}
