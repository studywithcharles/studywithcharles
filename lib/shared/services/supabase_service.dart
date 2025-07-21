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
    String? moreContext,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final rows =
        await _supabase.from('contexts').insert({
              'id': userId, // or generate your own UUID string
              'user_id': userId,
              'title': title,
              'result_format': resultFormat,
              'more_context': moreContext,
            }).select()
            as List<dynamic>;

    return Map<String, dynamic>.from(rows.first as Map);
  }

  /// Fetches all contexts for the current user, newest first.
  Future<List<Map<String, dynamic>>> fetchContexts() async {
    final userId = _supabase.auth.currentUser!.id;
    final rows = await _supabase.from('contexts').select() as List<dynamic>;
    // filter and sort client‑side if needed, or apply eq / order in the query:
    final filtered =
        rows
            .cast<Map<String, dynamic>>()
            .where((c) => c['user_id'] == userId)
            .toList()
          ..sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
    return filtered;
  }

  /// Updates an existing context by its ID and returns the updated row.
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

    final rows =
        await _supabase.from('contexts').update(updates).eq('id', id).select()
            as List<dynamic>;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  /// Deletes a context by its ID.
  Future<void> deleteContext(String id) async {
    await _supabase.from('contexts').delete().eq('id', id);
  }

  // ─── CARDS ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCard({
    required String contextId,
    required Map<String, dynamic> content,
    required String type,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final rows =
        await _supabase.from('cards').insert({
              'id': userId,
              'context_id': contextId,
              'user_id': userId,
              'content': content,
              'type': type,
            }).select()
            as List<dynamic>;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<List<Map<String, dynamic>>> fetchCards(String contextId) async {
    final rows = await _supabase.from('cards').select() as List<dynamic>;
    return rows
        .cast<Map<String, dynamic>>()
        .where((c) => c['context_id'] == contextId)
        .toList()
      ..sort(
        (a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String),
      );
  }

  // ─── EVENTS ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createEvent({
    required String groupId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final rows =
        await _supabase.from('events').insert({
              'id': userId,
              'user_id': userId,
              'group_id': groupId,
              'title': title,
              'description': description,
              'start_time': startTime.toIso8601String(),
              'end_time': endTime.toIso8601String(),
            }).select()
            as List<dynamic>;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<List<Map<String, dynamic>>> fetchEvents(String groupId) async {
    final userId = _supabase.auth.currentUser!.id;
    final rows = await _supabase.from('events').select() as List<dynamic>;
    return rows
        .cast<Map<String, dynamic>>()
        .where((e) => e['group_id'] == groupId || e['user_id'] == userId)
        .toList()
      ..sort(
        (a, b) =>
            (a['start_time'] as String).compareTo(b['start_time'] as String),
      );
  }

  // ─── MORE FEATURES ──────────────────────────────────────────────────────────
  // Add update/delete for cards, events, TCA, etc., following the same pattern.
}
