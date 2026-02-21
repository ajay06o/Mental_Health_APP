import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  final _textController = TextEditingController();
  String _type = 'post';
  XFile? _pickedImage;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      String? b64;
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        b64 = base64Encode(bytes);
      }

      final item = {
        'type': _type,
        'text': _textController.text.isEmpty ? null : _textController.text,
        'screenshot_base64': b64,
      };

      final res = await ApiClient.uploadContent([item]);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Content')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'post', child: Text('Post')),
                DropdownMenuItem(value: 'caption', child: Text('Caption')),
                DropdownMenuItem(value: 'comment', child: Text('Comment')),
                DropdownMenuItem(value: 'screenshot', child: Text('Screenshot')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'post'),
              decoration: const InputDecoration(labelText: 'Content Type'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _textController,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Text (optional)', border: OutlineInputBorder()),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text('Pick Screenshot'),
                ),
                const SizedBox(width: 12),
                if (_pickedImage != null) const Text('Image selected'),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const CircularProgressIndicator() : const Text('Upload'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
