import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // 📦 Injected State Manager
import 'package:firebase_auth/firebase_auth.dart'; // 🔐 Injected Native Auth Engine
import 'firebase_options.dart';
import 'screens/main_wrapper.dart'; 
import 'screens/auth_screen.dart'; // 🎛️ Injected Login Portal Terminal
import 'services/portfolio_service.dart'; // 📈 Injected Live Portfolio Engine
import 'services/auth_service.dart'; // 🛡️ Injected Reactive Security Brain

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
      title: 'NEUROTICK',
      debugShowCheckedModeBanner: false,
      
      // Applying your customized high-contrast quantitative dark theme
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      
      // ⚡ THE GATEKEEPER: Listens to Firebase Auth changes reactively and routes user nodes automatically
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          // While the Firebase engine performs key decryption / token validation verification, show fallback progress indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF9D4EDD)),
              ),
            );
          }
          
          // If a secure validated user data snapshot returns from the matrix, boot directly to Main Workspace
          if (snapshot.hasData) {
            return const MainWrapper();
          } 
          
          // Otherwise, block unauthorized navigation access vectors and prompt for uplink credentials
          return const AuthScreen();
        },
      ), 
    );
  }
}