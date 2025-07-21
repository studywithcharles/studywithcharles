// lib/features/study/presentation/study_list_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class StudyListScreen extends StatefulWidget {
  static const routeName = '/study';
  const StudyListScreen({Key? key}) : super(key: key);

  @override
  State<StudyListScreen> createState() => _StudyListScreenState();
}

class _StudyListScreenState extends State<StudyListScreen> {
  // 0 = Text, 1 = Diagram, 2 = Code
  int _displaySection = 0;
  final PageController _pageCtrl = PageController();
  final List<Map<String, String>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _openContextRules() {
    showModalBottomSheet<bool>(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Context RULES',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(0, 255, 255, 1),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Set your course title, result format, attachments & more context here.',
                    style: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.7)),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add({'role': 'user', 'text': text}));
    _msgCtrl.clear();

    Future.delayed(const Duration(milliseconds: 500), () {
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
            final m = _messages[i];
            final isUser = m['role'] == 'user';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Study',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Centered segmented control + context icon
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSegment('TEXT', 0),
                      _buildSegment('DIAGRAM', 1),
                      _buildSegment('CODE', 2),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.settings),
                  color: Colors.cyanAccent,
                  tooltip: 'Context RULES',
                  onPressed: _openContextRules,
                ),
              ],
            ),
          ),

          // Swipeable content
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

          // Text bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {},
                    child: const Icon(Icons.add, color: Colors.cyanAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          color: const Color.fromRGBO(255, 255, 255, 0.05),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: const InputDecoration(
                              hintText: 'test my power',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Color.fromRGBO(255, 255, 255, 0.5),
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            style: const TextStyle(
                              color: Color.fromRGBO(255, 255, 255, 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _sendMessage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          color: const Color.fromRGBO(255, 255, 255, 0.05),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
