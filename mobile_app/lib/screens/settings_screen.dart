import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import 'package:go_router/go_router.dart';
import 'audit_logs_screen.dart';
import 'upload_content_screen.dart';
import 'my_uploads_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;
  bool isBiometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // 🔹 Appearance Section
          _buildSectionTitle("Appearance"),
          _buildCard(
            child: SwitchListTile(
              title: const Text("Dark Mode"),
              subtitle: const Text("Enable dark theme"),
              value: isDarkMode,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() {
                  isDarkMode = val;
                });

                // TODO: Connect with ThemeProvider
              },
            ),
          ),

          // 🔹 Data & Consent Section
          _buildSectionTitle("Data & Consent"),
          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.blue),
              title: const Text("Consent & Data"),
              subtitle: const Text("View consent and manage uploaded data"),
              trailing: const Icon(Icons.info_outline, size: 16),
              onTap: () async {
                HapticFeedback.lightImpact();
                await _showConsentDialog();
              },
            ),
          ),

          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.blue),
              title: const Text('Audit Logs'),
              subtitle: const Text('View consent and deletion history'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
                );
              },
            ),
          ),

          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.green),
              title: const Text('Upload Content'),
              subtitle: const Text('Upload posts, captions or screenshots'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UploadContentScreen()),
                );
              },
            ),
          ),

          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.list, color: Colors.green),
              title: const Text('My Uploads'),
              subtitle: const Text('View your uploaded items'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyUploadsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Security Section
          _buildSectionTitle("Security"),
          _buildCard(
            child: SwitchListTile(
              title: const Text("Biometric Login"),
              subtitle: const Text("Use fingerprint or Face ID"),
              value: isBiometricEnabled,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() {
                  isBiometricEnabled = val;
                });

                // TODO: Integrate local_auth package
              },
            ),
          ),

          const SizedBox(height: 20),

          const SizedBox(height: 20),

          // 🔹 Account Section
          _buildSectionTitle("Account"),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: const Text("Logout"),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showLogoutDialog();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text("Delete Account"),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    _showDeleteDialog();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 About Section
          _buildSectionTitle("About"),
          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.blue),
              title: const Text("Privacy Policy"),
              onTap: () {
                // TODO: Open Privacy Policy URL
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              // TODO: Clear tokens
              // TODO: Navigate to Login screen
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Delete Account"),
        content: const Text(
          "This action is permanent and cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);

                // Call delete-my-data API
                _deleteMyData();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _showConsentDialog() async {
    try {
      final res = await ApiClient.getPublic('/social/consent');
      final consent = res['consent'] as String? ?? 'Consent text not available.';

      final accepted = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Consent and Disclaimer'),
          content: SingleChildScrollView(child: Text(consent)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Accept')),
          ],
        ),
      );

      if (accepted == true) {
        await ApiClient.post('/social/consent', {'accepted': true});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consent accepted')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _deleteMyData() async {
    try {
      // call server deletion
      await ApiClient.post('/social/delete-data', {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your uploaded data was deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete data: ${e.toString()}')));
    }
  }
}
