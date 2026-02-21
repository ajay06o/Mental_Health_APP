import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class MyUploadsScreen extends StatefulWidget {
  const MyUploadsScreen({super.key});

  @override
  State<MyUploadsScreen> createState() => _MyUploadsScreenState();
}

class _MyUploadsScreenState extends State<MyUploadsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final res = await ApiClient.getUploads();
    return List<dynamic>.from(res ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Uploads')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: Text('No uploads'));

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              final text = it['text'] as String?;
              final screenshot = it['screenshot_base64'] as String?;

              Uint8List? bytes;
              if (screenshot != null && screenshot.isNotEmpty) {
                try { bytes = base64Decode(screenshot); } catch (_) { bytes = null; }
              }

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(it['content_type'] ?? 'upload'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (text != null) Text(text),
                      if (bytes != null) Padding(padding: const EdgeInsets.only(top:8.0), child: Image.memory(bytes, height: 120)),
                    ],
                  ),
                  isThreeLine: text != null || bytes != null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
