// lib/features/onboarding/presentation/login_screen.dart

import 'package:flutter/material.dart';
import 'package:studywithcharles/features/home/presentation/main_screen.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '', _password = '';
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);

    try {
      await AuthService.instance.signIn(email: _email, password: _password);
      Navigator.pushReplacementNamed(context, MainScreen.routeName);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => _email = v!.trim(),
                validator: (v) => v != null && v.contains('@')
                    ? null
                    : 'Valid email required',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onSaved: (v) => _password = v!,
                validator: (v) =>
                    v != null && v.length >= 6 ? null : '6+ chars required',
              ),
              const SizedBox(height: 32),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Log In'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
