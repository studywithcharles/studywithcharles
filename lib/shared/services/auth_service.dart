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

  /// Expose the auth state changes stream from Firebase
  Stream<fb_auth.User?> authStateChanges() => _auth.authStateChanges();

  /// Generate an 8-char alphanumeric timetable code
  String _makeTimetableCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Helper function to sync the Firebase token with Supabase
  Future<void> _syncSupabaseSession(fb_auth.User user) async {
    final token = await user.getIdToken();
    if (token != null) {
      await _supabase.auth.setSession(token);
    } else {
      throw 'Could not get Firebase token.';
    }
  }

  /// Sign up in Firebase, mirror in Supabase, and sync the session.
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
      await _supabase.from('users').insert({
        'id': user.uid,
        'email': user.email,
        'display_name': name,
        'timetable_code': code,
      });
      // Sync session immediately after creating the user
      await _syncSupabaseSession(user);
    } catch (e) {
      await user.delete();
      rethrow;
    }
    return user;
  }

  /// Sign in with Firebase and immediately sync the session with Supabase.
  Future<fb_auth.User> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Sync session immediately after logging in
    await _syncSupabaseSession(cred.user!);
    return cred.user!;
  }

  /// Sign out of both Firebase and Supabase.
  Future<void> signOut() async {
    await _auth.signOut();
    await _supabase.auth.signOut();
  }
}
