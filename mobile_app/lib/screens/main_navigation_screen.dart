import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const String _tabKey = "last_tab_index";

  int _currentIndex = 0;
  bool _isRestoring = true;

  final PageStorageBucket _bucket = PageStorageBucket();

  final List<Widget> _screens = const [
    HomeScreen(key: PageStorageKey("home_scroll")),
    HistoryScreen(key: PageStorageKey("history_scroll")),
    InsightsScreen(key: PageStorageKey("insights_scroll")),
    ProfileScreen(key: PageStorageKey("profile_scroll")),
  ];

  @override
  void initState() {
    super.initState();
    _restoreLastTab();
  }

  // ==============================
  // RESTORE TAB INDEX
  // ==============================
  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_tabKey);

    await Future.delayed(const Duration(milliseconds: 150));

    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < _screens.length) {
      setState(() {
        _currentIndex = savedIndex;
      });
    }

    setState(() => _isRestoring = false);
  }

  // ==============================
  // SAVE TAB INDEX
  // ==============================
  Future<void> _saveLastTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tabKey, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isRestoring
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  key: ValueKey<int>(_currentIndex),
                  index: _currentIndex,
                  children: _screens,
                ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == _currentIndex) return;

          setState(() => _currentIndex = index);
          _saveLastTab(index);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded), label: "History"),
          BottomNavigationBarItem(
              icon: Icon(Icons.insights_rounded), label: "Insights"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }
}
