import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Listen to whether the user is logged in or out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  String? get currentUserUid => _auth.currentUser?.uid;
  User? get currentUser => _auth.currentUser;

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
      return result.user;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
      return result.user;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) throw Exception("No user signed in");

      // Re-authenticate first (Firebase requires this for sensitive operations)
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);

      // Now update
      await user.updatePassword(newPassword);
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) throw Exception("No user signed in");

      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      await user.delete();
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Converts Firebase error codes to user-friendly messages
  String _friendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Try again.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'No internet connection. Check your network.';
        case 'requires-recent-login':
          return 'Please sign out and sign back in before retrying.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    return e.toString().replaceAll('Exception: ', '');
  }
}