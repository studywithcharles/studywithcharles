import 'dart:io';
import 'package:uuid/uuid.dart';
import 'dart:math'; // Needed for random colors
import 'package:flutter/material.dart'; // Needed for Color class
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  final SupabaseClient supabase = Supabase.instance.client;
  final Uuid uuid = const Uuid();

  // ===========================================================================
  // == USER PROFILE
  // ===========================================================================
  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    final row = await supabase.from('users').select().eq('id', userId).single();
    return Map<String, dynamic>.from(row as Map);
  }

  /// Call this after you've confirmed payment succeeded.
  Future<void> markUserAsPremium() async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    await supabase
        .from('users')
        .update({'is_premium': true})
        .eq('id', firebaseUser.uid);
  }

  /// Update any of the user’s profile fields.
  Future<void> updateUserProfile({
    String? name,
    String? username,
    String? bio,
    String? photoUrl,
    String? usdtWallet,
  }) async {
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final updates = <String, dynamic>{};
    if (name != null) updates['display_name'] = name;
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (photoUrl != null) updates['avatar_url'] = photoUrl;
    if (usdtWallet != null) updates['wallet_address'] = usdtWallet;

    if (updates.isEmpty) return;

    await supabase.from('users').update(updates).eq('id', user.uid);
  }

  // ===========================================================================
  // == CONTEXTS (For Study Section)
  // ===========================================================================
  Future<String> createContext({
    required String title,
    required String resultFormat,
    String? moreContext,
    List<String>? attachmentUrls,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final newId = uuid.v4();
    final inserted = await supabase
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
    if (attachmentUrls != null) {
      for (final url in attachmentUrls) {
        await addContextAttachment(contextId: newId, url: url);
      }
    }
    return inserted['id'] as String;
  }

  Future<List<Map<String, dynamic>>> fetchContexts() async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return [];
    final rows = await supabase
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
    final row = await supabase
        .from('contexts')
        .update(updates)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (row == null) throw Exception('Context not found');
    return Map<String, dynamic>.from(row as Map);
  }

  Future<void> deleteContext(String id) async {
    await supabase.from('contexts').delete().eq('id', id);
  }

  // ===========================================================================
  // == CONTEXT ATTACHMENTS
  // ===========================================================================
  Future<void> addContextAttachment({
    required String contextId,
    required String url,
  }) async {
    await supabase.from('context_attachments').insert({
      'id': uuid.v4(),
      'context_id': contextId,
      'attachment_url': url,
    });
  }

  /// Fetches all attachment records for a given context ID.
  Future<List<Map<String, dynamic>>> fetchContextAttachments(
    String contextId,
  ) async {
    final attachments = await supabase
        .from('context_attachments')
        .select('attachment_url')
        .eq('context_id', contextId);
    return List<Map<String, dynamic>>.from(attachments as List);
  }

  // ===========================================================================
  // == CARDS (For Study Section)
  // ===========================================================================
  Future<Map<String, dynamic>> createCard({
    required String contextId,
    required Map<String, dynamic> content,
    required String type,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final newId = uuid.v4();
    final row = await supabase
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

  /// Pulls back the FULL message history for one context.
  Future<List<Map<String, dynamic>>> fetchCards(String contextId) async {
    // Grab the one row that we previously upserted for this context
    final row = await supabase
        .from('cards')
        .select('content')
        .eq('context_id', contextId)
        .eq('saved', true)
        .single(); // <-- use single() instead of limit(1).maybeSingle()

    // Extract the "messages" list out of the JSON column
    final content = row['content'] as Map<String, dynamic>;
    final rawMessages = content['messages'] as List<dynamic>? ?? [];

    // Force it into a List<Map<String,dynamic>> so our UI code can just consume it
    return rawMessages.cast<Map<String, dynamic>>();
  }

  Future<int> countSavedCardsSince({
    required String contextId,
    required DateTime since,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final rows = await supabase
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
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    // Build a full row, including a unique ID
    final cardData = {
      'id': uuid.v4(), // ← Always generate a new ID
      'context_id': contextId,
      'user_id': user.uid,
      'content': content,
      'type': 'text',
      'saved': true,
      'saved_at': DateTime.now().toIso8601String(),
    };

    // Upsert: insert if new, or update existing by context_id
    await supabase.from('cards').upsert(cardData, onConflict: 'context_id');
  }

  Future<void> deleteCard(String cardId) async {
    await supabase.from('cards').delete().eq('id', cardId);
  }

  // ===========================================================================
  // == GENERAL ATTACHMENTS
  // ===========================================================================
  Future<String> uploadAttachment(File file) async {
    final ext = file.path.split('.').last;
    final path = 'attachments/${uuid.v4()}.$ext';

    // Upload into our new bucket:
    await supabase.storage.from('study-attachments').upload(path, file);

    // Return a public URL so the app can display it:
    final publicUrl = supabase.storage
        .from('study-attachments')
        .getPublicUrl(path);

    return publicUrl;
  }

  // ===========================================================================
  // == TIMETABLE (EVENTS)
  // ===========================================================================
  Future<Map<String, dynamic>> createEvent({
    String? groupId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final newId = uuid.v4();
    final row = await supabase
        .from('events')
        .insert({
          'id': newId,
          'user_id': firebaseUser.uid,
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

  Future<void> updateEvent({
    required String eventId,
    String? groupId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await supabase
        .from('events')
        .update({
          'group_id': groupId,
          'title': title,
          'description': description,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
        })
        .eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    await supabase.from('events').delete().eq('id', eventId);
  }

  // THIS IS THE CORRECTED METHOD TO FIX EVENTS NOT SHOWING
  Future<List<Map<String, dynamic>>> fetchEvents() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // This calls the simpler, more reliable function from your schema
    final rows = await supabase.rpc(
      'get_events_with_groups',
      params: {'p_user_id': user.uid},
    );

    return List<Map<String, dynamic>>.from(rows as List);
  }

  // ===========================================================================
  // == TIMETABLE (GROUPS)
  // ===========================================================================
  Future<List<Map<String, dynamic>>> fetchEventGroups() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final response = await supabase.rpc(
      'get_groups_with_event_counts',
      params: {'p_user_id': user.uid},
    );
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> createEventGroup(String groupName) async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be logged in.');
    final random = Random();
    final color = Color.fromARGB(
      255,
      random.nextInt(156) + 100,
      random.nextInt(156) + 100,
      random.nextInt(156) + 100,
    );
    await supabase.from('event_groups').insert({
      'id': uuid.v4(),
      'user_id': user.uid,
      'group_name': groupName,
      'visibility': 'public',
      'color': '#${color.value.toRadixString(16).substring(2)}',
    });
  }

  Future<void> toggleGroupVisibility(
    String groupId,
    String currentVisibility,
  ) async {
    final newVisibility = currentVisibility == 'public' ? 'private' : 'public';
    await supabase
        .from('event_groups')
        .update({'visibility': newVisibility})
        .eq('id', groupId);
  }

  Future<void> deleteEventGroup(String groupId) async {
    await supabase.from('event_groups').delete().eq('id', groupId);
  }

  // ===========================================================================
  // == TIMETABLE (SUBSCRIPTIONS)
  // ===========================================================================
  Future<void> subscribeToTimetable(String timetableCode) async {
    if (timetableCode.isEmpty) {
      throw Exception('Timetable code cannot be empty.');
    }
    await supabase.rpc(
      'subscribe_to_timetable',
      params: {'p_timetable_code': timetableCode},
    );
  }

  // ===========================================================================
  // == TCA (LOVE SECTION)
  // ===========================================================================
  Future<Map<String, dynamic>?> fetchActiveTcaCycle() async {
    final response = await supabase
        .from('swc_cycles')
        .select('id, status')
        .eq('status', 'voting')
        .maybeSingle();
    return response;
  }

  Future<List<Map<String, dynamic>>> fetchTcaNominees(String cycleId) async {
    final response = await supabase
        .from('tca_nominees')
        .select('username')
        .eq('cycle_id', cycleId);
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<List<Map<String, dynamic>>> fetchPastTcaWinners() async {
    final response = await supabase
        .from('tca_awards')
        .select('winner_username, prize_amount, cycle_id')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> castTcaVote(String cycleId, String nomineeUsername) async {
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be logged in to vote.');

    await supabase.from('tca_votes').insert({
      'id': uuid.v4(),
      'cycle_id': cycleId,
      'user_id': user.uid,
      'nominee_username': nomineeUsername,
    });
  }

  // ===========================================================================
  // == PAYMENTS
  // ===========================================================================
  /// Creates a Paystack payment initialization and returns the authorization URL.
  Future<String> initializePaystackTransaction(
    int amount,
    String email,
    String reference,
  ) async {
    final response = await supabase.functions.invoke(
      'initialize-payment',
      body: {'amount': amount, 'email': email, 'reference': reference},
    );

    if (response.status != 200 || response.data == null) {
      throw Exception('Failed to initialize payment: ${response.data}');
    }

    final authUrl = response.data['data']['authorization_url'];
    if (authUrl == null) {
      throw Exception('Authorization URL not found in response.');
    }
    return authUrl as String;
  }
}
