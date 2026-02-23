import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/predict_service.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
    

  late Future<Map<String, dynamic>> _profileFuture;

  // Existing animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // NEW animations for smooth update
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;

  bool _isRefreshing = false;

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

    // Avatar pop animation
    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _avatarScale = Tween<double>(
      begin: 1,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _avatarController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  // Smooth refresh
  Future<void> _refreshProfile() async {
    setState(() => _isRefreshing = true);

    await Future.delayed(const Duration(milliseconds: 250));

    setState(() {
      _profileFuture = PredictService.fetchProfile();
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  // ================= IMAGE PICKER =================

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    try {
      if (kIsWeb) {
        await PredictService.uploadProfileImage(pickedFile);
      } else {
        await PredictService.uploadProfileImage(
          File(pickedFile.path),
        );
      }

      await _refreshProfile();

      // Avatar pop
      _avatarController.forward().then((_) {
        _avatarController.reverse();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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

              final name = data["name"] ?? "";
              final email = data["email"] ?? "Unknown";
              final displayName =
                  (name.toString().trim().isNotEmpty)
                      ? name
                      : email;

              final totalEntries =
                  data["total_entries"] ?? 0;
              final avgSeverity =
                  (data["avg_severity"] ?? 0).toDouble();
              final highRisk =
                  data["high_risk"] == true;

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _isRefreshing ? 0.5 : 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [

                      _animatedProfileHeader(displayName, data),

                      const SizedBox(height: 40),

                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "Entries",
                              totalEntries.toString(),
                              Icons.edit_note,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _statCard(
                              "Avg Score",
                              avgSeverity.toStringAsFixed(1),
                              Icons.analytics,
                            ),
                          ),
                        ],
                      ),

                      if (highRisk) _warningCard(),

                      const SizedBox(height: 40),

                      _sectionTitle("Account"),
                      const SizedBox(height: 16),

                      _settingsTile(
                        icon: Icons.settings,
                        title: "Settings",
                        onTap: () => context.go("/settings"),
                      ),

                      _settingsTile(
                        icon: Icons.edit,
                        title: "Edit Profile",
                        onTap: () async {
                          final data = await _profileFuture;
                          if (!mounted) return;
                          _openEditProfileSheet(data);
                        },
                      ),

                      const SizedBox(height: 40),

                      _logoutButton(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _animatedProfileHeader(
      String displayText,
      Map<String, dynamic> data) {

    final profileImage = data["profile_image"];

    final imageUrl =
        (profileImage != null &&
                profileImage.toString().isNotEmpty)
            ? "${ApiClient.baseUrl}$profileImage"
            : null;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            children: [

              ScaleTransition(
                scale: _avatarScale,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 62,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        imageUrl != null
                            ? NetworkImage(imageUrl)
                            : null,
                    child: imageUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.deepPurple,
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Smooth name change
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  displayText,
                  key: ValueKey(displayText),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "Emotional Wellness Journey",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= STAT CARD =================

  Widget _statCard(
      String title,
      String value,
      IconData icon) {

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 12),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade400,
            Colors.red.shade600,
          ],
        ),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "High emotional risk detected.\nPlease reach out for support.",
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight:
            FontWeight.bold,
        color: Colors.white,
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
      leading:
          Icon(icon, color: Colors.white),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white)),
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
          padding:
              const EdgeInsets.symmetric(
                  vertical: 14),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title:
                  const Text("Confirm Logout"),
              content: const Text(
                  "Are you sure you want to logout?"),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child:
                      const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmLogout();
                  },
                  child: const Text(
                    "Logout",
                    style: TextStyle(
                        color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        child: const Text(
          "Logout",
          style:
              TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final prefs =
        await SharedPreferences.getInstance();
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
