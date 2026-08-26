import 'package:flutter/material.dart';
import '../services/api_service.dart';

const primaryColor = Color(0xFF3730A3);

class ChangePasswordScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final currentPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;

  bool loading = false;
  String? errorMessage;
  String? successMessage;

  Future<void> handleChangePassword() async {
    final currentPass = currentPasswordCtrl.text.trim();
    final newPass = newPasswordCtrl.text.trim();
    final confirmPass = confirmPasswordCtrl.text.trim();

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() {
        errorMessage = "Please fill in all fields.";
        successMessage = null;
      });
      return;
    }

    if (newPass.length < 6) {
      setState(() {
        errorMessage = "New password must be at least 6 characters.";
        successMessage = null;
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        errorMessage = "New passwords do not match.";
        successMessage = null;
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
      successMessage = null;
    });

    final sId = widget.user['id'] is int
        ? widget.user['id'] as int
        : int.tryParse(widget.user['id']?.toString() ?? '1') ?? 1;

    final res = await ApiService.changeStudentPassword(sId, currentPass, newPass);

    setState(() => loading = false);

    if (res['success'] == true) {
      setState(() {
        successMessage = "Password updated successfully! ✅";
        currentPasswordCtrl.clear();
        newPasswordCtrl.clear();
        confirmPasswordCtrl.clear();
      });
    } else {
      setState(() {
        errorMessage = res['message'] ?? "Failed to update password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ),

            if (successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  successMessage!,
                  style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                ),
              ),

            _passwordField(
              label: "Current Password",
              controller: currentPasswordCtrl,
              obscure: !showCurrent,
              onToggle: () => setState(() => showCurrent = !showCurrent),
            ),
            const SizedBox(height: 16),

            _passwordField(
              label: "New Password",
              controller: newPasswordCtrl,
              obscure: !showNew,
              onToggle: () => setState(() => showNew = !showNew),
            ),
            const SizedBox(height: 16),

            _passwordField(
              label: "Confirm New Password",
              controller: confirmPasswordCtrl,
              obscure: !showConfirm,
              onToggle: () => setState(() => showConfirm = !showConfirm),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "Update Password",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: onToggle,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
