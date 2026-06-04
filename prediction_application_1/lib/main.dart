import 'package:flutter/material.dart';
import 'widgets/global_chat_bot.dart'; // Import the new widget
import 'screens/watchlist_screen.dart'; // Your main screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neural Stream Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      // --- THE MAGIC LINE ---
      // This forces the GlobalChatBot to float above every single screen in the app
      builder: (context, child) {
        return GlobalChatBot(child: child!);
      },
      home: const WatchlistScreen(), 
    );
  }
}