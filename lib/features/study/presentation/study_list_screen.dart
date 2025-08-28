import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart'; // for Clipboard
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // add to pubspec.yaml
import 'package:http/http.dart' as http; // add to pubspec.yaml
import 'package:audioplayers/audioplayers.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studywithcharles/shared/widgets/typing_indicator.dart';

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
  bool _showScrollToBottomButton = false;

  bool _isLoading = true;
  List<Map<String, dynamic>> _savedContexts = [];

  final PageController _pageCtrl = PageController();
  final List<Map<String, String>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<String> _attachmentUrls = [];
  final List<String> _sessionAttachmentUrls = [];
  List<String> _permanentAttachmentUrls = [];
  final List<String> _contextRuleSessionUrls = [];

  final TextEditingController _titleCtl = TextEditingController();
  String _selectedFormat = 'Summarize';
  final TextEditingController _moreCtl = TextEditingController();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // We no longer need to clear the state when the app is paused.
    // This prevents the card from resetting when you pick an image.
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();

    // show/hide FAB when user scrolls
    _scroll.addListener(() {
      final atBottom =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 100;
      if (_showScrollToBottomButton == atBottom) {
        setState(() {
          _showScrollToBottomButton = !atBottom;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(() {});
    _msgCtrl.dispose();
    _scroll.dispose();
    _pageCtrl.dispose();
    _titleCtl.dispose();
    _moreCtl.dispose();
    super.dispose();
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
        _sessionAttachmentUrls.clear(); // Clear session attachments
        _permanentAttachmentUrls.clear(); // Clear permanent attachments
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
                            Navigator.of(context).pop();
                            setState(() => _isLoading = true);
                            try {
                              final fullContextData = _savedContexts.firstWhere(
                                (c) => c['id'] == id,
                              );

                              final results = await Future.wait([
                                SupabaseService.instance.fetchCards(id),
                                SupabaseService.instance
                                    .fetchContextAttachments(id),
                              ]);

                              // --- FIX #1: RESTORE THE CORRECT TYPE FOR MESSAGES ---
                              final messages = results[0];

                              // --- FIX #2: SAFER ATTACHMENT PROCESSING ---
                              final rawAttachments =
                                  results[1] as List<dynamic>;
                              final attachments = rawAttachments
                                  // First, filter out any items that aren't the format we want
                                  .where(
                                    (e) =>
                                        e is Map<String, dynamic> &&
                                        e['url'] is String,
                                  )
                                  // Then, safely map the valid items to their URL strings
                                  .map<String>((e) => e['url'])
                                  .toList();

                              if (!mounted) return;

                              setState(() {
                                _currentContextId = id;
                                _messages.clear();
                                _sessionAttachmentUrls.clear();
                                _permanentAttachmentUrls = attachments;

                                _titleCtl.text = fullContextData['title'] ?? '';
                                _selectedFormat =
                                    fullContextData['result_format'] ??
                                    'Summarize';
                                _moreCtl.text =
                                    fullContextData['more_context'] ?? '';

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
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _confirmDelete(ctx['id'] as String, title),
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

  /// Shows a “delete this card?” dialog, deletes it if confirmed,
  /// then refreshes the list.
  Future<void> _confirmDelete(String contextId, String title) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete saved card?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await SupabaseService.instance.deleteContext(contextId);
      _showGlassSnackBar('Deleted "$title"');
      // If sheet is still open, close it
      if (Navigator.canPop(context)) Navigator.pop(context);
      // Refresh
      await _loadInitialData();
    }
  }

  /// Smart helper for picking, uploading, and queuing an attachment URL.
  Future<void> _handleFileUpload(ImageSource source) async {
    // 0️⃣ Request the right permission
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else {
      // On Android Q+ scoped storage, READ_EXTERNAL_STORAGE is enough.
      // On Android 13+, you might consider Permission.photos or Permission.videos,
      // but READ_EXTERNAL_STORAGE will cover gallery.
      permission =
          Permission.photos; // covers images on iOS, will fallback on Android
    }

    final status = await permission.request();
    if (!status.isGranted) {
      _showGlassSnackBar(
        source == ImageSource.camera
            ? 'Camera permission is required to take photos.'
            : 'Storage permission is required to select images.',
        isError: true,
      );
      return;
    }

    // 1️⃣ Close the sheet immediately.
    Navigator.of(context).pop();

    // 2️⃣ Prevent more than 3 attachments.
    if (_attachmentUrls.length >= 3) {
      _showGlassSnackBar('You can attach up to 3 images only.', isError: true);
      return;
    }

    // 3️⃣ Ensure context exists
    if (_currentContextId == null) {
      _showGlassSnackBar('Creating new card...');
      try {
        final newContextId = await SupabaseService.instance.createContext(
          title: _titleCtl.text.trim().isEmpty
              ? 'Untitled Card'
              : _titleCtl.text.trim(),
          resultFormat: _selectedFormat,
          moreContext: _moreCtl.text.isEmpty ? null : _moreCtl.text.trim(),
        );
        if (!mounted) return;
        setState(() => _currentContextId = newContextId);
      } catch (e) {
        _showGlassSnackBar('Failed to create card: $e', isError: true);
        return;
      }
    }

    // 4️⃣ Let the user pick or take a photo.
    final file = await _pickImage(source);
    if (file == null) return;

    // 5️⃣ Upload and link it.
    _showGlassSnackBar('Uploading…');
    try {
      final url = await SupabaseService.instance.uploadAttachment(file);
      await SupabaseService.instance.addContextAttachment(
        contextId: _currentContextId!,
        url: url,
      );

      // 6️⃣ Add the URL to the state to display the thumbnail.
      setState(() {
        _attachmentUrls.add(url);
      });
      _showGlassSnackBar('Image added! You can add more or type your prompt.');
    } catch (e) {
      _showGlassSnackBar('Upload failed: $e', isError: true);
    }
  }

  /// Opens your attachment menu and routes taps to the helper above.
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
                    onTap: () => _handleFileUpload(ImageSource.gallery),
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
                    onTap: () => _handleFileUpload(ImageSource.camera),
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
                      _showGlassSnackBar('File picker not implemented yet');
                    },
                  ),
                  const Divider(color: Colors.white24),
                  if (_currentContextId != null)
                    const ListTile(
                      leading: Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                      ),
                      title: Text(
                        'CARD IS SAVED',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
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

  Future<File?> _pickImage(ImageSource src) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: src,
      imageQuality: 80,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<void> _saveCurrentCard() async {
    // This function is now ONLY for the very first save.
    // Do nothing if the card is empty or already exists.
    if ((_messages.isEmpty && _attachmentUrls.isEmpty) ||
        _currentContextId != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the context record and get the new ID.
      final newContextId = await SupabaseService.instance.createContext(
        title: _titleCtl.text.trim().isEmpty
            ? 'Untitled Card'
            : _titleCtl.text.trim(),
        resultFormat: _selectedFormat,
        moreContext: _moreCtl.text.isEmpty ? null : _moreCtl.text.trim(),
      );

      // 2. Link any attachments that were added *before* the first save.
      for (final url in _attachmentUrls) {
        await SupabaseService.instance.addContextAttachment(
          contextId: newContextId,
          url: url,
        );
      }

      // 3. Save the initial card content (messages).
      await SupabaseService.instance.saveCard(
        contextId: newContextId,
        content: {'messages': _messages},
      );

      // 4. Update the UI state.
      if (!mounted) return;
      setState(() {
        _currentContextId = newContextId;
      });

      _showGlassSnackBar('Card saved! 🎉');

      // 5. Refresh the list of saved cards in the background without clearing the UI.
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

  /// Opens your context‐rules modal, now with image + file picking (50 MB limit),
  /// permission checks, and a preview of permanently attached images.
  /// 2️⃣ New helper to pick & upload from inside the context-rules sheet:
  Future<void> _pickAndUploadContextRuleAttachment() async {
    // request permission, pick image, etc. (same as your _pickImage + upload flow)
    final file = await _pickImage(ImageSource.gallery);
    if (file == null) return;

    _showGlassSnackBar('Uploading attachment…');
    try {
      final url = await SupabaseService.instance.uploadAttachment(file);
      setState(() {
        _contextRuleSessionUrls.add(url);
      });
      _showGlassSnackBar('Attachment added to context rules!');
    } catch (e) {
      _showGlassSnackBar('Upload failed: $e', isError: true);
    }
  }

  /// 3️⃣ Updated _openContextRules, replacing your old one:
  Future<void> _openContextRules() async {
    setState(() => _rulesOpen = true);

    // merge permanent + in-session for display
    final allAttachments = [
      ..._permanentAttachmentUrls,
      ..._contextRuleSessionUrls,
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
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

                        // ◼️ Course Title field
                        TextField(
                          controller: _titleCtl,
                          decoration: const InputDecoration(
                            labelText: 'Course Title',
                            labelStyle: TextStyle(color: Colors.white70),
                            hintText: 'e.g. Linear Algebra',
                            hintStyle: TextStyle(color: Colors.white54),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        // ◼️ Result Format dropdown with all five options
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
                          onChanged: (v) =>
                              setModalState(() => _selectedFormat = v!),
                          decoration: const InputDecoration(
                            labelText: 'Result Format',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                          ),
                          dropdownColor: const Color.fromRGBO(30, 30, 30, 1),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        // ► direct upload button
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.add_a_photo,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            'Add Photo/Video',
                            style: TextStyle(color: Colors.white70),
                          ),
                          onPressed: () async {
                            await _pickAndUploadContextRuleAttachment();
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(height: 12),

                        // ► attachment thumbnails
                        if (allAttachments.isNotEmpty)
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: allAttachments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final url = allAttachments[i];
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, st) => Container(
                                          color: Colors.white10,
                                          child: const Icon(
                                            Icons.error_outline,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -8,
                                      right: -8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            _permanentAttachmentUrls.remove(
                                              url,
                                            );
                                            _contextRuleSessionUrls.remove(url);
                                          });
                                        },
                                        child: const CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.black,
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),

                        // ◼️ More Context field
                        TextField(
                          controller: _moreCtl,
                          decoration: const InputDecoration(
                            labelText: 'More Context',
                            labelStyle: TextStyle(color: Colors.white70),
                            hintText: 'Any extra rules or constraints',
                            hintStyle: TextStyle(color: Colors.white54),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // ◼️ Cancel / Save buttons
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
                                  : () {
                                      Navigator.of(context).pop();
                                      _saveContextRules();
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
          );
        },
      ),
    );

    if (mounted) setState(() => _rulesOpen = false);
  }

  /// 4️⃣ Finally, update your save-context call so it also links in-session attachments:
  Future<void> _saveContextRules() async {
    if (_currentContextId != null) {
      await SupabaseService.instance.updateContext(
        id: _currentContextId!,
        title: _titleCtl.text.trim(),
        resultFormat: _selectedFormat,
        moreContext: _moreCtl.text.trim(),
      );
      // link any NEW attachments
      for (final url in _contextRuleSessionUrls) {
        await SupabaseService.instance.addContextAttachment(
          contextId: _currentContextId!,
          url: url,
        );
        _permanentAttachmentUrls.add(url);
      }
      _contextRuleSessionUrls.clear();

      _showGlassSnackBar('Context updated!');
      return;
    }

    // … your existing “create new context” logic …
    final newId = await SupabaseService.instance.createContext(
      title: _titleCtl.text.trim().isEmpty
          ? 'Untitled Card'
          : _titleCtl.text.trim(),
      resultFormat: _selectedFormat,
      moreContext: _moreCtl.text.trim(),
    );
    // link attachments
    for (final url in _contextRuleSessionUrls) {
      await SupabaseService.instance.addContextAttachment(
        contextId: newId,
        url: url,
      );
      _permanentAttachmentUrls.add(url);
    }
    _contextRuleSessionUrls.clear();

    setState(() => _currentContextId = newId);
    _showGlassSnackBar('Context saved! You can now ask questions.');
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
    final promptText = text.trim();
    if (promptText.isEmpty && _sessionAttachmentUrls.isEmpty) return;

    if (_currentContextId == null) {
      _openContextRules();
      return;
    }

    // Use the new session attachments list
    final attachmentsForThisMessage = List<String>.from(_sessionAttachmentUrls);

    setState(() {
      if (promptText.isNotEmpty) {
        _messages.add({'role': 'user', 'text': promptText, 'type': 'text'});
      }
      for (final url in attachmentsForThisMessage) {
        _messages.add({'role': 'user', 'text': url, 'type': 'image'});
      }
      _messages.add({'role': 'assistant', 'text': '', 'type': 'typing'});

      _msgCtrl.clear();
      _sessionAttachmentUrls.clear(); // Clear session list after sending
    });
    _scrollToBottom();

    try {
      // The permanent attachments are already in state, no need to fetch again
      final payload = {
        'prompt': promptText,
        'chat_history': _messages.sublist(0, _messages.length - 1),
        'attachments': {
          'session': attachmentsForThisMessage,
          'context': _permanentAttachmentUrls, // Use the state variable
        },
        'context_rules': {
          'title': _titleCtl.text.trim(),
          'result_format': _selectedFormat,
          'more_context': _moreCtl.text.trim(),
        },
      };

      final functionName = _displaySection == 1 ? 'image-proxy' : 'text-proxy';
      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: payload,
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] ?? 'Unknown AI error';
        throw Exception(errorMessage);
      }

      final aiType = _displaySection == 1 ? 'image' : 'text';
      final aiText = response.data['response'] as String;

      if (!mounted) return;

      setState(() {
        _messages.removeLast();
        _messages.add({'role': 'assistant', 'text': aiText, 'type': aiType});
      });
      _scrollToBottom();

      await SupabaseService.instance.saveCard(
        contextId: _currentContextId!,
        content: {'messages': _messages},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeLast());
      _showGlassSnackBar(e.toString(), isError: true);
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
          // Top segment picker
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

          // Main content + FAB overlay
          Expanded(
            child: Stack(
              children: [
                // PageView of chat / diagram / code
                PageView(
                  controller: _pageCtrl,
                  onPageChanged: (idx) => setState(() => _displaySection = idx),
                  children: [
                    _buildCardContent(0),
                    _buildCardContent(1),
                    _buildCardContent(2),
                  ],
                ),

                // Loading spinner
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),

                // --- CHANGE IS HERE ---
                // Scroll-to-bottom FAB (centered and styled)
                if (_showScrollToBottomButton)
                  Positioned(
                    // You can change left/right to just 'right: 20' to align it right
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Center(
                      child: FloatingActionButton(
                        mini: true,
                        // Set background to a semi-transparent black
                        backgroundColor: Colors.black.withOpacity(0.7),
                        onPressed: _scrollToBottom,
                        child: const Icon(
                          Icons.arrow_downward,
                          // Set icon color to white
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Attachments preview + input row
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A. Thumbnails row
                if (_attachmentUrls.isNotEmpty)
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachmentUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final url = _attachmentUrls[idx];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _attachmentUrls.removeAt(idx);
                                  });
                                },
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // B. Input row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                                  hintText: 'Type your question here…',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                                onSubmitted: _sendMessageHandler,
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.send,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: () =>
                                  _sendMessageHandler(_msgCtrl.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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

  /// Sends the given `text` to Speechify’s TTS API and plays back the result.
  /// Uses your SPEECHIFY_API_KEY (and optional SPEECHIFY_VOICE_ID) from `.env`.
  /// Sends the given text to Speechify’s TTS API and plays back the result.
  Future<void> _readAloud(String text) async {
    final apiKey = dotenv.env['SPEECHIFY_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _showGlassSnackBar(
        'Missing SPEECHIFY_API_KEY in your .env file.',
        isError: true,
      );
      return;
    }

    final uri = Uri.parse('https://api.sws.speechify.com/v1/audio/speech');
    _showGlassSnackBar('Generating audio…');

    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'input': text,
          'voice_id':
              dotenv.env['SPEECHIFY_VOICE_ID'] ??
              'Matthew', // Using a high-quality default
          // ✨ FIX: Request the more compatible MP3 format instead of WAV
          'audio_format': 'mp3',
        }),
      );

      if (resp.statusCode != 200) {
        var err = 'TTS failed (${resp.statusCode})';
        try {
          final json = jsonDecode(resp.body);
          if (json['error']?['message'] != null) {
            err = '${json['error']['message']} (${resp.statusCode})';
          }
        } catch (_) {}
        _showGlassSnackBar(err, isError: true);
        return;
      }

      final Map<String, dynamic> data = jsonDecode(resp.body);
      final String? b64 = data['audio_data'] as String?;

      if (b64 == null) {
        _showGlassSnackBar('API did not return audio data.', isError: true);
        return;
      }

      final bytes = base64Decode(b64);
      final player = AudioPlayer();

      // BytesSource works perfectly with MP3 data
      await player.play(BytesSource(bytes));
    } on SocketException {
      _showGlassSnackBar('TTS Error: No internet connection.', isError: true);
    } catch (e) {
      _showGlassSnackBar('TTS Error: $e', isError: true);
    }
  }

  /// 2) Chat bubble builder: now includes a typing indicator
  Widget _buildCardContent(int pageIndex) {
    if (pageIndex == 1 && _messages.isEmpty) {
      return _buildDiagramPlaceholder();
    }
    // We remove the !_isLoading check here because the list now handles its own loading state
    if (_messages.isEmpty) {
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

        // --- CHANGE IS HERE ---
        // If the message type is "typing", show the loading indicator.
        if (type == 'typing') {
          return const Align(
            alignment: Alignment.centerLeft,
            child: TypingIndicator(), // We'll create this widget next
          );
        }

        Widget content = type == 'image'
            ? Image.network(
                text,
                loadingBuilder: (c, child, prog) => prog == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (c, _, __) =>
                    const Icon(Icons.error_outline, color: Colors.redAccent),
              )
            : SelectableText(
                text,
                style: TextStyle(color: isUser ? Colors.black : Colors.white),
              );

        return Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? Colors.cyanAccent
                      : const Color.fromRGBO(255, 255, 255, 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: content,
              ),
            ),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        _showGlassSnackBar('Copied to clipboard');
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.volume_up,
                        size: 20,
                        color: Colors.white70,
                      ),
                      onPressed: () => _readAloud(text),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.share,
                        size: 20,
                        color: Colors.white70,
                      ),
                      onPressed: () => Share.share(text),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
