// lib/features/profile/presentation/profile_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isLoading = true;

  // Profile fields
  String _name = '';
  String _username = '';
  String _email = '';
  String _bio = '';
  String _usdtWallet = '';
  String? _photoUrl;
  String _tiktokUrl = '';
  String _instagramUrl = '';
  String _xUrl = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // NOTE: Switched from user.uid to user.id for Supabase Auth
    final profile = await SupabaseService.instance.fetchUserProfile(user.uid);
    if (!mounted) return;

    setState(() {
      _name = profile['display_name'] as String? ?? '';
      _username = profile['username'] as String? ?? '';
      _email = user.email!;
      _bio = profile['bio'] as String? ?? '';
      _usdtWallet = profile['wallet_address'] as String? ?? '';
      _photoUrl = profile['avatar_url'] as String?;

      // --- NEW: Safely load social media links from the JSONB column ---
      final socialHandles = profile['social_handles'] as Map<String, dynamic>?;
      if (socialHandles != null) {
        _tiktokUrl = socialHandles['tiktok'] as String? ?? '';
        _instagramUrl = socialHandles['instagram'] as String? ?? '';
        _xUrl = socialHandles['x'] as String? ?? '';
      }

      _isLoading = false;
    });
  }

  Future<void> _pickProfilePhoto() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final url = await SupabaseService.instance.uploadAttachment(
      File(file.path),
    );
    await SupabaseService.instance.updateUserProfile(photoUrl: url);
    setState(() => _photoUrl = url);
  }

  Future<void> _editField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onSaved,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) async {
    final controller = TextEditingController(text: initialValue);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $label'),
        content: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          validator: validator,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (validator != null && validator(val) != null) return;
              onSaved(val);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickProfilePhoto,
                child: ClipOval(
                  child: Container(
                    width: 120,
                    height: 120,
                    color: Colors.white10,
                    child: _photoUrl != null
                        ? Image.network(_photoUrl!, fit: BoxFit.cover)
                        : const Icon(
                            Icons.person,
                            size: 64,
                            color: Colors.white70,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickProfilePhoto,
                icon: const Icon(Icons.edit, color: Colors.cyanAccent),
                label: const Text(
                  'Change Photo',
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '@$_username',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(_email, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              _buildInfoTile(
                icon: Icons.person,
                label: 'Name',
                value: _name,
                onEdit: () => _editField(
                  label: 'Name',
                  initialValue: _name,
                  validator: (v) =>
                      v != null && v.isNotEmpty ? null : 'Required',
                  onSaved: (val) async {
                    await SupabaseService.instance.updateUserProfile(name: val);
                    setState(() => _name = val);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.alternate_email,
                label: 'Username',
                value: _username,
                onEdit: () => _editField(
                  label: 'Username',
                  initialValue: _username,
                  validator: (v) {
                    final re = RegExp(r'^[a-zA-Z0-9_]{3,15}$');
                    if (v == null || !re.hasMatch(v)) {
                      return '3–15 chars: letters, numbers, underscore';
                    }
                    return null;
                  },
                  onSaved: (val) async {
                    await SupabaseService.instance.updateUserProfile(
                      username: val,
                    );
                    setState(() => _username = val);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.info_outline,
                label: 'Bio',
                value: _bio,
                onEdit: () => _editField(
                  label: 'Bio',
                  initialValue: _bio,
                  onSaved: (val) async {
                    await SupabaseService.instance.updateUserProfile(bio: val);
                    setState(() => _bio = val);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // --- NEW SOCIAL MEDIA TILES ---
              _buildInfoTile(
                icon: Icons.music_note,
                label: 'TikTok URL',
                value: _tiktokUrl,
                onEdit: () => _editField(
                  label: 'TikTok URL',
                  initialValue: _tiktokUrl,
                  keyboardType: TextInputType.url,
                  onSaved: (val) async {
                    await SupabaseService.instance.updateUserSocials(
                      tiktok: val,
                    );
                    setState(() => _tiktokUrl = val);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.camera_alt,
                label: 'Instagram URL',
                value: _instagramUrl,
                onEdit: () => _editField(
                  label: 'Instagram URL',
                  initialValue: _instagramUrl,
                  keyboardType: TextInputType.url,
                  onSaved: (val) async {
                    await SupabaseService.instance.updateUserSocials(
                      instagram: val,
                    );
                    setState(() => _instagramUrl = val);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.close,
                label: 'X (Twitter) URL',
                value: _xUrl,
                onEdit: () => _editField(
                  label: 'X (Twitter) URL',
                  initialValue: _xUrl,
                  keyboardType: TextInputType.url,
                  onSaved: (val) async {
                    await SupabaseService.instance.updateUserSocials(x: val);
                    setState(() => _xUrl = val);
                  },
                ),
              ),

              // --- END OF NEW TILES ---
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.account_balance_wallet,
                label: 'USDT Wallet',
                value: _usdtWallet,
                onEdit: () => _editField(
                  label: 'USDT Wallet',
                  initialValue: _usdtWallet,
                  validator: (v) =>
                      v != null && v.isNotEmpty && v.startsWith('0x')
                      ? null
                      : 'Must be a valid wallet address',
                  onSaved: (val) async {
                    await SupabaseService.instance.updateUserProfile(
                      usdtWallet: val,
                    );
                    setState(() => _usdtWallet = val);
                  },
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  await AuthService.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white10,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      value.isNotEmpty ? value : 'Not set',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.cyanAccent),
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
