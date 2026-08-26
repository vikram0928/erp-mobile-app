import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/faculty_main_screen.dart';
import 'screens/student_main_screen.dart';
import 'services/api_service.dart';
 
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REC Sonbhadra ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1D63D1),
        fontFamily: 'Roboto',
      ),
      home: const SplashDecider(),
    );
  }
}
 
class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});
 
  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}
 
class _SplashDeciderState extends State<SplashDecider> {
  @override
  void initState() {
    super.initState();
    checkLogin();
  }
 
  Future<void> checkLogin() async {
    final loggedIn = await ApiService.isLoggedIn();
    final role = await ApiService.getRole();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
 
    Widget destination;
    if (!loggedIn) {
      destination = const LoginScreen();
    } else if (role == "faculty") {
      destination = const FacultyMainScreen();
    } else {
      destination = StudentMainScreen();
    }
 
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
 
 