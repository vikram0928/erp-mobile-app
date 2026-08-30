
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'faculty_overview_tab.dart';
import 'today_classes_screen.dart';
import 'weekly_schedule_screen.dart';
import 'students_list_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
 
const primaryColor = Color(0xFF1D63D1);
 
class FacultyMainScreen extends StatefulWidget {
  const FacultyMainScreen({super.key});
 
  @override
  State<FacultyMainScreen> createState() => _FacultyMainScreenState();
}
 
class _FacultyMainScreenState extends State<FacultyMainScreen> {
  int currentTab = 0;
  Map<String, dynamic>? user;
 
  @override
  void initState() {
    super.initState();
    loadUser();
  }
 
  Future<void> loadUser() async {
    final u = await ApiService.getUser();
    setState(() => user = u);
  }
 
  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
 
    final tabs = [
      FacultyOverviewTab(user: user!),
      TodayClassesTab(user: user!),
      WeeklyScheduleScreen(user: user!),
      StudentsListScreen(user: user!),
      ProfileScreen(user: user!),
    ];
 
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_titleFor(currentTab)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (currentTab == 4)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Logout",
              onPressed: () => _showLogoutDialog(context),
            ),
        ],
      ),
      body: IndexedStack(index: currentTab, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        onTap: (i) => setState(() => currentTab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Today Classes"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Schedule"),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Students"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
 
  String _titleFor(int index) {
    switch (index) {
      case 0:
        return "Overview";
      case 1:
        return "Today's Classes";
      case 2:
        return "Weekly Schedule";
      case 3:
        return "Students";
      default:
        return "My Profile";
    }
  }

  void _showLogoutDialog(BuildContext context) {
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
}
 