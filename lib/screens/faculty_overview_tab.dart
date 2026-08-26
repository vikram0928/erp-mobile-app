import 'package:flutter/material.dart';
import 'dart:math';
import '../services/api_service.dart';
import 'attendance_mark_screen.dart';
import 'ct_marks_screen.dart';
import 'today_classes_screen.dart';
import 'students_list_screen.dart';

import 'attendance_analytics_screen.dart';

const primaryColor = Color(0xFF1D63D1);

class FacultyOverviewTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const FacultyOverviewTab({super.key, required this.user});

  @override
  State<FacultyOverviewTab> createState() => _FacultyOverviewTabState();
}

class _FacultyOverviewTabState extends State<FacultyOverviewTab> {
  bool loading = true;

  int totalSubjects = 0;
  int classesToday = 0;
  int totalStudents = 0;
  double overallAttendancePct = 0;
  int lowAttendanceCount = 0;
  double attendanceThreshold = 75;

  double ctAveragePct = 0;
  int ctExcellent = 0, ctGood = 0, ctAverage = 0, ctLow = 0;

  static const Map<int, String> weekdayMap = {
    1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat",
  };

  @override
  void initState() {
    super.initState();
    loadOverview();
  }

  Future<void> loadOverview() async {
    setState(() {
      loading = true;
      ctExcellent = 0;
      ctGood = 0;
      ctAverage = 0;
      ctLow = 0;
      ctAveragePct = 0;
    });

    try {
      // Threshold
      try {
        final settings = await ApiService.getSystemSettings();
        final t = double.tryParse(settings['attendance_limit']?.toString() ?? "");
        if (t != null) attendanceThreshold = t;
      } catch (_) {}

      // Subjects
      final subjects = await ApiService.getFacultySubjects(widget.user['id']);
      totalSubjects = subjects.length;
      final subjectCodes = subjects.map((s) => s['subject_code'].toString()).toSet();
      final subjectIds = subjects.map((s) => s['id']).toSet();

      // Classes today
      final today = weekdayMap[DateTime.now().weekday];
      final timetable = await ApiService.getFacultyTimetable(widget.user['id']);
      classesToday = timetable.where((e) => e['day_of_week'] == today).length;

      // Unique students across all (dept, year) combos taught
      final deptYearPairs = <String>{};
      final Map<String, dynamic> studentsById = {};
      for (var s in subjects) {
        final deptId = s['dept_id'] ?? widget.user['dept_id'];
        final year = s['year'];
        final key = "$deptId-$year";
        if (deptYearPairs.contains(key)) continue;
        deptYearPairs.add(key);
        try {
          final list = await ApiService.getStudents(deptId, year);
          for (var st in list) {
            studentsById[st['roll_no']] = st;
          }
        } catch (_) {}
      }
      totalStudents = studentsById.length;

      // Attendance — fetch all records, filter to this faculty's subjects
      try {
        final allAttendance = await ApiService.getRaw("${ApiService.baseUrl}/attendance");
        final myAttendance = allAttendance.where((a) {
          final sCode = (a['subject_code'] ?? a['subject'] ?? '').toString();
          return subjectCodes.contains(sCode) || subjectIds.contains(a['subject_id']);
        }).toList();

        if (myAttendance.isNotEmpty) {
          final present = myAttendance.where((a) => a['status'] == 'present').length;
          overallAttendancePct = (present / myAttendance.length) * 100;

          // Per-student % for low-attendance count
          final Map<String, List<String>> perStudent = {};
          for (var a in myAttendance) {
            final roll = (a['roll_no'] ?? a['student_id'] ?? '').toString();
            perStudent.putIfAbsent(roll, () => []).add(a['status'].toString());
          }
          lowAttendanceCount = perStudent.values.where((statuses) {
            final p = statuses.where((s) => s == 'present').length;
            final pct = (p / statuses.length) * 100;
            return pct < attendanceThreshold;
          }).length;
        }
      } catch (_) {}

      // CT Marks — fetch all, filter to this faculty's subjects or all recorded CT marks
      try {
        final allCt = await ApiService.getRaw("${ApiService.baseUrl}/ct-marks");
        final myCt = allCt.where((m) {
          final sCode = (m['subject_code'] ?? m['subject'] ?? '').toString();
          return subjectCodes.isEmpty || subjectCodes.contains(sCode) || subjectIds.contains(m['subject_id']);
        }).toList();

        final ctList = myCt.isNotEmpty ? myCt : allCt;

        if (ctList.isNotEmpty) {
          double totalPct = 0;
          for (var m in ctList) {
            final obt = double.tryParse(m['marks_obtained']?.toString() ?? '0') ?? 0.0;
            final maxM = double.tryParse(m['max_marks']?.toString() ?? '20') ?? 20.0;
            final pct = maxM > 0 ? (obt / maxM) * 100 : 0.0;

            totalPct += pct;
            if (pct >= 85) {
              ctExcellent++;
            } else if (pct >= 70) {
              ctGood++;
            } else if (pct >= 50) {
              ctAverage++;
            } else {
              ctLow++;
            }
          }
          ctAveragePct = totalPct / ctList.length;
        }
      } catch (_) {}
    } catch (_) {
      // best-effort
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  backgroundImage: (widget.user['profile_photo_url'] != null &&
                          widget.user['profile_photo_url'].toString().isNotEmpty)
                      ? NetworkImage(ApiService.fixPhotoUrl(widget.user['profile_photo_url']))
                      : null,
                  child: (widget.user['profile_photo_url'] == null ||
                          widget.user['profile_photo_url'].toString().isEmpty)
                      ? const Icon(Icons.person, color: primaryColor)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Good Morning,", style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      Text(
                        widget.user['name'] ?? "",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Attendance Summary Cards (Clickable -> Opens Attendance Analytics & Register)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Attendance Summary", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AttendanceAnalyticsScreen(user: widget.user)),
                  );
                },
                child: const Text("View Register →", style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AttendanceAnalyticsScreen(user: widget.user)),
                    );
                  },
                  child: _statCard(
                    "${overallAttendancePct.toStringAsFixed(1)}%",
                    "Overall Attendance",
                    Colors.blue.shade50,
                    primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceAnalyticsScreen(
                          user: widget.user,
                          filterLowAttendanceOnly: true,
                        ),
                      ),
                    );
                  },
                  child: _statCard(
                    "$lowAttendanceCount",
                    "Below ${attendanceThreshold.toStringAsFixed(0)}% Threshold",
                    Colors.red.shade50,
                    Colors.red,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // CT Performance Card (Clickable -> Opens CT Marks Screen)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("CT Performance (Overall)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CtMarksScreen(user: widget.user)),
                  );
                },
                child: const Text("Enter Marks →", style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CtMarksScreen(user: widget.user)),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _DonutPainter(
                        excellent: ctExcellent, good: ctGood, average: ctAverage, low: ctLow,
                      ),
                      child: Center(
                        child: Text(
                          "${ctAveragePct.toStringAsFixed(0)}%",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendRow("Excellent (85%+)", Colors.green, ctExcellent),
                        _legendRow("Good (70-84%)", Colors.blue, ctGood),
                        _legendRow("Average (50-69%)", Colors.orange, ctAverage),
                        _legendRow("Low (<50%)", Colors.red, ctLow),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Stats (Interactive Click-Throughs)
          const Text("Quick Stats", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text("Students"), backgroundColor: primaryColor, foregroundColor: Colors.white),
                          body: StudentsListScreen(user: widget.user),
                        ),
                      ),
                    );
                  },
                  child: _miniStat("$totalStudents", "Total Students"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AttendanceMarkScreen(user: widget.user)),
                    );
                  },
                  child: _miniStat("$totalSubjects", "Total Subjects"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text("Today's Classes"), backgroundColor: primaryColor, foregroundColor: Colors.white),
                          body: TodayClassesTab(user: widget.user),
                        ),
                      ),
                    );
                  },
                  child: _miniStat("$classesToday", "Classes Today"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fg)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _legendRow(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Text("$count", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int excellent, good, average, low;
  _DonutPainter({required this.excellent, required this.good, required this.average, required this.low});

  @override
  void paint(Canvas canvas, Size size) {
    final total = excellent + good + average + low;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final values = [excellent, good, average, low];
    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.red];

    double startAngle = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}