import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'watchlist_screen.dart';
import 'home_screen.dart'; // Target search screen layout
import 'journal_screen.dart'; // Target portfolio data layers

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const WatchlistScreen(),
    const HomeScreen(),
    const JournalScreen(),
    const Center(child: Text("User Profile Data", style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true, // Crucial: Extends the canvas area cleanly beneath the curved bar boundaries
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // THE CENTRAL GLOWING ACTION BUTTON (As seen in image_6cf2c1.png)
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9D4EDD).withOpacity(0.4), // Premium electric glow border
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF7B2CBF), // Pure electric neon purple fill
          shape: const CircleBorder(),
          onPressed: () {
            // Option A: Trigger your Neural Tutor overlay window
            // Option B: Push straight to an Assistant specific view state
            print("Neural Assistant Activated");
          },
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),

      // Center mount positioning rules
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Mount your updated curved custom panel
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}