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
  final List<String> _attachmentUrls = [];

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
      if (!mounted) return;

      // Clear all session state
      setState(() {
        _savedContexts = contexts;
        _currentContextId = null;
        _messages.clear();
        _attachmentUrls.clear(); // FIX: Clear attachments
        _isLoading = false;
      });
    } catch (e) {
      _showGlassSnackBar('Error loading data: $e', isError: true);
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
                            Navigator.of(context).pop(); // close the sheet
                            setState(() => _isLoading = true);

                            try {
                              // ✨ FIX: Fetch both messages and attachment URLs
                              final messages = await SupabaseService.instance
                                  .fetchCards(id);
                              final attachments = await SupabaseService.instance
                                  .fetchContextAttachments(id);

                              if (!mounted) return;
                              setState(() {
                                _currentContextId = id;
                                _messages.clear();
                                _attachmentUrls
                                    .clear(); // Clear old attachments

                                // Load the attachment URLs into state
                                for (final att in attachments) {
                                  _attachmentUrls.add(
                                    att['attachment_url'] as String,
                                  );
                                }

                                // Load the message history into state
                                for (final m in messages) {
                                  _messages.add({
                                    'role': m['role'] ?? 'assistant',
                                    'text': m['text'] ?? '',
                                    'type': m['type'] ?? 'text',
                                  });
                                }
                              });
                            } catch (e) {
                              _showGlassSnackBar(
                                'Error loading saved card: $e',
                                isError: true,
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isLoading = false);
                              }
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
                                await _loadInitialData(); // Reload all data
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

  /// (1) Place this inside _StudyListScreenState (e.g. after _openSavedCardsList())
  Widget _buildDiagramPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'Visual Thinking, Unlocked',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Soon you’ll be able to turn any prompt into AI-powered diagrams—flowcharts, mind-maps, UML and more.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Text(
              'Launching 🎉 on or before October 1, 2025',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
                  // Add Photo/Video
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
                        setState(() {
                          _messages.add({
                            'role': 'user',
                            'text': url,
                            'type': 'image',
                          });
                          _attachmentUrls.add(url); // ← track the URL
                        });
                      }
                    },
                  ),

                  // Take Photo
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
                        setState(() {
                          _messages.add({
                            'role': 'user',
                            'text': url,
                            'type': 'image',
                          });
                          _attachmentUrls.add(url); // ← track the URL
                        });
                      }
                    },
                  ),

                  // Attach File (generic)
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

                  // Save (initial)
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
    // Prevent saving an empty card
    if (_messages.isEmpty && _attachmentUrls.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // This part handles the very first save of a new card
      if (_currentContextId == null) {
        final newContextId = await SupabaseService.instance.createContext(
          title: _titleCtl.text.trim().isEmpty
              ? 'Untitled Card'
              : _titleCtl.text.trim(),
          resultFormat: _selectedFormat,
          moreContext: _moreCtl.text.isEmpty ? null : _moreCtl.text.trim(),
          // Pass any attachments that were added before the first save
          attachmentUrls: _attachmentUrls,
        );
        // Set the new ID so that autosave can take over
        setState(() => _currentContextId = newContextId);
      }

      // Perform the upsert for the card's message content
      await SupabaseService.instance.saveCard(
        contextId: _currentContextId!,
        content: {'messages': _messages},
      );

      _showGlassSnackBar('Card saved! 🎉');

      // ✨ FIX: No longer calls _loadInitialData() which would clear the screen
      // Instead, we just refresh the list of saved cards in the background.
      final contexts = await SupabaseService.instance.fetchContexts();
      if (mounted) {
        setState(() {
          _savedContexts = contexts;
        });
      }
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

  /// Smoothly scrolls your ListView to the bottom after new messages.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessageHandler(String text) async {
    if (text.isEmpty || !mounted) return;

    // If we haven't created a context/card yet, force context‐rules first
    if (_currentContextId == null) {
      _openContextRules();
      return;
    }

    // 1) Show the user's message immediately
    final messageType = _displaySection == 1 ? 'image_prompt' : 'text';
    setState(() {
      _messages.add({'role': 'user', 'text': text, 'type': messageType});
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      setState(() => _isLoading = true);

      // 2) Call the right backend function,
      //    sending both prompt and attachments list
      String aiText;
      String aiType;
      if (_displaySection == 1) {
        // Image generation branch
        final response = await Supabase.instance.client.functions.invoke(
          'image-proxy',
          body: {
            'prompt': text,
            'attachments': _attachmentUrls, // URLs of uploaded files
          },
        );
        if (response.status != 200) {
          throw Exception(
            'Image proxy error ${response.status}: ${response.data}',
          );
        }
        aiText = response.data['response'] as String;
        aiType = 'image';
      } else {
        // Text generation branch (multimodal)
        final response = await Supabase.instance.client.functions.invoke(
          'text-proxy',
          body: {
            'prompt': text,
            'attachments': _attachmentUrls, // URLs of uploaded files
          },
        );
        if (response.status != 200) {
          throw Exception(
            'Text proxy error ${response.status}: ${response.data}',
          );
        }
        aiText = response.data['response'] as String;
        aiType = 'text';
      }

      if (!mounted) return;

      // 3) Show the AI's response
      setState(() {
        _isLoading = false;
        _messages.add({'role': 'assistant', 'text': aiText, 'type': aiType});
      });
      _scrollToBottom();

      // 4) ✨ Auto-save the updated conversation
      await SupabaseService.instance.saveCard(
        contextId: _currentContextId!,
        content: {'messages': _messages},
      );
      print('Card autosaved successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showGlassSnackBar('AI error: $e', isError: true);
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

  /// (2) Replace entire _buildCardContent with:
  Widget _buildCardContent(int pageIndex) {
    // If in DIAGRAM tab with no messages, show our placeholder
    if (pageIndex == 1 && _messages.isEmpty && !_isLoading) {
      return _buildDiagramPlaceholder();
    }

    if (_messages.isEmpty && !_isLoading) {
      // existing “no messages” for TEXT/CODE
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
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final type = msg['type'] ?? 'text';
        final text = msg['text'] ?? '';

        Widget content;
        if (type == 'image') {
          // your existing Image.network branch
          content = Image.network(
            text,
            loadingBuilder: (c, child, prog) => prog == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (c, _, __) =>
                const Icon(Icons.error_outline, color: Colors.redAccent),
          );
        } else {
          // user or assistant text bubble
          content = SelectableText(
            text,
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
            child: content,
          ),
        );
      },
    );
  }
}
