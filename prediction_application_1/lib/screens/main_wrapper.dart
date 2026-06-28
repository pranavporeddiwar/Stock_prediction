import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'watchlist_screen.dart';
import 'home_screen.dart'; 
import 'portfolio_screen.dart';
import 'profile_screen.dart';
import '../widgets/global_chat_bot.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),             // Index 0 → Home tab
    const WatchlistScreen(),        // Index 1 → Markets tab
    const PortfolioScreen(),        // Index 2 → Portfolio tab
    const ProfileScreen(),          // Index 3 → Profile tab
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
            // ⚡ Instantly slides up your existing Llama-3 interface!
            GlobalChatBot.show(context); 
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