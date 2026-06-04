import 'package:flutter/material.dart';
import 'watchlist_screen.dart';
import 'history_screen.dart'; // Ensure this is created

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  // The core screens of your Neural Stream app
  final List<Widget> _screens = [
    const WatchlistScreen(),
    const Center(child: Text("AI Scanner - Coming Soon", style: TextStyle(color: Colors.white24))),
    const HistoryScreen(), // Replaced Wallet with History
    const Center(child: Text("Profile - Coming Soon", style: TextStyle(color: Colors.white24))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFF00FFA3),
          unselectedItemColor: Colors.white24,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded, size: 20),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined, size: 20),
              label: 'Scanner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_toggle_off_rounded, size: 20), // History Icon
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_2_outlined, size: 20),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}