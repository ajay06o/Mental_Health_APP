import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/predict_service.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {

  late Future<Map<String, dynamic>> _profileFuture;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _profileFuture = PredictService.fetchProfile();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = PredictService.fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6D5DF6),
              Color(0xFF5B4BE0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _profileFuture,
            builder: (context, snapshot) {

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              }

              final data = snapshot.data ?? {};

              final email = data["email"] ?? "Unknown";
              final totalEntries = data["total_entries"] ?? 0;
              final avgSeverity =
                  (data["avg_severity"] ?? 0).toDouble();
              final highRisk =
                  data["high_risk"] == true;

              final emergencyEmail =
                  data["emergency_email"] ?? "Not Set";
              final emergencyName =
                  data["emergency_name"] ?? "Not Set";
              final alertsEnabled =
                  data["alerts_enabled"] ?? true;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    _animatedProfileHeader(email),

                    const SizedBox(height: 30),

                    _sectionTitle("Your Insights"),
                    const SizedBox(height: 16),

                    _infoCard(
                      icon: Icons.edit_note,
                      title: "Total Journal Entries",
                      value: totalEntries.toString(),
                    ),

                    _infoCard(
                      icon: Icons.analytics_outlined,
                      title: "Average Emotional Score",
                      value: avgSeverity.toStringAsFixed(1),
                    ),

                    if (highRisk) _warningCard(),

                    const SizedBox(height: 30),

                    _sectionTitle("Emergency Contact"),
                    const SizedBox(height: 16),

                    _emergencyCard(
                      emergencyName,
                      emergencyEmail,
                      alertsEnabled,
                    ),

                    const SizedBox(height: 30),

                    _sectionTitle("Account"),
                    const SizedBox(height: 16),

                    _settingsTile(
                      icon: Icons.settings,
                      title: "Settings",
                      onTap: () =>
                          context.go("/settings"),
                    ),

                    _settingsTile(
                      icon: Icons.edit,
                      title: "Edit Profile",
                      onTap: () async {
                        final data =
                            await _profileFuture;
                        if (!mounted) return;
                        _openEditProfileSheet(data);
                      },
                    ),

                    const SizedBox(height: 40),

                    _logoutButton(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ================= Animated Header =================

  Widget _animatedProfileHeader(String email) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        "High risk patterns detected.",
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emergencyCard(
      String name,
      String email,
      bool enabled) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text("Name: $name",
              style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 6),
          Text("Email: $email",
              style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 6),
          Text(
            enabled ? "Alerts Enabled" : "Alerts Disabled",
            style: TextStyle(
              color: enabled ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white),
      title: Text(title,
          style: const TextStyle(color: Colors.white)),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.white70,
      ),
      onTap: onTap,
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _confirmLogout,
        child: const Text(
          "Logout",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("last_tab_index");
    await AuthService.logout();
    if (mounted) context.go("/login");
  }

  void _openEditProfileSheet(Map<String, dynamic> data) {
  final nameController =
      TextEditingController(text: data["name"] ?? "");

  final emailController =
      TextEditingController(text: data["email"] ?? "");

  final emergencyNameController =
      TextEditingController(text: data["emergency_name"] ?? "");

  final emergencyEmailController =
      TextEditingController(text: data["emergency_email"] ?? "");

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool alertsEnabled = data["alerts_enabled"] ?? true;
  bool isSaving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Edit Profile",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 👤 NAME
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      labelStyle:
                          TextStyle(color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📧 EMAIL
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: "Email",
                      labelStyle:
                          TextStyle(color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔐 PASSWORD
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: "New Password",
                      labelStyle:
                          TextStyle(color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔒 CONFIRM PASSWORD
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                      labelStyle:
                          TextStyle(color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🚨 EMERGENCY NAME
                  TextField(
                    controller: emergencyNameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: "Emergency Contact Name",
                      labelStyle:
                          TextStyle(color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🚨 EMERGENCY EMAIL
                  TextField(
                    controller: emergencyEmailController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: "Emergency Contact Email",
                      labelStyle:
                          TextStyle(color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Enable Crisis Alerts",
                      style:
                          TextStyle(color: Colors.black87),
                    ),
                    value: alertsEnabled,
                    activeColor: Colors.deepPurple,
                    onChanged: (value) {
                      setModalState(() {
                        alertsEnabled = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (passwordController.text.isNotEmpty &&
                                  passwordController.text !=
                                      confirmPasswordController
                                          .text) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Passwords do not match"),
                                  ),
                                );
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                              });

                              try {
                                await PredictService.updateProfile(
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim(),
                                  password: passwordController
                                          .text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : passwordController.text.trim(),
                                  emergencyName:
                                      emergencyNameController.text.trim(),
                                  emergencyEmail:
                                      emergencyEmailController.text.trim(),
                                  alertsEnabled: alertsEnabled,
                                );

                                if (!mounted) return;

                                Navigator.pop(context);
                                _refreshProfile();

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Profile updated successfully"),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                  ),
                                );
                              } finally {
                                setModalState(() {
                                  isSaving = false;
                                });
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
}