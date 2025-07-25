// lib/shared/services/supabase_service.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // ─── USER PROFILE ───────────────────────────────────────────────────────────
  /// Fetches a single user row (including timetable_code) from the 'users' table.
  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    final row = await _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  // ─── CONTEXTS ────────────────────────────────────────────────────────────────
  Future<String> createContext({
    required String title,
    required String resultFormat,
    String? moreContext,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');

    final newId = _uuid.v4();
    final inserted = await _supabase
        .from('contexts')
        .insert({
          'id': newId,
          'user_id': firebaseUser.uid,
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

    final rows = await _supabase
        .from('contexts')
        .select()
        .eq('user_id', firebaseUser.uid)
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

    final newId = _uuid.v4();
    final row = await _supabase
        .from('cards')
        .insert({
          'id': newId,
          'context_id': contextId,
          'user_id': firebaseUser.uid,
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

  Future<int> countSavedCardsSince({
    required String contextId,
    required DateTime since,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');

    final rows = await _supabase
        .from('cards')
        .select()
        .eq('context_id', contextId)
        .eq('user_id', firebaseUser.uid)
        .eq('saved', true)
        .gte('saved_at', since.toIso8601String());
    return (rows as List).length;
  }

  Future<void> saveCard({
    required String contextId,
    required Map<String, dynamic> content,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');

    await _supabase.from('cards').insert({
      'id': _uuid.v4(),
      'context_id': contextId,
      'user_id': firebaseUser.uid,
      'content': content,
      'type': content['type'] ?? 'text',
      'saved': true,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── ATTACHMENTS ────────────────────────────────────────────────────────────
  Future<String> uploadAttachment(File file) async {
    final ext = file.path.split('.').last;
    final path = 'attachments/${_uuid.v4()}.$ext';
    await _supabase.storage.from('event-images').upload(path, file);
    return _supabase.storage.from('event-images').getPublicUrl(path);
  }

  // ─── EVENTS ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createEvent({
    required String groupId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String? repeatRule,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');

    final newId = _uuid.v4();
    final row = await _supabase
        .from('events')
        .insert({
          'id': newId,
          'user_id': firebaseUser.uid,
          'group_id': groupId,
          'title': title,
          'description': description,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          // 'repeat_rule': repeatRule, // <-- REMOVED: This column does not exist in the 'events' table
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  Future<List<Map<String, dynamic>>> fetchEvents(String groupId) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return [];

    final rows = await _supabase
        .from('events')
        .select()
        .or('group_id.eq.$groupId,user_id.eq.${firebaseUser.uid}')
        .order('start_time', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
