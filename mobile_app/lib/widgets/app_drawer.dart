import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: Text(
              "Mental Health App",
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Home"),
            onTap: () => Navigator.pushReplacementNamed(context, "/home"),
          ),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("History"),
            onTap: () => Navigator.pushNamed(context, "/history"),
          ),

          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text("Insights"),
            onTap: () => Navigator.pushNamed(context, "/insights"),
          ),

          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            onTap: () => Navigator.pushNamed(context, "/profile"),
          ),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () => Navigator.pushNamed(context, "/settings"),
          ),
        ],
      ),
    );
  }
}
