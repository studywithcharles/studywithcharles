// lib/features/study/presentation/study_list_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';

class StudyListScreen extends StatefulWidget {
  static const routeName = '/study';
  const StudyListScreen({super.key});

  @override
  State<StudyListScreen> createState() => _StudyListScreenState();
}

class _StudyListScreenState extends State<StudyListScreen> {
  int _displaySection = 0;
  bool _rulesOpen = false;
  String? _currentContextId;

  bool _isLoading = true;

  final PageController _pageCtrl = PageController();
  final List<Map<String, String>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Context rules fields
  final TextEditingController _titleCtl = TextEditingController();
  String _selectedFormat = 'Summarize';
  final TextEditingController _moreCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final contexts = await SupabaseService.instance.fetchContexts();
      if (contexts.isNotEmpty) {
        _currentContextId = contexts.first['id'] as String;
        final cards = await SupabaseService.instance.fetchCards(
          _currentContextId!,
        );
        _messages.clear();
        for (var row in cards) {
          final content = row['content'] as Map<String, dynamic>;
          _messages.add({
            'role': content['role'] as String,
            'text': content['text'] as String,
          });
        }
      }
    } catch (e) {
      _showGlassSnackBar('Error loading data: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    _pageCtrl.dispose();
    _titleCtl.dispose();
    _moreCtl.dispose();
    super.dispose();
  }

  void _showGlassSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: isError
            ? const Color.fromRGBO(0, 0, 0, 0.8)
            : const Color.fromRGBO(0, 0, 0, 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ☰ Main hamburger menu
  void _openHamburgerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(0, 255, 255, 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.add_box, color: Colors.white70),
                    title: const Text(
                      'New Card',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      /* TODO */
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark, color: Colors.white70),
                    title: const Text(
                      'Saved Cards',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      /* TODO */
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.question_answer,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'FAQ',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      /* TODO */
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white70),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      /* TODO */
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ➕ Card-actions menu (attached to plus icon)
  void _openCardActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
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
                    leading: const Icon(
                      Icons.photo_library,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Add Photo/Video',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      /* TODO */
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.attach_file,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Attach File',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      /* TODO */
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Take Photo',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      /* TODO */
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.save, color: Colors.cyanAccent),
                    title: const Text(
                      'SAVE THIS CARD',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _saveCurrentCard();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentCard() async {
    if (_currentContextId == null || _messages.isEmpty) return;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final savedCount = await SupabaseService.instance.countSavedCardsSince(
      contextId: _currentContextId!,
      since: startOfMonth,
    );
    if (savedCount >= 3) {
      _showGlassSnackBar(
        'Free users can only save 3 cards per month.',
        isError: true,
      );
      return;
    }

    try {
      await SupabaseService.instance.saveCard(
        contextId: _currentContextId!,
        content: _messages.last,
      );
      _showGlassSnackBar('Card saved! 🎉');
    } catch (e) {
      _showGlassSnackBar('Error saving card: $e', isError: true);
    }
  }

  void _openContextRules() async {
    setState(() => _rulesOpen = true);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Context RULES',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(0, 255, 255, 1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleCtl,
                      decoration: const InputDecoration(
                        labelText: 'Course Title',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'e.g. Linear Algebra',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedFormat,
                      items: const [
                        DropdownMenuItem(
                          value: 'Summarize',
                          child: Text('Summarize'),
                        ),
                        DropdownMenuItem(
                          value: 'Generate Q&A',
                          child: Text('Generate Q&A'),
                        ),
                        DropdownMenuItem(
                          value: 'Code for me',
                          child: Text('Code for me'),
                        ),
                        DropdownMenuItem(
                          value: 'Solve my assignment',
                          child: Text('Solve my assignment'),
                        ),
                        DropdownMenuItem(
                          value: 'Explain topic/Question',
                          child: Text('Explain topic/Question'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedFormat = v!),
                      decoration: const InputDecoration(
                        labelText: 'Result Format',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      dropdownColor: const Color.fromRGBO(30, 30, 30, 1),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, color: Colors.white70),
                      label: const Text(
                        'Add Attachments',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _moreCtl,
                      decoration: const InputDecoration(
                        labelText: 'More Context',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Any extra rules or constraints',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final id = await SupabaseService.instance
                                  .createContext(
                                    title: _titleCtl.text,
                                    resultFormat: _selectedFormat,
                                    moreContext: _moreCtl.text.isEmpty
                                        ? null
                                        : _moreCtl.text,
                                  );
                              if (!mounted) return;
                              setState(() => _currentContextId = id);
                              _showGlassSnackBar('Context saved! 🎉');
                              Navigator.of(context).pop();
                            } catch (e) {
                              if (mounted) {
                                _showGlassSnackBar(
                                  'Error saving context: $e',
                                  isError: true,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    setState(() => _rulesOpen = false);
  }

  Future<void> _sendMessageHandler(String text) async {
    if (text.isEmpty || !mounted) return;
    if (_currentContextId == null) {
      _openContextRules();
      return;
    }

    setState(() => _messages.add({'role': 'user', 'text': text}));
    _msgCtrl.clear();
    await SupabaseService.instance.createCard(
      contextId: _currentContextId!,
      content: {'role': 'user', 'text': text},
      type: 'text',
    );
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(
      () => _messages.add({
        'role': 'assistant',
        'text': 'LLM response for: "$text"',
      }),
    );
    await SupabaseService.instance.createCard(
      contextId: _currentContextId!,
      content: {'role': 'assistant', 'text': 'LLM response for: "$text"'},
      type: 'text',
    );
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Study Section',
          style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Roboto'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            color: Colors.white,
            onPressed: _openHamburgerMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented control + gear icon
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegment('TEXT', 0),
                        _buildSegment('DIAGRAM', 1),
                        _buildSegment('CODE', 2),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          color: _rulesOpen ? Colors.cyanAccent : Colors.white,
                          onPressed: _openContextRules,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // PageView (with loading & empty states inside first tab)
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (idx) => setState(() => _displaySection = idx),
              children: [
                _buildCardContent(0),
                _buildCardContent(1),
                _buildCardContent(2),
              ],
            ),
          ),

          // Bottom input + plus menu
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: const Color.fromRGBO(255, 255, 255, 0.12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _openCardActionsMenu,
                          child: const Icon(
                            Icons.add,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Type your message…',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Color.fromRGBO(255, 255, 255, 0.5),
                              ),
                            ),
                            onSubmitted: _sendMessageHandler,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _sendMessageHandler(_msgCtrl.text),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(int section) {
    if (section == 0) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_messages.isEmpty) {
        return const Center(
          child: Text(
            'No messages yet.\nYour first message will trigger the context rules popup.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
        );
      }
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final m = _messages[i], isUser = m['role'] == 'user';
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: const Color.fromRGBO(255, 255, 255, 0.05),
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      m['text']!,
                      style: TextStyle(
                        color: isUser
                            ? const Color.fromRGBO(255, 255, 255, 1)
                            : const Color.fromRGBO(0, 255, 255, 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else if (section == 1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.image, size: 80, color: Colors.white54),
            SizedBox(height: 12),
            Text('Diagram Output', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color.fromRGBO(30, 30, 30, 1),
        child: const Text(
          '// Your generated code will appear here',
          style: TextStyle(
            fontFamily: 'SourceCodePro',
            color: Colors.greenAccent,
          ),
        ),
      );
    }
  }

  Widget _buildSegment(String label, int idx) {
    final isSelected = _displaySection == idx;
    return GestureDetector(
      onTap: () {
        _pageCtrl.animateToPage(
          idx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() => _displaySection = idx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromRGBO(0, 255, 255, 1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : const Color.fromRGBO(255, 255, 255, 0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
