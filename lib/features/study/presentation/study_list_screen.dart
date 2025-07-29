// import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:flutter/services.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudyListScreen extends StatefulWidget {
  static const routeName = '/study';
  const StudyListScreen({super.key});

  @override
  State<StudyListScreen> createState() => _StudyListScreenState();
}

class _StudyListScreenState extends State<StudyListScreen>
    with WidgetsBindingObserver {
  int _displaySection = 0;
  bool _rulesOpen = false;
  String? _currentContextId;

  bool _isLoading = true;
  List<Map<String, dynamic>> _savedContexts = [];

  final PageController _pageCtrl = PageController();
  final List<Map<String, String>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final TextEditingController _titleCtl = TextEditingController();
  String _selectedFormat = 'Summarize';
  final TextEditingController _moreCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.dispose();
    _scroll.dispose();
    _pageCtrl.dispose();
    _titleCtl.dispose();
    _moreCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() {
        _currentContextId = null;
        _messages.clear();
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final contexts = await SupabaseService.instance.fetchContexts();
      _savedContexts = contexts;
      _currentContextId = null;
      _messages.clear();
    } catch (e) {
      _showGlassSnackBar('Error loading data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGlassSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'New Card',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      setState(() {
                        _currentContextId = null;
                        _messages.clear();
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark, color: Colors.white70),
                    title: const Text(
                      'Saved Cards',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openSavedCardsList();
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
                    onTap: () => _showGlassSnackBar('FAQ not implemented yet'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white70),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      await AuthService.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
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

  void _openSavedCardsList() {
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
              child: _savedContexts.isEmpty
                  ? const Center(
                      child: Text(
                        'No saved cards.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _savedContexts.length,
                      itemBuilder: (_, idx) {
                        final ctx = _savedContexts[idx];
                        final id = ctx['id'] as String;
                        final title = ctx['title'] as String;
                        return ListTile(
                          title: Text(
                            title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            setState(() => _isLoading = true);
                            _currentContextId = id;
                            _messages.clear();
                            final cards = await SupabaseService.instance
                                .fetchCards(id);
                            _messages.addAll(
                              cards.map((row) {
                                final content =
                                    row['content'] as Map<String, dynamic>;
                                // ✨ NEW: Handle both text and image types from saved history
                                return {
                                  'role': content['role'] as String,
                                  'text': content['text'] as String,
                                  'type': content['type'] ?? 'text',
                                };
                              }),
                            );
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete saved card?'),
                                  content: Text(
                                    'Are you sure you want to delete "$title"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await SupabaseService.instance.deleteContext(
                                  id,
                                );
                                _showGlassSnackBar('Deleted "$title"');
                                if (mounted) Navigator.of(context).pop();
                                await _loadInitialData();
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

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
                    onTap: () async {
                      Navigator.pop(context);
                      final file = await _pickImage(ImageSource.gallery);
                      if (file != null) {
                        _showGlassSnackBar('Uploading…');
                        final url = await SupabaseService.instance
                            .uploadAttachment(file);
                        _showGlassSnackBar('Uploaded');
                        setState(
                          () => _messages.add({
                            'role': 'user',
                            'text': url,
                            'type': 'image',
                          }),
                        );
                      }
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
                    onTap: () async {
                      Navigator.pop(context);
                      final file = await _pickImage(ImageSource.camera);
                      if (file != null) {
                        _showGlassSnackBar('Uploading…');
                        final url = await SupabaseService.instance
                            .uploadAttachment(file);
                        _showGlassSnackBar('Uploaded');
                        setState(
                          () => _messages.add({
                            'role': 'user',
                            'text': url,
                            'type': 'image',
                          }),
                        );
                      }
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
                      Navigator.pop(context);
                      _showGlassSnackBar('File picker not implemented');
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

  Future<File?> _pickImage(ImageSource src) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: src,
      imageQuality: 80,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<void> _saveCurrentCard() async {
    if (_messages.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      if (_currentContextId == null) {
        final newContextId = await SupabaseService.instance.createContext(
          title: _titleCtl.text.trim().isEmpty
              ? 'Untitled Card'
              : _titleCtl.text.trim(),
          resultFormat: _selectedFormat,
          moreContext: _moreCtl.text.isEmpty ? null : _moreCtl.text.trim(),
        );
        _currentContextId = newContextId;
      }
      await SupabaseService.instance.saveCard(
        contextId: _currentContextId!,
        content: {'messages': _messages},
      );
      _showGlassSnackBar('Card saved! 🎉');
      await _loadInitialData();
    } catch (e) {
      _showGlassSnackBar('Error saving card: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      onPressed: () => _showGlassSnackBar(
                        'Attach files from here not yet supported',
                      ),
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
                          onPressed: _titleCtl.text.trim().isEmpty
                              ? null
                              : () async {
                                  try {
                                    final id = await SupabaseService.instance
                                        .createContext(
                                          title: _titleCtl.text.trim(),
                                          resultFormat: _selectedFormat,
                                          moreContext: _moreCtl.text.isEmpty
                                              ? null
                                              : _moreCtl.text,
                                        );
                                    if (!mounted) return;
                                    setState(() => _currentContextId = id);
                                    _showGlassSnackBar('Context created!');
                                    Navigator.of(context).pop();
                                  } catch (e) {
                                    if (mounted)
                                      _showGlassSnackBar(
                                        'Error: $e',
                                        isError: true,
                                      );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                          ),
                          child: const Text(
                            'Continue',
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
    if (mounted) setState(() => _rulesOpen = false);
  }

  Future<void> _sendMessageHandler(String text) async {
    if (text.isEmpty || !mounted) return;
    if (_currentContextId == null) {
      _openContextRules();
      return;
    }

    final messageType = _displaySection == 1 ? 'image_prompt' : 'text';
    setState(
      () => _messages.add({'role': 'user', 'text': text, 'type': messageType}),
    );
    _msgCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
    });

    try {
      String aiResponseText;
      String aiResponseType;

      // ✅ CHANGED: Logic to call the correct backend function
      if (_displaySection == 1) {
        // Diagram Section
        setState(() => _isLoading = true);
        aiResponseText = await _generateImage(prompt: text);
        aiResponseType = 'image';
      } else {
        // Text or Code Section
        aiResponseText = await _queryText(history: _messages);
        aiResponseType = 'text';
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add({
          'role': 'assistant',
          'text': aiResponseText,
          'type': aiResponseType,
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients)
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showGlassSnackBar('AI error: $e', isError: true);
      }
    }
  }

  // ✅ CHANGED: Renamed from _queryGeminiProxy to be more specific
  Future<String> _queryText({
    required List<Map<String, String>> history,
  }) async {
    final body = {'history': history};
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-proxy',
        body: body,
      );
      if (response.status != 200)
        throw Exception(
          'Backend function error ${response.status}: ${response.data}',
        );
      return response.data['reply'] as String;
    } catch (e) {
      throw Exception('Failed to call text proxy: $e');
    }
  }

  // ✨ NEW: Dedicated function to call the image generation proxy
  Future<String> _generateImage({required String prompt}) async {
    final body = {'prompt': prompt};
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'imagen-proxy',
        body: body,
      );
      if (response.status != 200)
        throw Exception(
          'Backend function error ${response.status}: ${response.data}',
        );
      return response.data['url'] as String;
    } catch (e) {
      throw Exception('Failed to call image proxy: $e');
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
          Expanded(
            child: Stack(
              children: [
                PageView(
                  controller: _pageCtrl,
                  onPageChanged: (idx) => setState(() => _displaySection = idx),
                  children: [
                    _buildCardContent(0),
                    _buildCardContent(1),
                    _buildCardContent(2),
                  ],
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
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
                              hintText: 'Test my power...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Color.fromRGBO(255, 255, 255, 0.5),
                              ),
                            ),
                            onSubmitted: _sendMessageHandler,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: () => _sendMessageHandler(_msgCtrl.text),
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

  Widget _buildSegment(String label, int index) {
    final isActive = _displaySection == index;
    return GestureDetector(
      onTap: () => _pageCtrl.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.cyanAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ✅ CHANGED: This widget can now display both text and images
  Widget _buildCardContent(int pageIndex) {
    if (_messages.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          'No messages yet.\nStart a new conversation!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (_, index) {
        final message = _messages[index];
        final isUser = message['role'] == 'user';
        final messageType = message['type'] ?? 'text';

        Widget contentWidget;
        if (messageType == 'image') {
          contentWidget = Image.network(
            message['text']!,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error_outline, color: Colors.redAccent),
          );
        } else {
          contentWidget = SelectableText(
            message['text']!,
            style: TextStyle(color: isUser ? Colors.black : Colors.white),
          );
        }

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.cyanAccent
                  : const Color.fromRGBO(255, 255, 255, 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: contentWidget,
          ),
        );
      },
    );
  }
}
