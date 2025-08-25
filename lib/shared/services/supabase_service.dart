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

  /// Updates the social media handles for the current user.
  Future<void> updateUserSocials({
    String? tiktok,
    String? instagram,
    String? x,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    // First, fetch the existing social handles
    final existingData = await supabase
        .from('users')
        .select('social_handles')
        .eq('id', user.id)
        .single();

    final handles =
        (existingData['social_handles'] as Map<String, dynamic>?) ?? {};

    // Update the values if they were provided
    if (tiktok != null) handles['tiktok'] = tiktok;
    if (instagram != null) handles['instagram'] = instagram;
    if (x != null) handles['x'] = x;

    // Write the updated map back to the database
    await supabase
        .from('users')
        .update({'social_handles': handles})
        .eq('id', user.id);
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

  /// Fetch timetable events for the currently-signed-in Firebase user.
  /// Uses the DB RPC that accepts a p_user_id text parameter so we don't
  /// depend on auth.uid() inside Postgres (which caused the `uuid`/`text`
  /// errors you saw).
  Future<List<Map<String, dynamic>>> fetchEvents() async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      // Not signed in — return empty list (caller already handles UI while loading).
      return <Map<String, dynamic>>[];
    }

    final uid = firebaseUser.uid;
    try {
      // Call the version of the RPC that accepts p_user_id text
      final rows = await supabase.rpc(
        'get_timetable_events_for_user',
        params: {'p_user_id': uid},
      );

      if (rows == null) return <Map<String, dynamic>>[];
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      // Re-throw or wrap as needed. Returning empty list isn't ideal here because
      // the UI expects errors, so rethrow as PostgrestException style.
      rethrow;
    }
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
  /// Subscribe to another user's timetable by their username.
  /// Calls the DB RPC `subscribe_to_timetable_by_username(p_username text)`.
  Future<void> subscribeToTimetable(String username) async {
    final name = username.trim();
    if (name.isEmpty) {
      throw Exception('Username cannot be empty.');
    }

    // Call the RPC we created in the DB that looks up the target user by username
    // and inserts a row into timetable_shares.
    await supabase.rpc(
      'subscribe_to_timetable_by_username',
      params: {'p_username': name},
    );
  }

  /// Returns the list of users that the current user has added (subscribed to).
  /// Implemented client-side so we pass the Firebase uid directly instead of
  /// relying on auth.uid() in Postgres.
  Future<List<Map<String, dynamic>>> getMySharedUsers() async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return <Map<String, dynamic>>[];

    final uid = firebaseUser.uid;

    // We'll select from timetable_shares and join the users table to return
    // the chopped-down user info the UI needs.
    final rows = await supabase
        .from('timetable_shares')
        .select(
          'shared_user_id, created_at, shared_user:users(id, display_name, username, avatar_url)',
        )
        .eq('owner_id', uid)
        .order('created_at', ascending: false);

    // ignore: unnecessary_null_comparison
    if (rows == null) return <Map<String, dynamic>>[];

    // Convert to consistent List<Map<String,dynamic>> format expected by UI
    final list = (rows as List).map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      // the joined user columns will be under 'shared_user'
      final joined = map['shared_user'] as Map<String, dynamic>? ?? {};
      return {
        'id': joined['id'] ?? map['shared_user_id'],
        'display_name': joined['display_name'],
        'username': joined['username'],
        'avatar_url': joined['avatar_url'],
        'created_at': map['created_at'],
      };
    }).toList();

    return List<Map<String, dynamic>>.from(list);
  }

  Future<void> unsubscribeFromTimetable(String sharedUserId) async {
    final id = sharedUserId.trim();
    if (id.isEmpty) return;
    await supabase.rpc(
      'unsubscribe_from_timetable',
      params: {'p_shared_user_id': id},
    );
  }

  /// Fetch addon stats for a username. Expects RPC `get_timetable_addon_stats(p_username text)`
  /// to return a single row like { total: int, plus: int }.
  Future<Map<String, int>> fetchTimetableAddonStats(String username) async {
    final name = username.trim();
    if (name.isEmpty) return {'total': 0, 'plus': 0};

    final res = await supabase.rpc(
      'get_timetable_addon_stats',
      params: {'p_username': name},
    );
    if (res == null) return {'total': 0, 'plus': 0};

    final map = Map<String, dynamic>.from((res as List).first as Map);
    return {
      'total': (map['total'] as int?) ?? 0,
      'plus': (map['plus'] as int?) ?? 0,
    };
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
