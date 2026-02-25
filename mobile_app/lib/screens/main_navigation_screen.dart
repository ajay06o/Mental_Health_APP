import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

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

  int _currentIndex = 0; // ✅ Always start on Home

  final PageStorageBucket _bucket = PageStorageBucket();

  final List<Widget> _screens = const [
    HomeScreen(key: PageStorageKey("home_scroll")),
    HistoryScreen(key: PageStorageKey("history_scroll")),
    InsightsScreen(key: PageStorageKey("insights_scroll")),
    ProfileScreen(key: PageStorageKey("profile_scroll")),
  ];

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
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
          child: IndexedStack(
            key: ValueKey<int>(_currentIndex),
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ),

      // 🔥 Modern Bottom Navigation
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  // 🔥 Glass Background
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),

                  // 🔥 Sliding Active Indicator
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(
                      -1 + (_currentIndex * 0.66),
                      0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Container(
                        width:
                            MediaQuery.of(context).size.width / 4 - 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.withOpacity(0.9),
                              Colors.blueAccent.withOpacity(0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 🔥 Navigation Items
                  Row(
                    children: List.generate(4, (index) {
                      final icons = [
                        Icons.home_rounded,
                        Icons.history_rounded,
                        Icons.insights_rounded,
                        Icons.person_rounded,
                      ];

                      final labels = [
                        "Home",
                        "History",
                        "Insights",
                        "Profile",
                      ];

                      final isActive = _currentIndex == index;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onTabSelected(index),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                duration: const Duration(
                                    milliseconds: 250),
                                curve: Curves.easeOut,
                                scale: isActive ? 1.2 : 1.0,
                                child: Icon(
                                  icons[index],
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedOpacity(
                                duration: const Duration(
                                    milliseconds: 200),
                                opacity: isActive ? 1 : 0.7,
                                child: Text(
                                  labels[index],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}