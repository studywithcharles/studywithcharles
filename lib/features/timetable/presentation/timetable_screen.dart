// lib/features/timetable/presentation/timetable_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';
import 'manage_groups_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedUserId; // used when selecting an added user's events
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _loading = true;
  bool _isPremium = false;
  List<Map<String, dynamic>> _addedTimetables = []; // shared users
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _currentUserId = AuthService.instance.currentUser?.uid;
    _initAll();
  }

  Future<void> _initAll() async {
    await _checkPremium();
    await _loadMyCode();
    await _loadSharedUsers();
    await _loadEvents();
  }

  // ---------- DATA LOADING ----------

  Future<void> _checkPremium() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final profile = await SupabaseService.instance.fetchUserProfile(uid);
      if (!mounted) return;
      setState(() {
        _isPremium = profile['is_premium'] as bool? ?? false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPremium = false);
    }
  }

  Future<void> _loadMyCode() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _loadSharedUsers() async {
    try {
      final users = await SupabaseService.instance.getMySharedUsers();
      if (!mounted) return;
      setState(() {
        _addedTimetables = List<Map<String, dynamic>>.from(users);
      });
    } catch (e) {
      // non-fatal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load added timetables: $e')),
        );
      }
    }
  }

  /// Loads events and organizes them into a Map keyed by local date (midnight).
  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final allEvents = await SupabaseService.instance.fetchEvents();

      final Map<DateTime, List<Map<String, dynamic>>> temp = {};

      for (final event in allEvents) {
        // Accept String or DateTime for start_time
        final raw = event['start_time'];
        DateTime utcTime;
        if (raw is String) {
          utcTime = DateTime.parse(raw).toUtc();
        } else if (raw is DateTime) {
          utcTime = (raw).toUtc();
        } else {
          continue; // skip malformed record
        }

        final local = utcTime.toLocal();
        final key = DateTime(local.year, local.month, local.day);

        temp.putIfAbsent(key, () => []).add(Map<String, dynamic>.from(event));
      }

      if (!mounted) return;
      setState(() {
        _events = temp;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading events: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- HELPERS ----------

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );
      _focusedDay = focusedDay;
      _selectedUserId = null; // clear filter when user selects a new day
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  // ---------- ADD / EDIT / DELETE ----------

  Future<void> _addEvent() async {
    if (_selectedDay == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a date first to add an event.')),
      );
      return;
    }

    final groups = await SupabaseService.instance.fetchEventGroups();
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    String? title;
    String? description;
    String? selectedGroupId;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    String repeat = 'none'; // UI-only

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: const Color.fromRGBO(30, 30, 30, 0.95),
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'New Event',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter a title'
                                  : null,
                              onSaved: (v) => title = v,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              style: const TextStyle(color: Colors.white),
                              maxLines: 2,
                              onSaved: (v) => description = v,
                            ),
                            const SizedBox(height: 12),
                            if (groups.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: selectedGroupId,
                                hint: const Text(
                                  'Assign to a group (optional)',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                dropdownColor: const Color.fromRGBO(
                                  30,
                                  30,
                                  30,
                                  1,
                                ),
                                style: const TextStyle(color: Colors.white),
                                items: groups
                                    .map<DropdownMenuItem<String>>(
                                      (group) => DropdownMenuItem<String>(
                                        value: group['id'] as String,
                                        child: Text(
                                          group['group_name'] as String,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setModalState(() => selectedGroupId = v),
                                onSaved: (v) => selectedGroupId = v,
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Starts at:',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: ctx2,
                                          initialTime: startTime,
                                        );
                                        if (picked != null)
                                          setModalState(
                                            () => startTime = picked,
                                          );
                                      },
                                      child: Text(
                                        startTime.format(ctx2),
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      'Ends at:',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: ctx2,
                                          initialTime: endTime,
                                        );
                                        if (picked != null)
                                          setModalState(() => endTime = picked);
                                      },
                                      child: Text(
                                        endTime.format(ctx2),
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: repeat,
                              decoration: const InputDecoration(
                                labelText: 'Repeat',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              dropdownColor: const Color.fromRGBO(
                                30,
                                30,
                                30,
                                1,
                              ),
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('Does not repeat'),
                                ),
                                DropdownMenuItem(
                                  value: 'daily',
                                  child: Text('Every day'),
                                ),
                                DropdownMenuItem(
                                  value: 'weekly',
                                  child: Text('Every week'),
                                ),
                                DropdownMenuItem(
                                  value: 'monthly',
                                  child: Text('Every month'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setModalState(() => repeat = v ?? 'none'),
                              onSaved: (v) => repeat = v ?? 'none',
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () async {
                                if (!(formKey.currentState?.validate() ??
                                    false))
                                  return;
                                formKey.currentState?.save();

                                final startDT = DateTime(
                                  _selectedDay!.year,
                                  _selectedDay!.month,
                                  _selectedDay!.day,
                                  startTime.hour,
                                  startTime.minute,
                                );
                                final endDT = DateTime(
                                  _selectedDay!.year,
                                  _selectedDay!.month,
                                  _selectedDay!.day,
                                  endTime.hour,
                                  endTime.minute,
                                );

                                try {
                                  await SupabaseService.instance.createEvent(
                                    groupId: selectedGroupId,
                                    title: title!,
                                    description: description,
                                    startTime: startDT,
                                    endTime: endDT,
                                  );

                                  if (!mounted) return;
                                  Navigator.of(ctx2).pop();
                                  await _loadEvents();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Event saved'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving event: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Save Event',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editEvent(Map<String, dynamic> event) async {
    final groups = await SupabaseService.instance.fetchEventGroups();
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    String title = event['title'] ?? '';
    String? description = event['description'];
    String? selectedGroupId = event['group_id'];

    DateTime parsedStart = _parseToLocal(event['start_time']);
    DateTime parsedEnd = _parseToLocal(event['end_time']);
    TimeOfDay startTime = TimeOfDay.fromDateTime(parsedStart);
    TimeOfDay endTime = TimeOfDay.fromDateTime(parsedEnd);
    String repeat = event['repeat'] ?? 'none'; // UI-only

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: const Color.fromRGBO(30, 30, 30, 0.95),
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Edit Event',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: title,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter a title'
                                  : null,
                              onSaved: (v) => title = v ?? '',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: description,
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              style: const TextStyle(color: Colors.white),
                              maxLines: 2,
                              onSaved: (v) => description = v,
                            ),
                            const SizedBox(height: 12),
                            if (groups.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: selectedGroupId,
                                hint: const Text(
                                  'Assign to a group (optional)',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                dropdownColor: const Color.fromRGBO(
                                  30,
                                  30,
                                  30,
                                  1,
                                ),
                                style: const TextStyle(color: Colors.white),
                                items: groups
                                    .map(
                                      (group) => DropdownMenuItem(
                                        value: group['id'] as String,
                                        child: Text(
                                          group['group_name'] as String,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setModalState(() => selectedGroupId = v),
                                onSaved: (v) => selectedGroupId = v,
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Starts at:',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: ctx2,
                                          initialTime: startTime,
                                        );
                                        if (picked != null)
                                          setModalState(
                                            () => startTime = picked,
                                          );
                                      },
                                      child: Text(
                                        startTime.format(ctx2),
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      'Ends at:',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: ctx2,
                                          initialTime: endTime,
                                        );
                                        if (picked != null)
                                          setModalState(() => endTime = picked);
                                      },
                                      child: Text(
                                        endTime.format(ctx2),
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: repeat,
                              decoration: const InputDecoration(
                                labelText: 'Repeat',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              dropdownColor: const Color.fromRGBO(
                                30,
                                30,
                                30,
                                1,
                              ),
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('Does not repeat'),
                                ),
                                DropdownMenuItem(
                                  value: 'daily',
                                  child: Text('Every day'),
                                ),
                                DropdownMenuItem(
                                  value: 'weekly',
                                  child: Text('Every week'),
                                ),
                                DropdownMenuItem(
                                  value: 'monthly',
                                  child: Text('Every month'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setModalState(() => repeat = v ?? 'none'),
                              onSaved: (v) => repeat = v ?? 'none',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx2,
                                      builder: (dialogCtx) => AlertDialog(
                                        backgroundColor: const Color.fromRGBO(
                                          30,
                                          30,
                                          30,
                                          1,
                                        ),
                                        title: const Text(
                                          'Confirm Deletion',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: const Text(
                                          'Are you sure you want to delete this event?',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogCtx,
                                            ).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogCtx,
                                            ).pop(true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await SupabaseService.instance
                                            .deleteEvent(event['id']);
                                        if (!mounted) return;
                                        Navigator.of(ctx2).pop();
                                        await _loadEvents();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Event deleted'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Error deleting: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyanAccent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false))
                                        return;
                                      formKey.currentState?.save();

                                      final startDT = DateTime(
                                        _selectedDay!.year,
                                        _selectedDay!.month,
                                        _selectedDay!.day,
                                        startTime.hour,
                                        startTime.minute,
                                      );
                                      final endDT = DateTime(
                                        _selectedDay!.year,
                                        _selectedDay!.month,
                                        _selectedDay!.day,
                                        endTime.hour,
                                        endTime.minute,
                                      );

                                      try {
                                        // do not pass `repeat:` unless your API supports it
                                        await SupabaseService.instance
                                            .updateEvent(
                                              eventId: event['id'],
                                              title: title,
                                              description: description,
                                              groupId: selectedGroupId,
                                              startTime: startDT,
                                              endTime: endDT,
                                            );

                                        if (!mounted) return;
                                        Navigator.of(ctx2).pop();
                                        await _loadEvents();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Event updated'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Error updating: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text(
                                      'Save Changes',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _parseToLocal(dynamic raw) {
    if (raw is String) return DateTime.parse(raw).toLocal();
    if (raw is DateTime) return raw.toLocal();
    return DateTime.now();
  }

  // ---------- HAMBURGER / ADDED TIMETABLES ----------

  /// Shows the bottom sheet hamburger with code, enter-code, manage groups, added timetables
  Future<void> _openHamburger() async {
    final codeController = TextEditingController();

    // fetch local profile (username) to show
    String displayUsername = '';
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        final profile = await SupabaseService.instance.fetchUserProfile(uid);
        displayUsername =
            profile['username'] as String? ??
            profile['display_name'] as String? ??
            '';
      }
    } catch (_) {
      // ignore, we'll show empty username if fetch fails
    }

    // Placeholder numbers until backend provides addon stats
    int totalAddons = 0;
    int plusAddons = 0;

    // TODO: Replace this block with a backend call that returns:
    // { total: <int>, plus: <int> } for how many users have added THIS user's username.
    // Example:
    // final stats = await SupabaseService.instance.fetchTimetableAddonStats(displayUsername);
    // totalAddons = stats['total'] as int;
    // plusAddons = stats['plus'] as int;
    //
    // If you add that method to SupabaseService, remove the placeholder values above.
    //
    // --- End TODO ---

    final cashOut = (plusAddons ~/ 100) * 1000; // N1000 per 100 plus addons

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color.fromRGBO(30, 30, 30, 0.95),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: show username
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.white70),
                    title: Text(
                      displayUsername.isNotEmpty
                          ? '@$displayUsername'
                          : 'No username',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$totalAddons Addons',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),

                  // small row with plus-addons and estimated cash-out
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        // plus-addons mini chip
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amberAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$plusAddons plus',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // cash-out mini chip
                        Row(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.greenAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'N$cashOut',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white24),

                  // ENTER USERNAME -> subscribe to another user's timetable
                  ListTile(
                    leading: const Icon(Icons.input, color: Colors.white70),
                    title: Text(
                      _isPremium
                          ? 'Enter Username (add another timetable)'
                          : 'Enter Username (free users: 1 allowed)',
                      style: const TextStyle(color: Colors.white),
                    ),
                    enabled: _isPremium || _addedTimetables.length < 1,
                    onTap: () {
                      Navigator.of(context).pop(); // close hamburger
                      showDialog(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            backgroundColor: const Color.fromRGBO(
                              30,
                              30,
                              30,
                              1,
                            ),
                            title: const Text(
                              'Enter timetable username',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: TextField(
                              controller: codeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Username (e.g. alice123)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final usernameToAdd = codeController.text
                                      .trim();
                                  if (usernameToAdd.isEmpty) return;
                                  Navigator.pop(dialogContext);

                                  try {
                                    // NOTE: your existing backend method was subscribeToTimetable(code).
                                    // If you updated your backend to accept a username instead of code,
                                    // calling the same method with a username should work.
                                    // If you add a new API endpoint like subscribeToTimetableByUsername,
                                    // replace the call below with that new method.
                                    await SupabaseService.instance
                                        .subscribeToTimetable(usernameToAdd);

                                    // refresh local lists
                                    await _loadSharedUsers();
                                    await _loadEvents();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Subscribed to timetable',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Subscribe'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  // Manage groups
                  ListTile(
                    leading: const Icon(Icons.group, color: Colors.white70),
                    title: const Text(
                      'Manage Groups',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (context) => const ManageGroupsScreen(),
                            ),
                          )
                          .then((_) async {
                            await _loadEvents();
                          });
                    },
                  ),

                  // Added timetables
                  ListTile(
                    leading: const Icon(
                      Icons.person_add,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Added Timetables',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showAddedTimetables();
                    },
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddedTimetables() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            bool isLoading = false;
            List<Map<String, dynamic>> sharedUsers = List.from(
              _addedTimetables,
            );

            Future<void> refresh() async {
              setModal(() => isLoading = true);
              try {
                final u = await SupabaseService.instance.getMySharedUsers();
                setModal(() {
                  sharedUsers = List<Map<String, dynamic>>.from(u);
                  isLoading = false;
                });
              } catch (e) {
                setModal(() => isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }

            Future<void> removeShare(String sharedUserId) async {
              try {
                await SupabaseService.instance.unsubscribeFromTimetable(
                  sharedUserId,
                );
                await refresh();
                await _loadEvents();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error removing: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.25,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: const Color.fromRGBO(30, 30, 30, 0.95),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Added Timetables',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(color: Colors.white24),
                          Expanded(
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : sharedUsers.isEmpty
                                ? const Center(
                                    child: Text(
                                      'You have not added any other timetables.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: sharedUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = sharedUsers[index];
                                      final avatarUrl =
                                          user['avatar_url'] as String?;
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: avatarUrl != null
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: avatarUrl == null
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                        title: Text(
                                          user['display_name'] ?? 'No name',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '@${user['username'] ?? '...'}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.link_off,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () =>
                                              removeShare(user['id'] as String),
                                        ),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          setState(
                                            () => _selectedUserId =
                                                user['id'] as String,
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) async {
      await _loadSharedUsers();
      await _loadEvents();
    });
  }

  // ---------- DAY EVENTS SHEET ----------

  Future<void> _showDayEventsSheet(List<Map<String, dynamic>> events) async {
    if (_selectedDay == null) return;

    final filtered = _selectedUserId == null
        ? events
        : events.where((e) => e['user_id'] == _selectedUserId).toList();

    filtered.sort((a, b) {
      final aTime = _parseToLocal(a['start_time']);
      final bTime = _parseToLocal(b['start_time']);
      return aTime.compareTo(bTime);
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: const Color.fromRGBO(30, 30, 30, 0.95),
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.25,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Events for ${DateFormat.yMMMd().format(_selectedDay!)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No events for this day.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final ev = filtered[i];
                                final start = DateFormat.jm().format(
                                  _parseToLocal(ev['start_time']),
                                );
                                final owner =
                                    (ev['event_owner'] ??
                                            ev['owner'] ??
                                            ev['user'])
                                        as Map<String, dynamic>?;
                                final ownerUsername = owner != null
                                    ? owner['username']
                                    : ev['username'] ?? ev['creator_username'];
                                final isMine = ev['user_id'] == _currentUserId;

                                final groupName =
                                    ev['timetable_groups']?['group_name'] ??
                                    ev['group_name'];
                                final colorHex =
                                    ev['timetable_groups']?['group_color'] ??
                                    ev['group_color'];
                                Color? groupColor;
                                if (colorHex != null) {
                                  try {
                                    groupColor = Color(
                                      int.parse(
                                        colorHex.replaceFirst('#', '0xff'),
                                      ),
                                    );
                                  } catch (_) {
                                    groupColor = null;
                                  }
                                }

                                return Card(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.06,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    title: Text(
                                      ev['title'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (ev['description'] != null &&
                                            (ev['description'] as String)
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              ev['description'],
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        if (groupName != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              'Group: $groupName',
                                              style: TextStyle(
                                                color:
                                                    groupColor ??
                                                    Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        if (!isMine && ownerUsername != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              'by @$ownerUsername',
                                              style: const TextStyle(
                                                color: Colors.amberAccent,
                                                fontStyle: FontStyle.italic,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Text(
                                      start,
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                      ),
                                    ),
                                    onTap: isMine ? () => _editEvent(ev) : null,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final dayEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <Map<String, dynamic>>[];
    final todaysEvents = _selectedUserId == null
        ? dayEvents
        : dayEvents.where((e) => e['user_id'] == _selectedUserId).toList();

    todaysEvents.sort((a, b) {
      final aTime = _parseToLocal(a['start_time']);
      final bTime = _parseToLocal(b['start_time']);
      return aTime.compareTo(bTime);
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Timetable',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: _openHamburger,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white10,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2035, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (d) =>
                              isSameDay(_selectedDay, d),
                          eventLoader: _getEventsForDay,
                          onDaySelected: (sel, foc) => _onDaySelected(sel, foc),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (events.isEmpty) return null;
                              // show small rounded square filled pink if events exist (matches your screenshot)
                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.pinkAccent,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.pinkAccent.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${day.day}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          calendarStyle: const CalendarStyle(
                            defaultTextStyle: TextStyle(color: Colors.white),
                            weekendTextStyle: TextStyle(color: Colors.white70),
                            outsideTextStyle: TextStyle(color: Colors.white38),
                            selectedDecoration: BoxDecoration(
                              color: Colors.cyanAccent,
                              borderRadius: BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                            selectedTextStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                            todayTextStyle: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Tappable header to open full list for the day
                if (_selectedDay != null)
                  GestureDetector(
                    onTap: () => _showDayEventsSheet(todaysEvents),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Events for: ${DateFormat.yMMMd().format(_selectedDay!)}${_selectedUserId != null ? ' (filtered)' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Inline list or fallback
                Expanded(
                  child: todaysEvents.isEmpty
                      ? const Center(
                          child: Text(
                            'No events scheduled for this day.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: todaysEvents.length,
                          itemBuilder: (ctx, i) {
                            final ev = todaysEvents[i];
                            final start = DateFormat.jm().format(
                              _parseToLocal(ev['start_time']),
                            );
                            final owner =
                                (ev['event_owner'] ?? ev['owner'] ?? ev['user'])
                                    as Map<String, dynamic>?;
                            final ownerUsername = owner != null
                                ? owner['username']
                                : ev['username'] ?? ev['creator_username'];
                            final isMine = ev['user_id'] == _currentUserId;
                            final groupName =
                                ev['timetable_groups']?['group_name'] ??
                                ev['group_name'];

                            return Card(
                              color: const Color.fromRGBO(255, 255, 255, 0.06),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  ev['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (ev['description'] != null &&
                                        (ev['description'] as String)
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          ev['description'],
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    if (groupName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'Group: $groupName',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (!isMine && ownerUsername != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'by @$ownerUsername',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  start,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                  ),
                                ),
                                onTap: isMine ? () => _editEvent(ev) : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _selectedDay != null
          ? FloatingActionButton(
              onPressed: _addEvent,
              backgroundColor: Colors.cyanAccent,
              tooltip: 'Add Event',
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }
}
