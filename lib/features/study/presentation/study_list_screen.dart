import 'dart:async';
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
import 'package:studywithcharles/shared/widgets/glass_container.dart';

class StudyListScreen extends StatefulWidget {
  static const routeName = '/study';
  const StudyListScreen({super.key});

  @override
  State<StudyListScreen> createState() => _StudyListScreenState();
}

class _StudyListScreenState extends State<StudyListScreen>
    with WidgetsBindingObserver {
  String? _currentContextId;
  Map<String, dynamic>? _userProfile;
  bool _showScrollToBottomButton = false;
  bool _isDiagramMode = false;

  bool _isLoading = true;
  List<Map<String, dynamic>> _savedContexts = [];

  final List<Map<String, String>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<String> _sessionAttachmentUrls = [];
  List<String> _permanentAttachmentUrls = [];

  final TextEditingController _titleCtl = TextEditingController();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // We no longer need to clear the state when the app is paused.
    // This prevents the card from resetting when you pick an image.
  }

  // --- Paste these methods inside _StudyListScreenState ---
  // 1) Helper: wait for Firebase user and set Supabase Authorization header
  Future<String?> _waitForFirebaseUserAndSetSupabaseHeader({
    int timeoutSeconds = 5,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      final fbUser = AuthService.instance.currentUser;
      if (fbUser != null) {
        try {
          final token = await fbUser.getIdToken();
          Supabase.instance.client.headers.update(
            'Authorization',
            (value) => 'Bearer ${token ?? ''}',
            ifAbsent: () => 'Bearer ${token ?? ''}',
          );
          // ignore: avoid_print
          print(
            '[Study] Firebase user found; supabase header set. uid=${fbUser.uid}',
          );
        } catch (e) {
          // ignore: avoid_print
          print('[Study] Error fetching token for user: $e');
        }
        return fbUser.uid;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    // timed out
    // ignore: avoid_print
    print('[Study] No Firebase user found within $timeoutSeconds seconds.');
    return null;
  }

  // 2) initState replacement — wait for firebase user and then load or fall back
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Non-blocking: wait up to 5s for Firebase user and set the supabase header,
    // then load data for that user, otherwise initialize empty state.
    _waitForFirebaseUserAndSetSupabaseHeader(timeoutSeconds: 5).then((uid) {
      if (uid != null) {
        _loadInitialDataForUser(uid);
      } else {
        if (!mounted) return;
        setState(() {
          _savedContexts = [];
          _userProfile = null;
          _currentContextId = null;
          _messages.clear();
          _sessionAttachmentUrls.clear();
          _permanentAttachmentUrls.clear();
          _isLoading = false;
        });
      }
    });

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

  // 3) _loadInitialDataForUser: fetch contexts/profile for a given firebase uid
  Future<void> _loadInitialDataForUser(String userId) async {
    // Keep UI usable — only show full-screen loader for operations that must block.
    try {
      // Concurrent fetch, with a short timeout so UI doesn't hang
      final futures = Future.wait([
        SupabaseService.instance.fetchContexts(),
        SupabaseService.instance.fetchUserProfile(userId),
      ]);

      List<dynamic> results;
      try {
        results = await futures.timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              throw TimeoutException('Initial data fetch timed out (5s).'),
        );
      } on TimeoutException catch (te) {
        // ignore: avoid_print
        print('[Study] _loadInitialDataForUser timeout: $te');
        if (!mounted) return;
        setState(() {
          _savedContexts = [];
          _userProfile = null;
          _currentContextId = null;
          _messages.clear();
          _sessionAttachmentUrls.clear();
          _permanentAttachmentUrls.clear();
          _isLoading = false;
        });
        _showGlassSnackBar(
          'Error loading data: request timed out.',
          isError: true,
        );
        return;
      }

      final fetchedContexts = (results[0] as List?) ?? <Map<String, dynamic>>[];
      final fetchedProfile =
          (results[1] as Map<String, dynamic>?) ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _savedContexts = fetchedContexts.cast<Map<String, dynamic>>();
        _userProfile = Map<String, dynamic>.from(fetchedProfile);
        _currentContextId = null;
        _messages.clear();
        _sessionAttachmentUrls.clear();
        _permanentAttachmentUrls.clear();
        _isLoading = false;
      });

      // ignore: avoid_print
      print(
        '[Study] Loaded ${_savedContexts.length} saved contexts for firebase uid=$userId',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[Study] _loadInitialDataForUser error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _savedContexts = [];
        _userProfile = null;
        _currentContextId = null;
        _messages.clear();
        _sessionAttachmentUrls.clear();
        _permanentAttachmentUrls.clear();
        _isLoading = false;
      });
      _showGlassSnackBar('Error loading data: ${e.toString()}', isError: true);
    }
  }

  void _showGlassSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: isError ? Colors.redAccent : Colors.greenAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        // swallow any errors: we don't want snack errors to crash the app.
        // ignore: avoid_print
        print('[showGlassSnackBar] failed: $e');
      }
    });
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
      isScrollControlled: true, // Allows the sheet to be taller if needed
      builder: (_) => StatefulBuilder(
        // Use a StatefulBuilder to manage state within the sheet
        builder: (BuildContext context, StateSetter setModalState) {
          return GlassContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Make the sheet wrap its content
              children: [
                Text(
                  'Saved Cards',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 12),
                if (_savedContexts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'No saved cards.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                else
                  // Make the list scrollable if it's too long
                  Flexible(
                    child: ListView.builder(
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
                            // (Your existing onTap logic remains the same)
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

                              final messages = results[0];
                              final rawAttachments =
                                  results[1] as List<dynamic>;
                              final attachments = rawAttachments
                                  .where(
                                    (e) =>
                                        e is Map<String, dynamic> &&
                                        e['url'] is String,
                                  )
                                  .map<String>((e) => e['url'])
                                  .toList();

                              if (!mounted) return;

                              setState(() {
                                _currentContextId = id;
                                _messages.clear();
                                _sessionAttachmentUrls.clear();
                                _permanentAttachmentUrls = attachments;
                                _titleCtl.text = fullContextData['title'] ?? '';

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
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _confirmDelete(ctx['id'] as String, title),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Shows a “delete this card?” dialog, deletes it if confirmed,
  /// then refreshes the list.
  /// Shows a themed dialog to confirm deleting a card.
  Future<void> _confirmDelete(String contextId, String title) async {
    final shouldDelete = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete Card',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Delete Saved Card?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete "$title"? This action cannot be undone.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldDelete == true) {
      // We wrap this in a try-catch for safety
      try {
        setState(() => _isLoading = true);
        await SupabaseService.instance.deleteContext(contextId);
        _showGlassSnackBar('Deleted "$title"');
        // If the modal sheet for saved cards is still open, close it
        if (Navigator.canPop(context)) {
          final currentRoute = ModalRoute.of(context);
          if (currentRoute is ModalBottomSheetRoute) {
            Navigator.pop(context);
          }
        }
        // Refresh the contexts list
        if (_userProfile != null && _userProfile!['id'] != null) {
          await _loadInitialDataForUser(_userProfile!['id']);
        }
      } catch (e) {
        _showGlassSnackBar('Error deleting card: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// Smart helper for picking, uploading, and queuing an attachment URL.
  /// Smart helper for picking, uploading, and queuing an attachment URL.
  Future<void> _handleFileUpload(ImageSource source) async {
    // 0️⃣ Request permission
    final permission = source == ImageSource.camera
        ? Permission.camera
        : Permission.photos;
    final status = await permission.request();
    if (!status.isGranted) {
      _showGlassSnackBar(
        'Permission is required to access photos.',
        isError: true,
      );
      return;
    }

    // 1️⃣ Close the sheet immediately.
    Navigator.of(context).pop();

    // 2️⃣ Prevent more than 3 attachments per message.
    if (_sessionAttachmentUrls.length >= 3) {
      _showGlassSnackBar(
        'You can attach up to 3 images per message.',
        isError: true,
      );
      return;
    }

    // 3️⃣ Let the user pick or take a photo.
    final file = await _pickImage(source);
    if (file == null) return;

    // 4️⃣ Upload it.
    _showGlassSnackBar('Uploading…');
    try {
      final url = await SupabaseService.instance.uploadAttachment(file);

      // 5️⃣ Add the URL to the session state to display the thumbnail.
      setState(() {
        _sessionAttachmentUrls.add(url);
      });
      _showGlassSnackBar('Image added! You can now send your message.');
    } catch (e) {
      _showGlassSnackBar('Upload failed: $e', isError: true);
    }
  }

  /// Opens your attachment menu and routes taps to the helper above.
  /// Opens your card actions menu with the new options.
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
                    leading: const Icon(Icons.palette, color: Colors.white70),
                    title: const Text(
                      'Diagram',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      // --- BEHAVIOR IS CHANGED HERE ---
                      // It now just enables diagram mode and closes the sheet.
                      setState(() => _isDiagramMode = true);
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.attach_file,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Attachments',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openAttachmentMenu();
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
                        _handleSaveCard();
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

  /// Opens a second menu specifically for choosing an attachment type.
  void _openAttachmentMenu() {
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
                      Icons.description,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handles the logic for saving a new card for the first time.
  /// Handles the logic for saving a new card for the first time.
  Future<void> _handleSaveCard() async {
    // 1. Do nothing if the card is already saved.
    if (_currentContextId != null) {
      _showGlassSnackBar('This card is already saved.');
      return;
    }
    // 2. Do nothing if there's nothing to save.
    if (_messages.isEmpty && _sessionAttachmentUrls.isEmpty) {
      _showGlassSnackBar(
        'Add a message or attachment before saving.',
        isError: true,
      );
      return;
    }

    // --- FIX IS HERE ---
    // 3. Check subscription status using the fetched profile.
    final isPlusUser = _userProfile?['is_premium'] ?? false;
    if (!isPlusUser && _savedContexts.length >= 3) {
      _showGlassSnackBar(
        'Free users can only save up to 3 cards. Upgrade to Plus for unlimited saves!',
        isError: true,
      );
      return;
    }

    // 4. Ensure a title is set.
    bool titleWasSet = _titleCtl.text.trim().isNotEmpty;
    if (!titleWasSet) {
      titleWasSet = await _promptForTitle(isSaving: true);
    }

    // 5. If user cancelled the title prompt, abort the save.
    if (!titleWasSet) return;

    setState(() => _isLoading = true);
    try {
      final newContextId = await SupabaseService.instance.createContext(
        title: _titleCtl.text.trim(),
        resultFormat: 'Summarize', // Default value
        moreContext: null,
      );

      await SupabaseService.instance.saveCard(
        contextId: newContextId,
        content: {'messages': _messages},
      );

      if (!mounted) return;
      setState(() => _currentContextId = newContextId);

      _showGlassSnackBar('Card saved! 🎉');

      // Refresh the list of saved cards in the background
      final contexts = await SupabaseService.instance.fetchContexts();
      if (mounted) {
        setState(() => _savedContexts = contexts);
      }
    } catch (e) {
      _showGlassSnackBar('Error saving card: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Builds the new clickable title bar that replaces the segmented control.
  /// Builds the new clickable title bar with an icon and updated placeholder.
  Widget _buildTitleBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: GestureDetector(
        onTap: () => _promptForTitle(isSaving: false),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                height: 44,
                width: double.infinity,
                color: const Color.fromRGBO(255, 255, 255, 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // --- NEW ICON IS HERE ---
                    const Icon(
                      Icons.menu_book_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _titleCtl.text.trim().isEmpty
                            // --- NEW PLACEHOLDER TEXT IS HERE ---
                            ? 'Course Title'
                            : _titleCtl.text.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.edit, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a dialog to enter or edit the card's title.
  /// Returns true if a title was successfully set, false otherwise.
  /// Shows a custom glassy dialog using GlassContainer to enter or edit the card's title.
  Future<bool> _promptForTitle({required bool isSaving}) async {
    final titleController = TextEditingController(text: _titleCtl.text);
    final wasSet = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Set Title',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        // We wrap your GlassContainer in a standard Dialog widget
        // to get the correct positioning and backdrop behavior.
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            // Using your excellent reusable widget!
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isSaving ? 'Set a Title to Save' : 'Edit Course Title',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Linear Algebra',
                    hintStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                      ),
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          Navigator.of(context).pop(true);
                        }
                      },
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (wasSet == true) {
      setState(() {
        _titleCtl.text = titleController.text.trim();
      });
      return true;
    }
    return false;
  }

  Future<File?> _pickImage(ImageSource src) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: src,
      imageQuality: 80,
    );
    return picked == null ? null : File(picked.path);
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

  // REPLACE the old _sendMessageHandler in study_list_screen.dart WITH THIS
  Future<void> _sendMessageHandler(String text) async {
    final promptText = text.trim();
    if (promptText.isEmpty && _sessionAttachmentUrls.isEmpty) {
      _showGlassSnackBar(
        'Please enter a message or add an attachment.',
        isError: true,
      );
      return;
    }

    final bool wasDiagramMode = _isDiagramMode;
    final attachmentsForThisMessage = List<String>.from(_sessionAttachmentUrls);

    // Update UI right away
    setState(() {
      for (final url in attachmentsForThisMessage) {
        _messages.add({'role': 'user', 'text': url, 'type': 'image'});
      }
      if (promptText.isNotEmpty) {
        _messages.add({'role': 'user', 'text': promptText, 'type': 'text'});
      }
      _messages.add({'role': 'assistant', 'text': '', 'type': 'typing'});
      _msgCtrl.clear();
      _sessionAttachmentUrls.clear();
      _isDiagramMode = false;
    });
    _scrollToBottom();

    try {
      final String functionName = wasDiagramMode ? 'image-proxy' : 'text-proxy';
      final String aiResponseType = wasDiagramMode ? 'image' : 'text';

      // --- THIS IS THE FIX ---
      // Build the FULL payload that both functions expect

      List<Map<String, String>> chatHistoryPayload = _messages
          .where((m) => (m['type'] ?? 'text') != 'typing')
          .map(
            (m) => {
              'role': (m['role'] ?? 'user').toString(),
              'text': (m['text'] ?? '').toString(),
            },
          )
          .toList();

      const int maxHistoryToSend = 8;
      if (chatHistoryPayload.length > maxHistoryToSend) {
        chatHistoryPayload = chatHistoryPayload.sublist(
          chatHistoryPayload.length - maxHistoryToSend,
        );
      }

      final Map<String, dynamic> payload = {
        'prompt': promptText,
        'chat_history': chatHistoryPayload,
        'attachments': {
          'session': attachmentsForThisMessage,
          'context': _permanentAttachmentUrls,
        },
        'title': _titleCtl.text.trim(),
        'context_rules': {
          'title': _titleCtl.text.trim(),
          'result_format': wasDiagramMode ? 'Generate Diagram' : 'Summarize',
          'more_context': wasDiagramMode
              ? 'Create a visual diagram for this prompt'
              : null,
        },
      };

      // --- END OF FIX ---

      final response = await Supabase.instance.client.functions
          .invoke(functionName, body: payload)
          .timeout(
            const Duration(seconds: 60), // Increased timeout for image gen
            onTimeout: () =>
                throw Exception('AI service timed out. Please try again.'),
          );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage =
            errorData?['error'] ??
            errorData?['message'] ??
            'Unknown AI error (${response.status})';
        throw Exception(errorMessage);
      }

      final aiText = (response.data['response'] ?? '') as String;

      if (!mounted) return;
      setState(() {
        _messages.removeLast(); // remove typing indicator
        _messages.add({
          'role': 'assistant',
          'text': aiText,
          'type': aiResponseType,
        });
      });
      _scrollToBottom();

      if (_currentContextId != null) {
        await SupabaseService.instance.saveCard(
          contextId: _currentContextId!,
          content: {'messages': _messages},
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (_messages.isNotEmpty && (_messages.last['type'] == 'typing')) {
        setState(() => _messages.removeLast());
      }
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
        scrolledUnderElevation: 0.0,
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
          _buildTitleBar(),
          Expanded(
            child: Stack(
              children: [
                _buildCardContent(),
                // Polished Loading Indicator
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(24),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 20),
                            Text(
                              'Loading Card...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_showScrollToBottomButton && !_isLoading)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Center(
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.black.withOpacity(0.7),
                        onPressed: _scrollToBottom,
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_sessionAttachmentUrls.isNotEmpty)
                  Container(
                    height: 80,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sessionAttachmentUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final url = _sessionAttachmentUrls[idx];
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
                                    _sessionAttachmentUrls.removeAt(idx);
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
                        padding: const EdgeInsets.only(
                          left: 4,
                          right: 4,
                          top: 2,
                          bottom: 2,
                        ),
                        child: Row(
                          children: [
                            if (_isDiagramMode)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _isDiagramMode = false),
                                  child: const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.cyanAccent,
                                    child: Icon(
                                      Icons.palette,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              )
                            else
                              InkWell(
                                onTap: _openCardActionsMenu,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.cyanAccent,
                                  ),
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
  // REPLACE your old _buildCardContent function WITH THIS
  Widget _buildCardContent() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Start a new conversation!\nAdd attachments or type a question below.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 16),
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

        if (type == 'typing') {
          return const Align(
            alignment: Alignment.centerLeft,
            child: TypingIndicator(),
          );
        }

        // --- THIS IS THE FINAL IMAGE DISPLAY FIX ---
        Widget content;
        if (type == 'image') {
          // Check if the text is a URL or base64 data
          if (text.startsWith('http')) {
            // It's a URL from an attachment
            content = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                text,
                loadingBuilder: (c, child, prog) => prog == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (c, _, __) =>
                    const Icon(Icons.error_outline, color: Colors.redAccent),
              ),
            );
          } else {
            // It's base64 data from our new image-proxy
            try {
              final imageBytes = base64Decode(text);
              content = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(imageBytes),
              );
            } catch (e) {
              // If decoding fails, show a broken image icon
              content = const Icon(
                Icons.broken_image,
                color: Colors.redAccent,
                size: 40,
              );
            }
          }
        } else {
          // It's a normal text message
          content = SelectableText(
            text,
            style: TextStyle(color: isUser ? Colors.black : Colors.white),
          );
        }
        // --- END OF FIX ---

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
            if (!isUser &&
                type == 'text' &&
                text.isNotEmpty) // Only show actions for non-empty text
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
