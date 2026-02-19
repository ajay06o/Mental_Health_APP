import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

              // TODO: Call delete API
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
