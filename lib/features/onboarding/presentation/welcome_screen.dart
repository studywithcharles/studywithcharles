// lib/features/onboarding/presentation/welcome_screen.dart

import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  static const routeName = '/welcome';
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Study With Charles',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 64),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, SignupScreen.routeName),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Sign Up'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, LoginScreen.routeName),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}
