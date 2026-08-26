import 'package:flutter/material.dart';

class FacultyProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;
  final Future<void> Function() onProfileUpdated;

  const FacultyProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Faculty Profile\n${user['name'] ?? ''}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}