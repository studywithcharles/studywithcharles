// lib/shared/services/auth_service.dart

import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- THIS GETTER HAS BEEN ADDED BACK IN. APOLOGIES! ---
  /// Expose the current Firebase user (or null) for synchronous access.
  fb_auth.User? get currentUser => _auth.currentUser;

  /// Expose the auth state changes stream from Firebase for reactive UI.
  Stream<fb_auth.User?> authStateChanges() => _auth.authStateChanges();

  String _makeTimetableCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<fb_auth.User> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final fb_auth.User user = cred.user!;
    await user.updateDisplayName(name);
    final code = _makeTimetableCode();
    try {
      // This database request is now automatically authenticated by the code in main.dart
      await _supabase.from('users').insert({
        'id': user.uid,
        'email': user.email,
        'display_name': name,
        'timetable_code': code,
      });
    } catch (e) {
      await user.delete();
      rethrow;
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

  /// The signOut method now ONLY signs out from Firebase.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
