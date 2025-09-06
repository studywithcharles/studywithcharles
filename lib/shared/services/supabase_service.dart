import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:math'; // Needed for random colors
import 'package:flutter/material.dart'; // Needed for Color class
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  final String _verifyFunctionUrl =
      'https://stgykupephpnlshzvfwn.supabase.co/functions/v1/verify-transaction';
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
    required String repeat, // <-- always required (store 'none' if no repeat)
  }) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final newId = uuid.v4();

    final insertData = {
      'id': newId,
      'user_id': firebaseUser.uid,
      'group_id': groupId,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'repeat': repeat, // <-- always save the repeat mode
    };

    final row = await supabase
        .from('events')
        .insert(insertData)
        .select()
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  // Helper: returns base event id if this looks like a synthetic recurring-instance id
  // e.g. "746033c4-..._r3" -> "746033c4-..."
  String _baseEventId(String eventId) {
    if (eventId.contains('_r')) {
      return eventId.split('_r').first;
    }
    return eventId;
  }

  /// Update an event (server-side). Throws if:
  ///  - caller tried to update a synthetic recurring occurrence id (contains "_r")
  ///  - no row was updated (not found or no permission)
  Future<void> updateEvent({
    required String eventId,
    String? groupId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    required String repeat,
  }) async {
    // Reject attempts to edit an expanded single occurrence (synthetic id).
    if (eventId.contains('_r')) {
      throw Exception(
        'This appears to be a single instance of a recurring event and cannot be edited individually. '
        'Open the original event to edit the series.',
      );
    }

    final baseId = _baseEventId(eventId);

    final updates = <String, dynamic>{
      'group_id': groupId,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'repeat': repeat,
    };

    // Perform update and request the resulting rows so we can detect "no rows updated".
    final res = await supabase
        .from('events')
        .update(updates)
        .eq('id', baseId)
        .select();

    // If the update didn't return rows, nothing was updated (row not found or no permission)
    // ignore: unnecessary_type_check, unnecessary_null_comparison
    if (res == null || (res is List && res.isEmpty)) {
      throw Exception(
        'Event not found or you do not have permission to update it.',
      );
    }
  }

  /// Delete an event. Throws if:
  ///  - caller tried to delete a synthetic recurring occurrence id (contains "_r")
  ///  - no row was deleted (not found or no permission)
  Future<void> deleteEvent(String eventId) async {
    // Reject attempts to delete an expanded single occurrence (synthetic id).
    if (eventId.contains('_r')) {
      throw Exception(
        'This appears to be a single instance of a recurring event and cannot be deleted individually. '
        'Delete the original event to remove the series.',
      );
    }

    final baseId = _baseEventId(eventId);

    // Ask PostgREST to return deleted rows so we can confirm deletion happened
    final res = await supabase
        .from('events')
        .delete()
        .eq('id', baseId)
        .select();

    // ignore: unnecessary_type_check, unnecessary_null_comparison
    if (res == null || (res is List && res.isEmpty)) {
      throw Exception(
        'Event not found or you do not have permission to delete it.',
      );
    }
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
  /// Subscribe to another user's timetable by username.
  /// Uses the RPC that accepts both the username and an explicit subscriber id
  /// to avoid relying on auth.uid() inside Postgres.
  Future<void> subscribeToTimetable(String username) async {
    final name = username.trim();
    if (name.isEmpty) {
      throw Exception('Username cannot be empty.');
    }

    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in.');

    // Call the RPC that accepts the subscriber id explicitly.
    await supabase.rpc(
      'subscribe_to_timetable_by_username_with_subscriber',
      params: {'p_username': name, 'p_subscriber_id': firebaseUser.uid},
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

    // 1. Fetch from 'timetable_shares' where WE are the 'shared_user_id'.
    // 2. Explicitly join the 'users' table using the 'owner_id' to get the profile of the person we subscribed to.
    final rows = await supabase
        .from('timetable_shares')
        .select(
          '*, owner:users!owner_id(id, display_name, username, avatar_url)',
        )
        .eq('shared_user_id', uid) // <-- FIX 1: Filtered correctly
        .order('created_at', ascending: false);

    // 3. The user data is now nested under 'owner'. This code flattens it
    //    so your UI code doesn't need to change.
    final list = (rows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final ownerProfile = map.remove('owner'); // <-- Use the 'owner' alias
      if (ownerProfile != null) {
        map.addAll(Map<String, dynamic>.from(ownerProfile));
      }
      return map;
    }).toList();

    return List<Map<String, dynamic>>.from(list);
  }

  Future<void> unsubscribeFromTimetable(String ownerId) async {
    // Mirror for compatibility — calls the real deletion method
    return unsubscribeFromTimetableByOwner(ownerId);
  }

  // In SupabaseService (add near other subscription methods)
  Future<void> unsubscribeFromTimetableByOwner(String ownerId) async {
    final fb_auth.User? firebaseUser =
        fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');

    // Delete the exact share row (owner_id = ownerId, shared_user_id = current user)
    await supabase.from('timetable_shares').delete().match({
      'owner_id': ownerId,
      'shared_user_id': firebaseUser.uid,
    });
  }

  /// Fetch addon stats for a username. Expects RPC `get_timetable_addon_stats(p_username text)`
  /// to return a single row like { total: int, plus: int }.
  Future<Map<String, int>> fetchTimetableAddonStats(String username) async {
    final name = username.trim();
    if (name.isEmpty) return {'total': 0, 'plus': 0};

    try {
      final res = await supabase.rpc(
        'get_timetable_addon_stats',
        params: {'p_username': name},
      );

      if (res == null) return {'total': 0, 'plus': 0};

      if (res is List && res.isNotEmpty) {
        final row = res.first;
        if (row is Map) {
          final total = row['total'] is int
              ? row['total'] as int
              : int.tryParse(row['total']?.toString() ?? '') ?? 0;
          final plus = row['plus'] is int
              ? row['plus'] as int
              : int.tryParse(row['plus']?.toString() ?? '') ?? 0;
          return {'total': total, 'plus': plus};
        }
      }
      return {'total': 0, 'plus': 0};
    } catch (e) {
      // RPC failed — fallback to client-side computation
      debugPrint('fetchTimetableAddonStats RPC failed, falling back: $e');
      try {
        // 1) Find owner id (case-insensitive)
        final ownerRow = await supabase
            .from('users')
            .select('id')
            .ilike('username', name) // use ilike for case-insensitive match
            .maybeSingle();

        if (ownerRow == null || ownerRow['id'] == null) {
          return {'total': 0, 'plus': 0};
        }
        final ownerId = ownerRow['id'] as String;

        // 2) Fetch shares and owner info of the shared users
        final rows = await supabase
            .from('timetable_shares')
            .select(
              'shared_user_id, shared_user:users!shared_user_id(is_premium)',
            )
            .eq('owner_id', ownerId);

        // ignore: unnecessary_null_comparison
        if (rows == null) return {'total': 0, 'plus': 0};

        int total = 0;
        int plus = 0;
        // ignore: unnecessary_type_check
        if (rows is List) {
          total = rows.length;
          for (final r in rows) {
            // ignore: unnecessary_type_check
            if (r is Map) {
              final su = r['shared_user'];
              if (su is Map && (su['is_premium'] == true)) plus++;
            }
          }
        }
        return {'total': total, 'plus': plus};
      } catch (e2) {
        debugPrint('Client-side addon stats fallback failed: $e2');
        return {'total': 0, 'plus': 0};
      }
    }
  }

  /// Fetch latest notifications for current Firebase user
  /// Fetch latest notifications for current Firebase user
  Future<List<Map<String, dynamic>>> fetchNotifications({
    int limit = 50,
  }) async {
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return <Map<String, dynamic>>[];

    final rows = await supabase
        .from('timetable_notifications')
        .select(
          'id, recipient_id, actor_id, actor_username, event_id, action, payload, created_at, read',
        )
        .eq('recipient_id', user.uid)
        .order('created_at', ascending: false)
        .limit(limit);

    // ignore: unnecessary_null_comparison
    if (rows == null) return <Map<String, dynamic>>[];

    // Flatten payload JSON so UI can access `title` and `start_time` easily
    final list = (rows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['payload'] != null && map['payload'] is Map) {
        final payload = Map<String, dynamic>.from(map['payload']);
        map['title'] = payload['title'];
        map['start_time'] = payload['start_time'];
      }
      return map;
    }).toList();

    return List<Map<String, dynamic>>.from(list);
  }

  /// Return how many unread notifications the current user has.
  Future<int> fetchUnreadCount() async {
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final rows = await supabase
        .from('timetable_notifications')
        .select('id')
        .eq('recipient_id', user.uid)
        .eq('read', false);
    return (rows as List).length;
  }

  /// Mark a single notification as read (by its numeric id)
  Future<void> markNotificationRead(int notificationId) async {
    await supabase
        .from('timetable_notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }

  /// Mark all notifications for the current user as read
  Future<void> markAllNotificationsRead() async {
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await supabase
        .from('timetable_notifications')
        .update({'read': true})
        .eq('recipient_id', user.uid)
        .eq('read', false);
  }

  /// Save an FCM device token onto the user's row (as an array in `fcm_tokens` JSONB field).
  /// This function will create or append to an array at users.fcm_tokens.
  Future<void> saveDeviceToken(String token) async {
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Read existing tokens (if your users table doesn't have `fcm_tokens`, this still works)
    final row = await supabase
        .from('users')
        .select('fcm_tokens')
        .eq('id', user.uid)
        .maybeSingle();

    List<dynamic> tokens = [];
    if (row != null && row['fcm_tokens'] != null) {
      final existing = row['fcm_tokens'];
      if (existing is List)
        tokens = existing;
      else if (existing is String) {
        try {
          tokens = jsonDecode(existing) as List<dynamic>;
        } catch (_) {
          tokens = [];
        }
      }
    }

    if (!tokens.contains(token)) {
      tokens.add(token);
      await supabase
          .from('users')
          .update({'fcm_tokens': tokens})
          .eq('id', user.uid);
    }
  }

  /// Remove an FCM device token from the user's row.
  Future<void> removeDeviceToken(String token) async {
    final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final row = await supabase
        .from('users')
        .select('fcm_tokens')
        .eq('id', user.uid)
        .maybeSingle();

    if (row == null || row['fcm_tokens'] == null) return;

    List<dynamic> tokens;
    final existing = row['fcm_tokens'];
    if (existing is List)
      tokens = List<dynamic>.from(existing);
    else {
      try {
        tokens = List<dynamic>.from(jsonDecode(existing));
      } catch (_) {
        tokens = [];
      }
    }

    tokens.removeWhere((t) => t == token);
    await supabase
        .from('users')
        .update({'fcm_tokens': tokens})
        .eq('id', user.uid);
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

  // full function to verify a paystack reference server-side
  Future<Map<String, dynamic>> verifyTransaction(String reference) async {
    final resp = await http.post(
      Uri.parse(_verifyFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reference': reference}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      // return the error body or throw if you prefer
      try {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Verify request failed: ${resp.statusCode}');
      }
    }
  }
}
