import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'watchlist_screen.dart';
import 'home_screen.dart'; 
import 'portfolio_screen.dart'; // 🔄 Swapped out legacy journal imports cleanly

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
    const PortfolioScreen(), // 🎯 Clean execution mounting index 2 target layout!
    const Center(child: Text("User Profile Data", style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true, 
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9D4EDD).withOpacity(0.4), 
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF7B2CBF), 
          shape: const CircleBorder(),
          onPressed: () {
            print("Neural Assistant Activated");
          },
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

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