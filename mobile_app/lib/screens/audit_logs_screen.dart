import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  late Future<List<dynamic>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchLogs();
  }

  Future<List<dynamic>> _fetchLogs() async {
    final res = await ApiClient.get('/social/audit-logs');
    return List<dynamic>.from(res ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: FutureBuilder<List<dynamic>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) return const Center(child: Text('No audit logs'));

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, i) {
              final l = logs[i];
              return ListTile(
                title: Text(l['action'] ?? 'action'),
                subtitle: Text(l['details'] ?? ''),
                trailing: Text(l['timestamp']?.toString() ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
