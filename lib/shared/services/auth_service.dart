import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Expose the current Firebase user (or null)
  fb_auth.User? get currentUser => _auth.currentUser;

  /// Generate an 8‑char alphanumeric timetable code
  String _makeTimetableCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Sign up in Firebase and mirror the user row in Supabase.
  Future<fb_auth.User> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    // 1️⃣ Firebase signup
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final fb_auth.User user = cred.user!;
    await user.updateDisplayName(name);

    // 2️⃣ Mirror in Supabase with a fresh code
    final code = _makeTimetableCode();
    try {
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

  Future<void> signOut() async {
    await _auth.signOut();
    await _supabase.auth.signOut();
  }
}
