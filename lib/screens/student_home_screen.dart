import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'notifications_screen.dart';
import 'student_attendance_summary_screen.dart';
import 'student_ct_marks_summary_screen.dart';

const primaryColor = Color(0xFF3730A3);

class StudentHomeScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentHomeScreen({super.key, required this.student});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  bool loading = true;
  late Map<String, dynamic> currentStudent;

  double attendancePct = 72.0;
  double ctMarksPct = 73.4;
  double overallPerformanceScore = 72.7;
  String performanceCategory = "VERY GOOD";
  int unreadNotificationsCount = 3;

  @override
  void initState() {
    super.initState();
    currentStudent = Map<String, dynamic>.from(widget.student);
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    setState(() => loading = true);

    try {
      // Refresh student user data from local/server session
      final freshUser = await ApiService.getUser();
      if (freshUser != null) {
        currentStudent = Map<String, dynamic>.from(freshUser);
      }

      final sRoll = (currentStudent['roll_no'] ?? '').toString();
      final sId = currentStudent['id'];

      // 1. Attendance %
      final rawAttendance = await ApiService.getRaw("${ApiService.baseUrl}/attendance");
      final myAttendance = rawAttendance.where((a) {
        final rMatch = sRoll.isNotEmpty && a['roll_no'].toString().toLowerCase() == sRoll.toLowerCase();
        final iMatch = sId != null && a['student_id'] == sId;
        return rMatch || iMatch;
      }).toList();

      if (myAttendance.isNotEmpty) {
        final pCount = myAttendance.where((a) => (a['status'] ?? '').toString().toLowerCase() == 'present').length;
        attendancePct = (pCount / myAttendance.length) * 100;
      }

      // 2. CT Marks %
      final rawCt = await ApiService.getRaw("${ApiService.baseUrl}/ct-marks");
      final myCt = rawCt.where((m) {
        final rMatch = sRoll.isNotEmpty && m['roll_no'].toString().toLowerCase() == sRoll.toLowerCase();
        final iMatch = sId != null && m['student_id'] == sId;
        return rMatch || iMatch;
      }).toList();

      if (myCt.isNotEmpty) {
        double totalPct = 0;
        for (var m in myCt) {
          final obt = double.tryParse(m['marks_obtained']?.toString() ?? '0') ?? 0.0;
          final maxM = double.tryParse(m['max_marks']?.toString() ?? '20') ?? 20.0;
          totalPct += maxM > 0 ? (obt / maxM) * 100 : 0;
        }
        ctMarksPct = totalPct / myCt.length;
      }

      // 3. Performance
      overallPerformanceScore = (attendancePct * 0.5) + (ctMarksPct * 0.5);
      if (overallPerformanceScore >= 85) {
        performanceCategory = "EXCELLENT";
      } else if (overallPerformanceScore >= 70) {
        performanceCategory = "VERY GOOD";
      } else if (overallPerformanceScore >= 60) {
        performanceCategory = "GOOD";
      } else if (overallPerformanceScore >= 50) {
        performanceCategory = "AVERAGE";
      } else {
        performanceCategory = "NEED ATTENTION";
      }
    } catch (_) {}

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = ApiService.fixPhotoUrl(currentStudent['profile_photo_url'] ?? currentStudent['photo']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: true,
        bottom: false,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadDashboardData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // Header Banner (Hello, Student 👋 Welcome back!) - Shifted nicely below status bar
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3730A3).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: photoUrl.isNotEmpty
                                  ? Image.network(
                                      photoUrl,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 28, color: primaryColor),
                                    )
                                  : const Icon(Icons.person, size: 28, color: primaryColor),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hello, ${currentStudent['name'] ?? 'Vikram Singh'} 👋",
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Welcome back!",
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                          // Notification Bell with Unread Badge
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                  );
                                },
                              ),
                              if (unreadNotificationsCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      "$unreadNotificationsCount",
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Notifications Preview Box (Screen 1 Layout)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.notifications_active_outlined, size: 18, color: primaryColor),
                                  SizedBox(width: 6),
                                  Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                  );
                                },
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                child: const Text("View All", style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _notificationRow(
                            icon: Icons.calendar_month,
                            iconBg: Colors.purple.shade50,
                            iconColor: Colors.purple,
                            title: "Your next class is at 10:00 AM – Data Structures, P2",
                            time: "5 min ago",
                          ),
                          Divider(height: 16, color: Colors.grey.shade100),
                          _notificationRow(
                            icon: Icons.assignment_turned_in,
                            iconBg: Colors.green.shade50,
                            iconColor: Colors.green,
                            title: "CT-1 marks have been uploaded",
                            time: "1 hr ago",
                          ),
                          Divider(height: 16, color: Colors.grey.shade100),
                          _notificationRow(
                            icon: Icons.warning_amber_rounded,
                            iconBg: Colors.orange.shade50,
                            iconColor: Colors.orange,
                            title: "Your attendance is below the threshold in Mathematics",
                            time: "2 hrs ago",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 1: Attendance Summary (Screen 1 Layout)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentAttendanceSummaryScreen(student: currentStudent),
                          ),
                        );
                      },
                      child: _summaryCard(
                        icon: Icons.event_available,
                        iconBg: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        title: "Attendance Summary",
                        value: "${attendancePct.toStringAsFixed(0)}%",
                        subtitle: "Overall Attendance",
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 2: CT Marks Summary (Screen 1 Layout)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentCtMarksSummaryScreen(student: currentStudent),
                          ),
                        );
                      },
                      child: _summaryCard(
                        icon: Icons.analytics_outlined,
                        iconBg: Colors.green.shade50,
                        iconColor: Colors.green.shade700,
                        title: "CT Marks Summary",
                        value: "${ctMarksPct.toStringAsFixed(1)}%",
                        subtitle: "Average Marks",
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 3: Overall Performance (Screen 1 Layout)
                    _summaryCard(
                      icon: Icons.emoji_events_outlined,
                      iconBg: Colors.purple.shade50,
                      iconColor: Colors.purple.shade700,
                      title: "Overall Performance",
                      value: performanceCategory,
                      subtitle: "${overallPerformanceScore.toStringAsFixed(1)}%",
                      showArrow: false,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _notificationRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Row(
          children: [
            Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(width: 4),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    bool showArrow = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (showArrow)
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
        ],
      ),
    );
  }
}
