// lib/features/study/presentation/study_list_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class StudyListScreen extends StatefulWidget {
  static const routeName = '/study';
  const StudyListScreen({super.key});

  @override
  State<StudyListScreen> createState() => _StudyListScreenState();
}

class _StudyListScreenState extends State<StudyListScreen> {
  int _displaySection = 0;
  bool _rulesOpen = false;
  final PageController _pageCtrl = PageController();
  final List<Map<String, String>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Context rules fields
  final TextEditingController _titleCtl = TextEditingController();
  String _selectedFormat = 'Summarize';
  final TextEditingController _moreCtl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    _pageCtrl.dispose();
    _titleCtl.dispose();
    _moreCtl.dispose();
    super.dispose();
  }

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
                          onPressed: () => Navigator.of(context).pop(),
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

  void _sendMessageHandler(String text) {
    if (text.isEmpty || !mounted) return;
    setState(() => _messages.add({'role': 'user', 'text': text}));
    _msgCtrl.clear();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(
        () => _messages.add({
          'role': 'assistant',
          'text': 'LLM response for: "$text"',
        }),
      );
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildCardContent(int section) {
    switch (section) {
      case 0:
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: _messages.length,
          itemBuilder: (_, i) {
            final m = _messages[i], isUser = m['role'] == 'user';
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
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
      case 1:
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
      case 2:
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
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
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
          // ── (CENTERED) Segmented control + gear ─────────────────
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

          // ── PageView ────────────────────────────────────────────
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

          // ── Bottom text bar (unchanged) ─────────────────────────
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
                          onTap: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.1,
                                  ),
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
                                        leading: const Icon(
                                          Icons.save,
                                          color: Colors.cyanAccent,
                                        ),
                                        title: const Text(
                                          'SAVE THIS CARD',
                                          style: TextStyle(
                                            color: Colors.cyanAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
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
                              hintText: 'test my power',
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
