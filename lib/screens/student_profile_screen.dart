import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

const primaryColor = Color(0xFF3730A3);

class StudentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback? onProfileUpdated;
  const StudentProfileScreen({super.key, required this.student, this.onProfileUpdated});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String? photoUrl;
  bool uploadingPhoto = false;
  bool isEditing = false;
  bool saving = false;

  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController dobCtrl;
  late TextEditingController addressCtrl;

  @override
  void initState() {
    super.initState();
    photoUrl = ApiService.fixPhotoUrl(widget.student['profile_photo_url'] ?? widget.student['photo']);

    nameCtrl = TextEditingController(text: widget.student['name'] ?? "Vikram Singh");
    emailCtrl = TextEditingController(text: widget.student['email'] ?? "vikram.singh@college.edu.in");
    phoneCtrl = TextEditingController(text: widget.student['contact_no'] ?? widget.student['mobile'] ?? "+91 98765 43210");
    dobCtrl = TextEditingController(text: widget.student['dob'] ?? "15 Aug 2004");
    addressCtrl = TextEditingController(text: widget.student['address'] ?? "Lucknow, Uttar Pradesh, India");
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

    final sId = widget.student['id'] is int
        ? widget.student['id'] as int
        : int.tryParse(widget.student['id']?.toString() ?? '1') ?? 1;

    final result = await ApiService.uploadStudentPhoto(
      sId,
      File(picked.path),
    );

    setState(() {
      uploadingPhoto = false;
      if (result["success"] == true) {
        final fixed = ApiService.fixPhotoUrl(result["photo_url"]);
        photoUrl = "$fixed?t=${DateTime.now().millisecondsSinceEpoch}";
      }
    });
  }

  Future<void> saveProfileChanges() async {
    setState(() => saving = true);

    final sId = widget.student['id'] is int
        ? widget.student['id'] as int
        : int.tryParse(widget.student['id']?.toString() ?? '1') ?? 1;

    final deptId = widget.student['dept_id'] ?? widget.student['department']?['id'] ?? 1;
    final year = widget.student['current_year'] ?? widget.student['year'] ?? "Y3";
    final rollNo = widget.student['roll_no'] ?? "";

    final result = await ApiService.updateStudentProfile(sId, {
      "name": nameCtrl.text.trim(),
      "email": emailCtrl.text.trim(),
      "contact_no": phoneCtrl.text.trim(),
      "dob": dobCtrl.text.trim(),
      "address": addressCtrl.text.trim(),
      "roll_no": rollNo,
      "dept_id": deptId,
      "current_year": year,
    });

    setState(() {
      saving = false;
      isEditing = false;
    });

    if (!mounted) return;

    if (result['success'] == true) {
      // Notify parent (StudentMainScreen) to refresh user from server
      widget.onProfileUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile details updated successfully! ✅")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Failed to update profile")),
      );
    }
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
        content: const Text(
          "Are you sure you want to logout?\nYou will need to login again to access your account.",
        ),
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
    final rollNo = widget.student['roll_no'] ?? "21CSE101";
    final dept = widget.student['department']?['name'] ?? widget.student['department']?['code'] ?? "Computer Science & Engineering";
    final yearBranch = "${widget.student['current_year'] ?? '3rd Year'} / ${widget.student['branch'] ?? 'CSE'}";
    final semester = widget.student['semester'] ?? "Semester 5";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit_outlined),
            tooltip: isEditing ? "Save" : "Edit Profile",
            onPressed: () {
              if (isEditing) {
                saveProfileChanges();
              } else {
                setState(() => isEditing = true);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Photo & Name Section (Screen 3 Layout)
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
                              width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                const SizedBox(height: 12),
                if (!isEditing) ...[
                  Text(
                    nameCtrl.text,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Roll No. $rollNo",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: TextField(
                      controller: nameCtrl,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Editable Information Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _infoTile(Icons.domain_outlined, "Department", dept, editable: false),
                _infoTile(Icons.school_outlined, "Year / Branch", yearBranch, editable: false),
                _infoTile(Icons.calendar_today_outlined, "Semester", semester, editable: false),
                _infoFieldTile(Icons.email_outlined, "Email", emailCtrl, isEditing),
                _infoFieldTile(Icons.phone_outlined, "Mobile Number", phoneCtrl, isEditing),
                _infoFieldTile(Icons.cake_outlined, "Date of Birth", dobCtrl, isEditing),
                _infoFieldTile(Icons.location_on_outlined, "Address", addressCtrl, isEditing, showDivider: false),
              ],
            ),
          ),

          if (isEditing) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: saving ? null : saveProfileChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Save Profile Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Change Password Action Tile (Screen 3 Layout)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChangePasswordScreen(user: widget.student)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text("Change Password", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Logout Action Tile (Screen 3 Layout)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: handleLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade700)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, {bool editable = true, bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _infoFieldTile(IconData icon, String label, TextEditingController controller, bool editing, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 12),
              Expanded(
                child: editing
                    ? TextField(
                        controller: controller,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        ),
                      )
                    : Text(
                        controller.text,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}
