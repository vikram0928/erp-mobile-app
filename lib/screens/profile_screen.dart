import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

const primaryColor = Color(0xFF1D63D1);

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController designationCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController contactCtrl;

  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool savingProfile = false;
  bool savingPassword = false;
  bool uploadingPhoto = false;
  String? profileMessage;
  String? passwordMessage;
  bool profileSuccess = false;
  bool passwordSuccess = false;

  String? photoUrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.user['name'] ?? "");
    designationCtrl = TextEditingController(text: widget.user['designation'] ?? "");
    emailCtrl = TextEditingController(text: widget.user['email'] ?? "");
    contactCtrl = TextEditingController(text: widget.user['contact_no'] ?? "");
    photoUrl = ApiService.fixPhotoUrl(widget.user['profile_photo_url']);
  }

  Future<void> pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (picked == null) return;

    setState(() => uploadingPhoto = true);

    final result = await ApiService.uploadFacultyPhoto(
      widget.user['id'],
      File(picked.path),
    );

   setState(() {
      uploadingPhoto = false;
      if (result["success"] == true) {
        // Cache-bust so the new image shows immediately instead of a cached old one
        final fixed = ApiService.fixPhotoUrl(result["photo_url"]);
        photoUrl = "$fixed?t=${DateTime.now().millisecondsSinceEpoch}";
      }
    });

    if (result["success"] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Failed to upload photo")),
      );
    }
  }

  Future<void> saveProfile() async {
    setState(() {
      savingProfile = true;
      profileMessage = null;
    });

    final deptId = widget.user['department'] != null
        ? widget.user['department']['id']
        : widget.user['dept_id'];

    final result = await ApiService.updateFacultyProfile(widget.user['id'], {
      "name": nameCtrl.text.trim(),
      "designation": designationCtrl.text.trim(),
      "email": emailCtrl.text.trim(),
      "contact_no": contactCtrl.text.trim(),
      "dept_id": deptId,
    });

    setState(() {
      savingProfile = false;
      profileSuccess = result["success"] == true;
      profileMessage = profileSuccess
          ? "Profile updated successfully."
          : (result["message"] ?? "Failed to update profile.");
    });
  }

  Future<void> savePassword() async {
    if (newPasswordCtrl.text.length < 6) {
      setState(() {
        passwordSuccess = false;
        passwordMessage = "Password must be at least 6 characters.";
      });
      return;
    }
    if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
      setState(() {
        passwordSuccess = false;
        passwordMessage = "Passwords do not match.";
      });
      return;
    }

    setState(() {
      savingPassword = true;
      passwordMessage = null;
    });

    final deptId = widget.user['department'] != null
        ? widget.user['department']['id']
        : widget.user['dept_id'];

    final result = await ApiService.updateFacultyProfile(widget.user['id'], {
      "name": nameCtrl.text.trim(),
      "designation": designationCtrl.text.trim(),
      "email": emailCtrl.text.trim(),
      "contact_no": contactCtrl.text.trim(),
      "dept_id": deptId,
      "password": newPasswordCtrl.text,
    });

    setState(() {
      savingPassword = false;
      passwordSuccess = result["success"] == true;
      passwordMessage = passwordSuccess
          ? "Password updated successfully."
          : (result["message"] ?? "Failed to update password.");
      if (passwordSuccess) {
        newPasswordCtrl.clear();
        confirmPasswordCtrl.clear();
      }
    });
  }

  Future<void> handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text("Confirm Logout"),
          ],
        ),
        content: const Text("Are you sure you want to log out of REC Sonbhadra ERP?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: handleLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Profile Photo ----
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                          ? NetworkImage(photoUrl!)
                          : null,
                      child: photoUrl == null || photoUrl!.isEmpty
                          ? const Icon(Icons.person, size: 48, color: primaryColor)
                          : null,
                    ),
                    if (uploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: uploadingPhoto ? null : pickAndUploadPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Tap the camera icon to change photo",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _card(
            title: "Profile Information",
            message: profileMessage,
            success: profileSuccess,
            children: [
              _field("Full Name", nameCtrl),
              _field("Designation", designationCtrl),
              _field("Email", emailCtrl, keyboard: TextInputType.emailAddress),
              _field("Contact Number", contactCtrl, keyboard: TextInputType.phone),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: savingProfile ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: savingProfile
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Changes"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _card(
            title: "Change Password",
            message: passwordMessage,
            success: passwordSuccess,
            children: [
              _field("New Password", newPasswordCtrl, obscure: true),
              _field("Confirm New Password", confirmPasswordCtrl, obscure: true),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: savingPassword ? null : savePassword,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: savingPassword
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Update Password"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---- LOGOUT BUTTON ----
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("Logout from Application", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: handleLogout,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required List<Widget> children,
    String? message,
    bool success = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (message != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: success ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool obscure = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: keyboard,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}