// lib/shared/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<fb_auth.User> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    // 1️⃣ Create user in Firebase
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final fb_auth.User user = cred.user!;
    await user.updateDisplayName(name);

    // 2️⃣ Mirror the user in Supabase
    try {
      await _supabase
          .from('users')
          .insert({'id': user.uid, 'email': user.email, 'name': name})
          .select()
          .maybeSingle();
    } catch (e) {
      await user.delete();
      throw Exception('Supabase insert failed: $e');
    }

    return user;
  }

  Future<fb_auth.User> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user!;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _supabase.auth.signOut();
  }
}
