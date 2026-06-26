import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  bool isLogin = true;
  bool isLoading = false;

  void _authenticate() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) return;
    
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await _auth.signIn(_emailController.text, _passController.text);
      } else {
        await _auth.signUp(_emailController.text, _passController.text);
      }
      // If successful, the authStateChanges stream in main.dart will automatically route us!
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF9D4EDD), size: 60),
              const SizedBox(height: 20),
              const Text("NEURAL STREAM", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 10),
              Text(isLogin ? "Initialize Terminal" : "Register New Node", style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.5)),
              
              const SizedBox(height: 50),
              
              _buildTextField(_emailController, "Identity (Email)", Icons.email_outlined, false),
              const SizedBox(height: 20),
              _buildTextField(_passController, "Encryption Key (Password)", Icons.lock_outline, true),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isLoading ? null : _authenticate,
                  child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isLogin ? "ESTABLISH UPLINK" : "CREATE NODE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
              
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? "No access? Request a Node here." : "Existing Node? Establish Uplink.", style: const TextStyle(color: Color(0xFF9D4EDD))),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: const Color(0xFF9D4EDD)),
        filled: true,
        fillColor: const Color(0xFF0F111A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}