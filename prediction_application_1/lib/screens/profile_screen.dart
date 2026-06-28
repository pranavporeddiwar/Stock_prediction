import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _capitalController = TextEditingController();

  // Dropdown values
  String _experience = 'Beginner';
  String _riskAppetite = 'Moderate';
  String _preferredSegment = 'Equity';
  String _tradingStyle = 'Intraday';

  // Options
  static const List<String> _experienceOptions = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
  static const List<String> _riskOptions = ['Conservative', 'Moderate', 'Aggressive'];
  static const List<String> _segmentOptions = ['Equity', 'F&O', 'Commodities', 'Crypto', 'All'];
  static const List<String> _styleOptions = ['Intraday', 'Swing', 'Positional', 'Long-term'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _capitalController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUserUid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        _nameController.text = d['name'] ?? '';
        _phoneController.text = d['phone'] ?? '';
        _capitalController.text = d['dailyCapital']?.toString() ?? '';
        _experience = d['experience'] ?? 'Beginner';
        _riskAppetite = d['riskAppetite'] ?? 'Moderate';
        _preferredSegment = d['preferredSegment'] ?? 'Equity';
        _tradingStyle = d['tradingStyle'] ?? 'Intraday';
      }
    } catch (e) {
      debugPrint("Profile load error: $e");
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        // If name is empty, auto-enter edit mode so user fills the profile
        if (_nameController.text.isEmpty) _isEditing = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _auth.currentUserUid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dailyCapital': double.tryParse(_capitalController.text.trim()) ?? 0,
        'experience': _experience,
        'riskAppetite': _riskAppetite,
        'preferredSegment': _preferredSegment,
        'tradingStyle': _tradingStyle,
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile saved successfully"),
            backgroundColor: Color(0xFF00FFA3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF0F111A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Change Password", style: TextStyle(color: Colors.white)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPassController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    decoration: InputDecoration(
                      hintText: "Current Password",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: newPassController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                    decoration: InputDecoration(
                      hintText: "New Password",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9D4EDD)),
                onPressed: isSaving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => isSaving = true);
                  try {
                    await _auth.changePassword(currentPassController.text, newPassController.text);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated"), backgroundColor: Color(0xFF00FFA3)));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
                    }
                  }
                },
                child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Update", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF0F111A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("This action cannot be undone. All your data will be permanently deleted. Enter your password to confirm.", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: isDeleting ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => isDeleting = true);
                  try {
                    await _auth.deleteAccount(passController.text);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      // User is deleted, auth stream will redirect to login
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setDialogState(() => isDeleting = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
                    }
                  }
                },
                child: isDeleting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Delete", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to sign out?", style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _auth.signOut();
            },
            child: const Text("Sign Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF9D4EDD))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "PROFILE",
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF9D4EDD), size: 20),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildAvatar(email),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 30),

              // Section: Personal Info
              _buildSectionLabel("PERSONAL INFORMATION"),
              const SizedBox(height: 12),
              _buildTextField(_nameController, "Full Name", Icons.person_outline, required: true),
              const SizedBox(height: 14),
              _buildTextField(_phoneController, "Phone Number", Icons.phone_outlined, keyboard: TextInputType.phone),
              const SizedBox(height: 28),

              // Section: Trading Profile
              _buildSectionLabel("TRADING PROFILE"),
              const SizedBox(height: 12),
              _buildDropdown("Experience Level", _experience, _experienceOptions, (v) => setState(() => _experience = v!)),
              const SizedBox(height: 14),
              _buildDropdown("Risk Appetite", _riskAppetite, _riskOptions, (v) => setState(() => _riskAppetite = v!)),
              const SizedBox(height: 14),
              _buildDropdown("Preferred Segment", _preferredSegment, _segmentOptions, (v) => setState(() => _preferredSegment = v!)),
              const SizedBox(height: 14),
              _buildDropdown("Trading Style", _tradingStyle, _styleOptions, (v) => setState(() => _tradingStyle = v!)),
              const SizedBox(height: 14),
              _buildTextField(_capitalController, "Daily Capital (₹)", Icons.account_balance_wallet_outlined, keyboard: TextInputType.number),
              const SizedBox(height: 30),

              // Save Button (only in edit mode)
              if (_isEditing) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("SAVE PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _loadProfile(); // reload original data
                    setState(() => _isEditing = false);
                  },
                  child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
                ),
              ],

              const SizedBox(height: 20),

              // Account Security Section
              _buildSectionLabel("ACCOUNT SECURITY"),
              const SizedBox(height: 12),
              _buildSecurityAction(
                title: "Change Password",
                icon: Icons.lock_outline,
                color: Colors.white,
                onTap: _showChangePasswordDialog,
              ),
              const SizedBox(height: 10),
              _buildSecurityAction(
                title: "Sign Out",
                icon: Icons.logout,
                color: Colors.white,
                onTap: _confirmSignOut,
              ),
              const SizedBox(height: 10),
              _buildSecurityAction(
                title: "Delete Account",
                icon: Icons.delete_outline,
                color: Colors.redAccent,
                onTap: _showDeleteAccountDialog,
              ),
              const SizedBox(height: 100), // bottom padding for nav bar
            ],
          ),
        ),
      ),
    );
  }

  // ──────────── UI BUILDING BLOCKS ────────────

  Widget _buildAvatar(String email) {
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.3), blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF9D4EDD), size: 20),
        filled: true,
        fillColor: const Color(0xFF0F111A),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(_isEditing ? 0.08 : 0.05)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: _isEditing ? onChanged : null,
        dropdownColor: const Color(0xFF0F111A),
        style: const TextStyle(color: Colors.white),
        icon: Icon(Icons.expand_more, color: _isEditing ? const Color(0xFF9D4EDD) : Colors.white24, size: 20),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }

  Widget _buildSecurityAction({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
