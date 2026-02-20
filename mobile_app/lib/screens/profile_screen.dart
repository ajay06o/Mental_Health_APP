import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/predict_service.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>>
      _profileFuture;

  late AnimationController _controller;
  late Animation<double> _fade;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profileFuture =
        PredictService.fetchProfile();

    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 400),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture =
          PredictService.fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go("/settings"),
          ),
        ],
      ),
      body: FutureBuilder<
          Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                textAlign:
                    TextAlign.center,
              ),
            );
          }

          final data =
              snapshot.data ?? {};

          _controller.forward();

          final email =
              data["email"] ?? "Unknown";
          final totalEntries =
              data["total_entries"] ?? 0;
          final avgSeverity =
              (data["avg_severity"] ?? 0)
                  .toDouble();
          final highRisk =
              data["high_risk"] == true;

          final emergencyEmail =
              data["emergency_email"] ??
                  "Not Set";
          final emergencyName =
              data["emergency_name"] ??
                  "Not Set";
          final alertsEnabled =
              data["alerts_enabled"] ??
                  true;

          return FadeTransition(
            opacity: _fade,
            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                children: [
                  _profileHeader(email),
                  const SizedBox(height: 20),
                  _statCard(
                      "Total Entries",
                      totalEntries
                          .toString(),
                      Icons.list_alt),
                  _statCard(
                      "Avg Severity",
                      avgSeverity
                          .toStringAsFixed(
                              1),
                      Icons
                          .analytics_outlined),
                  const SizedBox(height: 20),
                  _emergencyCard(
                      emergencyName,
                      emergencyEmail,
                      alertsEnabled),
                  if (highRisk)
                    _alertCard(),
                  const SizedBox(height: 30),
                  _logoutButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =============================
  // HEADER
  // =============================
  Widget _profileHeader(String email) {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor:
                Colors.white,
            child: Icon(Icons.person,
                size: 32,
                color: Colors
                    .deepPurple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              email,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
                Icons.edit,
                color:
                    Colors.white),
            onPressed: () async {
              final data =
                  await _profileFuture;
              if (!mounted) return;
              _openEditProfileSheet(
                  data);
            },
          )
        ],
      ),
    );
  }

  // =============================
  // STAT CARD
  // =============================
  Widget _statCard(
      String title,
      String value,
      IconData icon) {
    return Card(
      margin: const EdgeInsets.only(
          bottom: 12),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon,
            color:
                Colors.deepPurple),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
              fontWeight:
                  FontWeight.bold),
        ),
      ),
    );
  }

  // =============================
  // EMERGENCY CARD
  // =============================
  Widget _emergencyCard(
      String name,
      String email,
      bool enabled) {
    return Card(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      color:
          Colors.orange.withOpacity(
              0.08),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "🚨 Emergency Contact",
              style: TextStyle(
                  fontWeight:
                      FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Name: $name"),
            Text("Email: $email"),
            const SizedBox(height: 6),
            Text(
              enabled
                  ? "Alerts Enabled"
                  : "Alerts Disabled",
              style: TextStyle(
                color: enabled
                    ? Colors.green
                    : Colors.red,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // ALERT
  // =============================
  Widget _alertCard() {
    return Card(
      margin:
          const EdgeInsets.only(
              top: 14),
      color:
          Colors.red.withOpacity(
              0.1),
      child: const Padding(
        padding:
            EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning,
                color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "High risk patterns detected. Please consider professional support.",
                style: TextStyle(
                    fontWeight:
                        FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // LOGOUT
  // =============================
  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon:
            const Icon(Icons.logout),
        label:
            const Text("Logout"),
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              Colors.red,
        ),
        onPressed:
            _confirmLogout,
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
        title: const Text(
            "Confirm Logout"),
        content: const Text(
            "Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
                    context,
                    false),
            child:
                const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(
                    context,
                    true),
            child:
                const Text("Logout"),
          ),
        ],
      ),
    );

    if (result == true &&
        mounted) {
      final prefs =
          await SharedPreferences
              .getInstance();
      await prefs.remove(
          "last_tab_index");

      await AuthService.logout();

      context.go("/login");
    }
  }

  // =============================
  // EDIT PROFILE SHEET
  // =============================
  void _openEditProfileSheet(
      Map<String, dynamic> data) {
    final emailController =
        TextEditingController(
            text: data["email"] ??
                "");

    final passwordController =
        TextEditingController();

    final emergencyNameController =
        TextEditingController(
            text: data[
                    "emergency_name"] ??
                "");

    final emergencyEmailController =
        TextEditingController(
            text: data[
                    "emergency_email"] ??
                "");

    bool alertsEnabled =
        data["alerts_enabled"] ??
            true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context,
              setModalState) {
            return Padding(
              padding:
                  EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom:
                    MediaQuery.of(
                                context)
                            .viewInsets
                            .bottom +
                        20,
              ),
              child:
                  SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      "Edit Profile",
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(
                        height: 16),
                    TextField(
                      controller:
                          emailController,
                      decoration:
                          const InputDecoration(
                              labelText:
                                  "Email"),
                    ),
                    const SizedBox(
                        height: 12),
                    TextField(
                      controller:
                          passwordController,
                      obscureText:
                          true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "New Password (optional)",
                      ),
                    ),
                    const SizedBox(
                        height: 12),
                    TextField(
                      controller:
                          emergencyNameController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Emergency Contact Name",
                      ),
                    ),
                    const SizedBox(
                        height: 12),
                    TextField(
                      controller:
                          emergencyEmailController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Emergency Contact Email",
                      ),
                    ),
                    const SizedBox(
                        height: 12),
                    SwitchListTile(
                      title: const Text(
                          "Enable Crisis Alerts"),
                      value:
                          alertsEnabled,
                      onChanged:
                          (value) {
                        setModalState(() =>
                            alertsEnabled =
                                value);
                      },
                    ),
                    const SizedBox(
                        height: 20),
                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          ElevatedButton(
                        onPressed:
                            _saving
                                ? null
                                : () async {
                                    setState(() =>
                                        _saving =
                                            true);

                                    try {
                                      await PredictService
                                          .updateProfile(
                                        email:
                                            emailController
                                                .text
                                                .trim(),
                                        password: passwordController
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : passwordController
                                                .text
                                                .trim(),
                                        emergencyName:
                                            emergencyNameController
                                                .text
                                                .trim(),
                                        emergencyEmail:
                                            emergencyEmailController
                                                .text
                                                .trim(),
                                        alertsEnabled:
                                            alertsEnabled,
                                      );

                                      if (!mounted)
                                        return;

                                      Navigator.pop(
                                          context);

                                      _refreshProfile();

                                      ScaffoldMessenger.of(
                                              context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Profile updated successfully")),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                              context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                e.toString())),
                                      );
                                    } finally {
                                      setState(() =>
                                          _saving =
                                              false);
                                    }
                                  },
                        child: _saving
                            ? const CircularProgressIndicator(
                                color:
                                    Colors
                                        .white,
                              )
                            : const Text(
                                "Save Changes"),
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
