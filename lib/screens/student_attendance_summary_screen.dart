import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../services/api_service.dart';

const primaryColor = Color(0xFF3730A3);

class StudentAttendanceSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentAttendanceSummaryScreen({super.key, required this.student});

  @override
  State<StudentAttendanceSummaryScreen> createState() => _StudentAttendanceSummaryScreenState();
}

class _StudentAttendanceSummaryScreenState extends State<StudentAttendanceSummaryScreen> {
  bool loading = true;

  double overallPercentage = 72.0;
  int presentPct = 72;
  int absentPct = 18;
  int leavePct = 10;

  List<Map<String, dynamic>> subjectAttendance = [
    {"code": "CSE301", "name": "Data Structures", "pct": 75.0, "color": Colors.green},
    {"code": "CSE302", "name": "Database Management Systems", "pct": 68.0, "color": Colors.orange},
    {"code": "MAT201", "name": "Mathematics", "pct": 62.0, "color": Colors.orange},
    {"code": "ECE201", "name": "Digital Electronics", "pct": 80.0, "color": Colors.green},
    {"code": "PHY201", "name": "Physics", "pct": 70.0, "color": Colors.green},
  ];

  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadStudentAttendanceData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> loadStudentAttendanceData() async {
    setState(() => loading = true);

    try {
      final sRoll = (widget.student['roll_no'] ?? '').toString();
      final sId = widget.student['id'];

      // Fetch all attendance records from backend
      final rawAttendance = await ApiService.getRaw("${ApiService.baseUrl}/attendance");
      final myRecords = rawAttendance.where((a) {
        final rMatch = sRoll.isNotEmpty && a['roll_no'].toString().toLowerCase() == sRoll.toLowerCase();
        final iMatch = sId != null && a['student_id'] == sId;
        return rMatch || iMatch;
      }).toList();

      if (myRecords.isNotEmpty) {
        final presentCount = myRecords.where((a) => (a['status'] ?? '').toString().toLowerCase() == 'present').length;
        final absentCount = myRecords.where((a) => (a['status'] ?? '').toString().toLowerCase() == 'absent').length;

        final total = myRecords.length;
        overallPercentage = (presentCount / total) * 100;
        presentPct = ((presentCount / total) * 100).round();
        absentPct = ((absentCount / total) * 100).round();
        leavePct = 100 - presentPct - absentPct;
        if (leavePct < 0) leavePct = 0;

        // Group by subject
        final Map<String, List<String>> bySubject = {};
        final Map<String, String> subNames = {};
        for (var r in myRecords) {
          final code = (r['subject_code'] ?? r['subject'] ?? 'SUB').toString();
          final name = (r['subject_name'] ?? code).toString();
          subNames[code] = name;
          bySubject.putIfAbsent(code, () => []).add((r['status'] ?? '').toString().toLowerCase());
        }

        final List<Map<String, dynamic>> computed = [];
        bySubject.forEach((code, statuses) {
          final pCount = statuses.where((s) => s == 'present').length;
          final pct = (pCount / statuses.length) * 100;
          computed.add({
            "code": code,
            "name": subNames[code] ?? code,
            "pct": pct,
            "color": pct >= 75 ? Colors.green : Colors.orange,
          });
        });

        if (computed.isNotEmpty) {
          subjectAttendance = computed;
        }
      }
    } catch (_) {}

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Attendance Summary"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadStudentAttendanceData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Donut Chart Card (Screen 4 Layout)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Circular Chart
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: CustomPaint(
                              painter: _AttendanceDonutPainter(
                                presentPct: presentPct,
                                absentPct: absentPct,
                                leavePct: leavePct,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${overallPercentage.toStringAsFixed(0)}%",
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    Text(
                                      "Overall\nAttendance",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Legend Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _legendBadge("Present:", "$presentPct%", Colors.green),
                                const SizedBox(height: 10),
                                _legendBadge("Absent:", "$absentPct%", Colors.red),
                                const SizedBox(height: 10),
                                _legendBadge("Leave:", "$leavePct%", Colors.orange),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Attendance by Subject Header
                    const Text("Attendance by Subject", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Subject Progress Bars List (Screen 4 Layout)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: subjectAttendance.map((item) {
                          final double pct = (item['pct'] as num).toDouble();
                          final Color color = pct >= 75 ? Colors.green : (pct >= 65 ? Colors.orange : Colors.red);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['code'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          item['name'],
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "${pct.toStringAsFixed(0)}%",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct / 100.0,
                                    backgroundColor: Colors.grey.shade100,
                                    color: color,
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Monthly Attendance Trend Line Chart (Screen 4 Layout)
                    const Text("Monthly Attendance Trend", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    Container(
                      height: 220,
                      padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (val, meta) => Text(
                                  "${val.toInt()}%",
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"];
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < months.length) {
                                    return Text(months[idx], style: TextStyle(fontSize: 10, color: Colors.grey.shade600));
                                  }
                                  return const Text("");
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 5,
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 60),
                                FlSpot(1, 80),
                                FlSpot(2, 65),
                                FlSpot(3, 50),
                                FlSpot(4, 70),
                                FlSpot(5, 72),
                              ],
                              isCurved: true,
                              color: primaryColor,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: primaryColor.withValues(alpha: 0.08),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _legendBadge(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}

class _AttendanceDonutPainter extends CustomPainter {
  final int presentPct, absentPct, leavePct;
  _AttendanceDonutPainter({required this.presentPct, required this.absentPct, required this.leavePct});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 14.0;

    final values = [presentPct, absentPct, leavePct];
    final colors = [Colors.green, Colors.red, Colors.orange];

    double startAngle = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = (values[i] / 100.0) * 2 * pi;
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
  bool shouldRepaint(covariant _AttendanceDonutPainter oldDelegate) => true;
}
