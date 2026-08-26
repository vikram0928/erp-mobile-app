import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'student_home_screen.dart';
import 'student_today_classes_screen.dart';
import 'student_schedule_screen.dart';
import 'student_profile_screen.dart';

const primaryColor = Color(0xFF3730A3);

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int currentTab = 0;
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final u = await ApiService.getStudentMe();
    setState(() {
      user = u;
      loading = false;
    });
  }

  void refreshUser() {
    loadUser();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final tabs = [
      StudentHomeScreen(student: user!),
      StudentTodayClassesScreen(student: user!),
      StudentScheduleScreen(student: user!),
      StudentProfileScreen(student: user!, onProfileUpdated: refreshUser),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: IndexedStack(index: currentTab, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentTab,
          onTap: (i) => setState(() => currentTab = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: "Today Classes",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: "Schedule",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}