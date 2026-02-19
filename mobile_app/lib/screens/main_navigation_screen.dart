import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
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
  // RESTORE TAB
  // ==============================
  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_tabKey);

    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < _screens.length) {
      if (!mounted) return;
      _currentIndex = savedIndex;
    }

    if (!mounted) return;
    setState(() => _isRestoring = false);
  }

  // ==============================
  // SAVE TAB
  // ==============================
  Future<void> _saveLastTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tabKey, index);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.lightImpact();

    setState(() => _currentIndex = index);
    _saveLastTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _isRestoring
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  key: ValueKey<int>(_currentIndex),
                  index: _currentIndex,
                  children: _screens,
                ),
        ),
      ),

      // 🔥 Modern Bottom Navigation
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 10,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold),
          onTap: _onTabSelected,
          items: [
            _navItem(Icons.home_rounded, "Home", 0),
            _navItem(Icons.history_rounded, "History", 1),
            _navItem(Icons.insights_rounded, "Insights", 2),
            _navItem(Icons.person_rounded, "Profile", 3),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(
      IconData icon, String label, int index) {
    final isActive = _currentIndex == index;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(6),
        decoration: isActive
            ? BoxDecoration(
                color: Colors.indigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Icon(icon),
      ),
      label: label,
    );
  }
}
