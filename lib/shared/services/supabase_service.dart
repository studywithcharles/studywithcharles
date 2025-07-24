// lib/shared/services/supabase_service.dart

import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // ─── CONTEXTS ────────────────────────────────────────────────────────────────

  /// Creates a new context and returns its generated UUID.
  Future<String> createContext({
    required String title,
    required String resultFormat,
    String? moreContext,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final userId = firebaseUser.uid;

    final newId = _uuid.v4();
    final inserted = await _supabase
        .from('contexts')
        .insert({
          'id': newId,
          'user_id': userId,
          'title': title,
          'result_format': resultFormat,
          'more_context': moreContext,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<List<Map<String, dynamic>>> fetchContexts() async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return [];
    final userId = firebaseUser.uid;

    final rows = await _supabase
        .from('contexts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> updateContext({
    required String id,
    String? title,
    String? resultFormat,
    String? moreContext,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (resultFormat != null) updates['result_format'] = resultFormat;
    if (moreContext != null) updates['more_context'] = moreContext;

    final row = await _supabase
        .from('contexts')
        .update(updates)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (row == null) throw Exception('Context not found');
    return Map<String, dynamic>.from(row as Map);
  }

  Future<void> deleteContext(String id) async {
    await _supabase.from('contexts').delete().eq('id', id);
  }

  // ─── CARDS ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCard({
    required String contextId,
    required Map<String, dynamic> content,
    required String type,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final userId = firebaseUser.uid;

    final newId = _uuid.v4();
    final row = await _supabase
        .from('cards')
        .insert({
          'id': newId,
          'context_id': contextId,
          'user_id': userId,
          'content': content,
          'type': type,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  Future<List<Map<String, dynamic>>> fetchCards(String contextId) async {
    final rows = await _supabase
        .from('cards')
        .select()
        .eq('context_id', contextId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Count how many cards the user has saved since [since].
  Future<int> countSavedCardsSince({
    required String contextId,
    required DateTime since,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final userId = firebaseUser.uid;

    final rows = await _supabase
        .from('cards')
        .select()
        .eq('context_id', contextId)
        .eq('user_id', userId)
        .eq('saved', true)
        .gte('saved_at', since.toIso8601String());
    return (rows as List).length;
  }

  /// Saves a card (marks it saved + timestamp).
  Future<void> saveCard({
    required String contextId,
    required Map<String, dynamic> content,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final userId = firebaseUser.uid;

    await _supabase.from('cards').insert({
      'id': _uuid.v4(),
      'context_id': contextId,
      'user_id': userId,
      'content': content,
      'type': content['type'] ?? 'text',
      'saved': true,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── EVENTS ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createEvent({
    required String groupId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final userId = firebaseUser.uid;

    final newId = _uuid.v4();
    final row = await _supabase
        .from('events')
        .insert({
          'id': newId,
          'user_id': userId,
          'group_id': groupId,
          'title': title,
          'description': description,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  Future<List<Map<String, dynamic>>> fetchEvents(String groupId) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return [];
    final userId = firebaseUser.uid;

    final rows = await _supabase
        .from('events')
        .select()
        .or('group_id.eq.$groupId,user_id.eq.$userId')
        .order('start_time', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
