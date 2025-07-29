import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';

// NEW: Helper function to convert a hex color string (like #ff8800) into a Color object.
Color hexToColor(String? code) {
  if (code == null || code.length != 7) {
    return Colors.grey; // Default color if something is wrong
  }
  return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
}

class ManageGroupsScreen extends StatefulWidget {
  const ManageGroupsScreen({super.key});

  @override
  State<ManageGroupsScreen> createState() => _ManageGroupsScreenState();
}

class _ManageGroupsScreenState extends State<ManageGroupsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _groups = [];
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _groups = await SupabaseService.instance.fetchEventGroups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching groups: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createGroup() async {
    final groupName = _textController.text.trim();
    if (groupName.isEmpty) return;

    try {
      await SupabaseService.instance.createEventGroup(groupName);
      _textController.clear();
      FocusScope.of(context).unfocus(); // Close the keyboard
      await _fetchGroups(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Manage Event Groups'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchGroups,
                    color: Colors.cyanAccent,
                    backgroundColor: Colors.black,
                    child: _groups.isEmpty
                        ? const Center(
                            child: Text(
                              'No groups created yet. Pull down to refresh.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _groups.length,
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              final isPublic = group['visibility'] == 'public';
                              // NEW: Get the color and event count from our new data
                              final color = hexToColor(group['color']);
                              final eventCount = group['event_count'];

                              return Card(
                                color: Colors.white10,
                                child: ListTile(
                                  // NEW: Leading widget to show color and count
                                  leading: CircleAvatar(
                                    backgroundColor: color,
                                    child: Text(
                                      eventCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    group['group_name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Toggle Public/Private',
                                        icon: Icon(
                                          isPublic ? Icons.public : Icons.lock,
                                          color: isPublic
                                              ? Colors.cyanAccent
                                              : Colors.white70,
                                        ),
                                        onPressed: () async {
                                          await SupabaseService.instance
                                              .toggleGroupVisibility(
                                                group['id'],
                                                group['visibility'],
                                              );
                                          await _fetchGroups();
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Group',
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () async {
                                          await SupabaseService.instance
                                              .deleteEventGroup(group['id']);
                                          await _fetchGroups();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                // Input field to add a new group
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'New Group Name',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.cyanAccent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
