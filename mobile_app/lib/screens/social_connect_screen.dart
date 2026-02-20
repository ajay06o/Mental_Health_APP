import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/social_service.dart';
import '../services/oauth_listener_service.dart';
import 'sync_logs_screen.dart';

class SocialConnectScreen extends StatefulWidget {
  const SocialConnectScreen({super.key});

  @override
  State<SocialConnectScreen> createState() =>
      _SocialConnectScreenState();
}

class _SocialConnectScreenState extends State<SocialConnectScreen> {
  late Future<Map<String, bool>> _connectionsFuture;

  final Set<String> _loadingPlatforms = {};
  final Map<String, DateTime?> _lastSync = {};
  final Map<String, String?> _syncError = {};

  @override
  void initState() {
    super.initState();
    _connectionsFuture = SocialService.getConnections();
    _loadPreferences();

    // ✅ FIXED: Provide BOTH success and error callbacks
    OAuthListenerService.startListening(
      (platform) {
        _handleOAuthSuccess(platform);
      },
      (platform, error) {
        _showError(platform, error ?? "OAuth failed");
        setState(() => _loadingPlatforms.remove(platform));
      },
    );
  }

  @override
  void dispose() {
    OAuthListenerService.dispose();
    super.dispose();
  }

  // ==============================
  // LOAD STORED DATA
  // ==============================
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    for (final p in ["instagram", "twitter", "facebook", "linkedin"]) {
      final ts = prefs.getString("${p}_last_sync");
      _lastSync[p] = ts != null ? DateTime.tryParse(ts) : null;
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveLastSync(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString("${platform}_last_sync", now.toIso8601String());
    _lastSync[platform] = now;
  }

  // ==============================
  // OAUTH FLOW
  // ==============================
  Future<void> _connectPlatform(String platform) async {
    HapticFeedback.mediumImpact();

    setState(() => _loadingPlatforms.add(platform));

    try {
      final url = await SocialService.getOAuthUrl(platform);

      final uri = Uri.parse(url);

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception("Could not launch OAuth URL");
      }
    } catch (e) {
      _showError(platform, e.toString());
      setState(() => _loadingPlatforms.remove(platform));
    }
  }

  Future<void> _handleOAuthSuccess(String platform) async {
    if (!mounted) return;

    await _showSuccessAnimation();

    if (!mounted) return;

    await _showSyncProgress(platform);

    if (!mounted) return;

    await _saveLastSync(platform);

    _refresh();

    if (mounted) {
      setState(() => _loadingPlatforms.remove(platform));
    }
  }

  // ==============================
  // ERROR UI
  // ==============================
  void _showError(String platform, String message) {
    setState(() => _syncError[platform] = message);
  }

  Future<void> _retrySync(String platform) async {
    setState(() => _syncError[platform] = null);

    try {
      await SocialService.retrySync(platform);
      await _showSyncProgress(platform);
      await _saveLastSync(platform);
    } catch (e) {
      _showError(platform, e.toString());
    }
  }

  // ==============================
  // SYNC PROGRESS
  // ==============================
  Future<void> _showSyncProgress(String platform) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SyncDialog(platform: platform),
    );
  }

  void _refresh() {
    setState(() {
      _connectionsFuture = SocialService.getConnections();
    });
  }

  // ==============================
  // UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Social Connections"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SyncLogsScreen(),
                ),
              );
            },
          )
        ],
      ),
      body: FutureBuilder<Map<String, bool>>(
        future: _connectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...["instagram", "twitter", "facebook", "linkedin"]
                  .map((p) => _platformCard(p, data[p] == true)),
            ],
          );
        },
      ),
    );
  }

  Widget _platformCard(String platform, bool connected) {
    final loading = _loadingPlatforms.contains(platform);
    final error = _syncError[platform];
    final lastSync = _lastSync[platform];

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(platform.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  ElevatedButton(
                    onPressed: connected
                        ? null
                        : () => _connectPlatform(platform),
                    child:
                        Text(connected ? "Connected" : "Connect"),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lastSync != null
                  ? "Last Sync: $lastSync"
                  : "Never synced",
              style: const TextStyle(fontSize: 12),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text("Error: $error",
                  style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: () => _retrySync(platform),
                child: const Text("Retry"),
              )
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _showSuccessAnimation() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                "assets/lottie/success.json",
                height: 120,
              ),
              const SizedBox(height: 12),
              const Text(
                "Connection Successful!",
                style:
                    TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    if (mounted) Navigator.pop(context);
  }
}

// =================================
// SYNC DIALOG WITH POLLING
// =================================
class _SyncDialog extends StatefulWidget {
  final String platform;

  const _SyncDialog({required this.platform});

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  int analyzed = 0;
  int total = 1;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    try {
      final status =
          await SocialService.getSyncStatus(widget.platform);

      if (!mounted) return;

      setState(() {
        analyzed = status["analyzed"] ?? 0;
        total = status["total"] ?? 1;
      });

      if (analyzed < total) {
        Future.delayed(const Duration(seconds: 2), _poll);
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = analyzed / total;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Syncing Posts..."),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text("$analyzed / $total posts analyzed"),
          ],
        ),
      ),
    );
  }
}
