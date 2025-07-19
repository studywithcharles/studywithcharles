// lib/shared/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart'; // adjust path if needed

/// High‑level Supabase API service for your app’s features.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final SupabaseClient _supabase = SupabaseClientWrapper.instance.client;

  // ─── CONTEXTS ────────────────────────────────────────────────────────────────

  /// Inserts a new study context and returns the inserted row.
  Future<Map<String, dynamic>> createContext({
    required String title,
    required String resultFormat,
    required String moreContext,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    // .select() makes Supabase return the inserted row(s) as List<Map>.
    final rows = await _supabase.from('contexts').insert({
      'id': userId, // or generate your own UUID string
      'user_id': userId,
      'title': title,
      'result_format': resultFormat,
      'more_context': moreContext,
    }).select();
    // rows is List<dynamic>; convert to Map<String, dynamic>
    return Map<String, dynamic>.from((rows as List).first);
  }

  /// Fetches all contexts for the current user, ordered newest→oldest.
  Future<List<Map<String, dynamic>>> fetchMyContexts() async {
    final userId = _supabase.auth.currentUser!.id;
    final rows = await _supabase
        .from('contexts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    // cast List<dynamic> → List<Map<String, dynamic>>
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ─── CARDS ───────────────────────────────────────────────────────────────────

  /// Inserts a new card under a context and returns the inserted row.
  Future<Map<String, dynamic>> createCard({
    required String contextId,
    required Map<String, dynamic> content,
    required String type,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final rows = await _supabase.from('cards').insert({
      'id': userId,
      'context_id': contextId,
      'user_id': userId,
      'content': content,
      'type': type,
    }).select();
    return Map<String, dynamic>.from((rows as List).first);
  }

  /// Fetches cards for a given context.
  Future<List<Map<String, dynamic>>> fetchCards(String contextId) async {
    final rows = await _supabase
        .from('cards')
        .select()
        .eq('context_id', contextId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ─── EVENTS ──────────────────────────────────────────────────────────────────

  /// Inserts a new event and returns the inserted row.
  Future<Map<String, dynamic>> createEvent({
    required String groupId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final rows = await _supabase.from('events').insert({
      'id': userId,
      'user_id': userId,
      'group_id': groupId,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
    }).select();
    return Map<String, dynamic>.from((rows as List).first);
  }

  /// Fetches events for a group or owned by the user.
  Future<List<Map<String, dynamic>>> fetchEvents(String groupId) async {
    final userId = _supabase.auth.currentUser!.id;
    final rows = await _supabase
        .from('events')
        .select()
        .or('group_id.eq.$groupId,user_id.eq.$userId')
        .order('start_time', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ─── MORE FEATURES ──────────────────────────────────────────────────────────
  // Follow the same pattern for TCA, council, voting, etc.
}
