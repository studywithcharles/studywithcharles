// lib/features/study/presentation/create_context_screen.dart

import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';

class CreateContextScreen extends StatefulWidget {
  static const routeName = '/create-context';
  const CreateContextScreen({super.key});

  @override
  State<CreateContextScreen> createState() => _CreateContextScreenState();
}

class _CreateContextScreenState extends State<CreateContextScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _formatCtrl = TextEditingController();
  final _moreCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _formatCtrl.dispose();
    _moreCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.createContext(
        title: _titleCtrl.text.trim(),
        resultFormat: _formatCtrl.text.trim(),
        moreContext: _moreCtrl.text.trim(),
      );
      Navigator.of(context).pop(true); // signal “created”
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating context: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Study Context')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _formatCtrl,
                decoration: const InputDecoration(labelText: 'Result Format'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _moreCtrl,
                decoration: const InputDecoration(
                  labelText: 'More Context (optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Create Context'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
