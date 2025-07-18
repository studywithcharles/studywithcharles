// lib/features/onboarding/presentation/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/features/home/presentation/main_screen.dart';

class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignupScreen({super.key});

  @override
  SignupScreenState createState() => SignupScreenState();
}

class SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '', _password = '', _name = '';
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);

    try {
      // This now creates the Firebase user AND mirrors them in Supabase.
      await AuthService.instance.signUp(
        email: _email,
        password: _password,
        name: _name,
      );
      // On success, navigate into your main app screen
      Navigator.pushReplacementNamed(context, MainScreen.routeName);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Name
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                onSaved: (v) => _name = v!.trim(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => _email = v!.trim(),
                validator: (v) => (v != null && v.contains('@'))
                    ? null
                    : 'Valid email required',
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onSaved: (v) => _password = v!,
                validator: (v) => (v != null && v.length >= 6)
                    ? null
                    : 'Password must be at least 6 characters',
              ),
              const SizedBox(height: 32),

              // Submit button or loader
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Create Account'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
