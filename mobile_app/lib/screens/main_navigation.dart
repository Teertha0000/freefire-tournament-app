import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/custom_curved_navbar.dart';
import 'home_screen.dart';
import 'my_matches_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MyMatchesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Crucial for 0 spacing under the navbar and letting body go behind
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomCurvedNavBar(
        items: const [
          Icons.home_filled,
          Icons.sports_esports_rounded,
          Icons.person,
        ],
        selectedIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.surfaceGrey.withOpacity(0.95),
        activeColor: AppTheme.primaryCyan,
        inactiveColor: Colors.white,
      ),
    );
  }
}
