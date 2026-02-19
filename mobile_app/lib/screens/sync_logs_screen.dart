import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/social_service.dart';

class SyncLogsScreen extends StatefulWidget {
  const SyncLogsScreen({super.key});

  @override
  State<SyncLogsScreen> createState() => _SyncLogsScreenState();
}

class _SyncLogsScreenState extends State<SyncLogsScreen> {
  late Future<List<Map<String, dynamic>>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = SocialService.getSyncLogs();
  }

  void _refresh() {
    setState(() {
      _logsFuture = SocialService.getSyncLogs();
    });
  }

  // ============================================
  // STATUS COLOR
  // ============================================
  Color _statusColor(bool success) {
    return success ? Colors.green : Colors.red;
  }

  IconData _statusIcon(bool success) {
    return success ? Icons.check_circle : Icons.error;
  }

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sync History Logs"),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _logsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _errorState();
            }

            final logs = snapshot.data ?? [];

            if (logs.isEmpty) {
              return _emptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (_, index) {
                final log = logs[index];
                return _logCard(log);
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================
  // LOG CARD
  // ============================================
  Widget _logCard(Map<String, dynamic> log) {
    final platform = log["platform"] ?? "unknown";
    final success = log["success"] ?? false;
    final count = log["count"] ?? 0;
    final timestamp = log["timestamp"] ?? "";
    final errorMessage = log["error"];

    String formattedTime = "";
    if (timestamp.isNotEmpty) {
      try {
        formattedTime = DateFormat(
          'dd MMM yyyy, hh:mm a',
        ).format(DateTime.parse(timestamp));
      } catch (_) {}
    }

    final color = _statusColor(success);

    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    platform.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _statusIcon(success),
                  color: color,
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              "Posts Analyzed: $count",
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 6),

            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            if (!success && errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                "Error: $errorMessage",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _retry(platform),
                child: const Text("Retry Sync"),
              )
            ],
          ],
        ),
      ),
    );
  }

  // ============================================
  // RETRY
  // ============================================
  Future<void> _retry(String platform) async {
    try {
      await SocialService.retrySync(platform);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Retry started"),
        ),
      );

      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // ============================================
  // EMPTY STATE
  // ============================================
  Widget _emptyState() {
    return const Center(
      child: Text(
        "No sync logs available yet.\nStart syncing your accounts.",
        textAlign: TextAlign.center,
      ),
    );
  }

  // ============================================
  // ERROR STATE
  // ============================================
  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, size: 40, color: Colors.red),
          const SizedBox(height: 10),
          const Text("Failed to load logs"),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _refresh,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
