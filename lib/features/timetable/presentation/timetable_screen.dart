// lib/features/timetable/presentation/timetable_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _loading = true;
  String _myCode = '';
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _checkPremium();
    _loadMyCode();
    _loadEvents();
  }

  Future<void> _checkPremium() async {
    // TODO: replace with real premium check
    final user = AuthService.instance.currentUser;
    setState(() {
      _isPremium = user != null && user.email?.endsWith('@premium.com') == true;
    });
  }

  Future<void> _loadMyCode() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    if (!mounted) return;
    final profile = await SupabaseService.instance.fetchUserProfile(uid);
    if (!mounted) return;
    setState(() {
      _myCode = profile['timetable_code'] as String? ?? '';
    });
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // FIXED: The fetchEvents function no longer needs any arguments.
      // This resolves the error you are seeing.
      final all = await SupabaseService.instance.fetchEvents();
      final temp = <DateTime, List<Map<String, dynamic>>>{};
      for (var e in all) {
        final dt = DateTime.parse(e['start_time'] as String).toLocal();
        final key = DateTime(dt.year, dt.month, dt.day);
        temp.putIfAbsent(key, () => []).add(e);
      }
      if (mounted) {
        setState(() {
          _events = temp;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading events: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  void _onDaySelected(DateTime sel, DateTime foc) {
    setState(() {
      _selectedDay = sel;
      _focusedDay = foc;
    });
  }

  Future<void> _addEvent() async {
    if (_selectedDay == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a day to add an event.')),
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
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
                  color: const Color.fromRGBO(255, 255, 255, 0.1),
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
                                  .map(
                                    (group) => DropdownMenuItem(
                                      value: group['id'] as String,
                                      child: Text(
                                        group['group_name'] as String,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setModalState(() => selectedGroupId = v);
                              },
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
                                        context: context,
                                        initialTime: startTime,
                                      );
                                      if (picked != null) {
                                        setModalState(() => startTime = picked);
                                      }
                                    },
                                    child: Text(
                                      startTime.format(context),
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
                                        context: context,
                                        initialTime: endTime,
                                      );
                                      if (picked != null) {
                                        setModalState(() => endTime = picked);
                                      }
                                    },
                                    child: Text(
                                      endTime.format(context),
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () async {
                              if (formKey.currentState?.validate() ?? false) {
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

                                await SupabaseService.instance.createEvent(
                                  groupId: selectedGroupId,
                                  title: title!,
                                  description: description,
                                  startTime: startDT,
                                  endTime: endDT,
                                );

                                if (!mounted) return;
                                Navigator.pop(context);
                                _loadEvents();
                              }
                            },
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openHamburger() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: const Color.fromRGBO(255, 255, 255, 0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    'Your Code',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _myCode,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _myCode));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      }
                    },
                  ),
                ),
                const Divider(color: Colors.white24),
                if (_isPremium)
                  ListTile(
                    leading: const Icon(Icons.input, color: Colors.white70),
                    title: const Text(
                      'Enter Code',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {},
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.lock, color: Colors.white70),
                    title: const Text(
                      'Enter Code (Premium)',
                      style: TextStyle(color: Colors.white38),
                    ),
                    enabled: false,
                  ),
                ListTile(
                  leading: const Icon(Icons.group, color: Colors.white70),
                  title: const Text(
                    'Grouped Events',
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
                        .then((_) => _loadEvents());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.white70),
                  title: const Text(
                    'Added Timetables',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todaysEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Timetable Section',
          style: TextStyle(
            fontFamily: 'Roboto',
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
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white10,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (d) =>
                              isSameDay(_selectedDay, d),
                          eventLoader: _getEventsForDay,
                          onDaySelected: _onDaySelected,
                          calendarStyle: const CalendarStyle(
                            defaultTextStyle: TextStyle(color: Colors.white),
                            weekendTextStyle: TextStyle(color: Colors.white70),
                            outsideTextStyle: TextStyle(color: Colors.white38),
                            selectedDecoration: BoxDecoration(
                              color: Colors.cyanAccent,
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: TextStyle(color: Colors.black),
                            todayDecoration: BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: TextStyle(color: Colors.white),
                            markerDecoration: BoxDecoration(
                              color: Colors.pinkAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
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
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedDay != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Events for ${DateFormat.yMMMd().format(_selectedDay!)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
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
                          itemBuilder: (context, index) {
                            final event = todaysEvents[index];
                            final startTime = DateFormat.jm().format(
                              DateTime.parse(event['start_time']).toLocal(),
                            );
                            return Card(
                              color: const Color.fromRGBO(255, 255, 255, 0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(
                                  event['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  event['description'] ?? '',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: Text(
                                  startTime,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                  ),
                                ),
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
