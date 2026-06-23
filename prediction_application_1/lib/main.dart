import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_wrapper.dart'; 

void main() async {
  // 1. Ensures the native Flutter engine framework is initialized before asynchronous bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Starts up the Firebase project layer natively on your device
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("☁️ Firebase Cloud Framework Initialized Safely inside Mobile Core.");
  } catch (e) {
    print("⚠️ Firebase Root Init Warning: Check your local google-services configuration. Details: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neural Stream Terminal',
      debugShowCheckedModeBanner: false,
      
      // Applying your customized high-contrast quantitative dark theme
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      
      // 👇 FIXED: Builder section removed to decouple the layout architecture.
      // Your terminal now boots lightning fast straight into the master screen navigation matrix.
      home: const MainWrapper(), 
    );
  }
}