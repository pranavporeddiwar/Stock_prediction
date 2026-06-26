import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Listen to whether the user is logged in or out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user ID
  String? get currentUserUid => _auth.currentUser?.uid;

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
      return result.user;
    } catch (e) {
      throw Exception("Login Failed: ${e.toString().split(']').last.trim()}");
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
      return result.user;
    } catch (e) {
      throw Exception("Registration Failed: ${e.toString().split(']').last.trim()}");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}