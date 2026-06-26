import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // 📦 Injected State Manager
import 'firebase_options.dart';
import 'screens/main_wrapper.dart'; 
import 'services/portfolio_service.dart'; // 📈 Injected Live Portfolio Engine

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
  
  // 3. Mount the Global State Providers before booting the UI layer
  runApp(
    MultiProvider(
      providers: [
        // This spins up the active memory and socket engine the moment the app boots
        ChangeNotifierProvider(create: (_) => PortfolioService()),
      ],
      child: const MyApp(),
    ),
  );
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
      
      // Your terminal boots lightning fast straight into the master screen navigation matrix.
      home: const MainWrapper(), 
    );
  }
}