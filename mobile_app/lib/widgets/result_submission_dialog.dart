import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/match_provider.dart';
import '../providers/auth_provider.dart';

class ResultSubmissionDialog extends ConsumerStatefulWidget {
  final String matchId;

  const ResultSubmissionDialog({super.key, required this.matchId});

  @override
  ConsumerState<ResultSubmissionDialog> createState() => _ResultSubmissionDialogState();
}

class _ResultSubmissionDialogState extends ConsumerState<ResultSubmissionDialog> {
  final _killsController = TextEditingController();
  final _rankController = TextEditingController();
  File? _imageFile;
  bool _isUploading = false;
  String? _uploadError;

  @override
  void dispose() {
    _killsController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _imageFile = File(result.files.single.path!);
        _uploadError = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_imageFile == null) {
      setState(() => _uploadError = 'Please select a screenshot.');
      return;
    }
    if (_killsController.text.isEmpty || _rankController.text.isEmpty) {
      setState(() => _uploadError = 'Please enter your kills and rank.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final userId = ref.read(authProvider).userId;
      if (userId == null) throw Exception('Not authenticated.');

      final ext = _imageFile!.path.split('.').last;
      final fileName = '${widget.matchId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // 1. Upload to Supabase Storage
      await supabase.storage.from('match_proofs').upload(fileName, _imageFile!);
      
      // 2. Get Public URL
      final imageUrl = supabase.storage.from('match_proofs').getPublicUrl(fileName);

      // 3. Submit securely to Node.js backend
      await ref.read(matchActionProvider.notifier).submitProof(
        widget.matchId,
        int.parse(_killsController.text),
        int.parse(_rankController.text),
        imageUrl,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Match Proof'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_uploadError != null) 
              Text(_uploadError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            
            GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                color: Colors.blueGrey.withOpacity(0.3),
                alignment: Alignment.center,
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : const Text('Tap to select Screenshot', style: TextStyle(color: Colors.white70)),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _killsController,
              decoration: const InputDecoration(labelText: 'Total Kills', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _rankController,
              decoration: const InputDecoration(labelText: 'Placement (e.g., 1 for Booyah)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              enabled: !_isUploading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submit,
          child: _isUploading 
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
            : const Text('Submit'),
        ),
      ],
    );
  }
}
