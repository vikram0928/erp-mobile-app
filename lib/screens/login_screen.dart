import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'faculty_main_screen.dart';
import 'student_main_screen.dart';
 
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
 
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
 
class _LoginScreenState extends State<LoginScreen> {
  String selectedRole = "faculty";
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
 
  bool loading = false;
  String errorMessage = "";
 
  Future<void> handleLogin() async {
    setState(() {
      loading = true;
      errorMessage = "";
    });
 
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
 
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = "Please enter both email and password.";
        loading = false;
      });
      return;
    }
 
    final result = selectedRole == "faculty"
        ? await ApiService.facultyLogin(email, password)
        : await ApiService.studentLogin(email, password);
 
    setState(() => loading = false);
 
    if (result['success'] == true) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
           builder: (_) => selectedRole == "faculty"
              ? const FacultyMainScreen()
              : StudentMainScreen(),
        ),
      );
    } else {
      setState(() => errorMessage = result['message']);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1D63D1);
 
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.school, size: 56, color: primaryColor),
                const SizedBox(height: 12),
                const Text(
                  "REC Sonbhadra",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Attendance ERP Portal",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _roleButton("Faculty", "faculty", primaryColor),
                      _roleButton("Student", "student", primaryColor),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (errorMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Login",
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
 
  Widget _roleButton(String label, String value, Color primaryColor) {
    final isSelected = selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
 