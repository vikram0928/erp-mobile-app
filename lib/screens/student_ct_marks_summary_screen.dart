import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../services/api_service.dart';

const primaryColor = Color(0xFF3730A3);

class StudentCtMarksSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentCtMarksSummaryScreen({super.key, required this.student});

  @override
  State<StudentCtMarksSummaryScreen> createState() => _StudentCtMarksSummaryScreenState();
}

class _StudentCtMarksSummaryScreenState extends State<StudentCtMarksSummaryScreen> {
  bool loading = true;

  double overallCtAverage = 73.4;
  double ct1Avg = 73.8;
  double ct2Avg = 72.6;
  double ct3Avg = 73.7;

  List<Map<String, dynamic>> subjectMarks = [
    {"code": "CSE301", "name": "Data Structures", "ct1": 16, "ct2": 15, "ct3": 17, "avg": 48, "max": 60, "pct": 80.0},
    {"code": "CSE302", "name": "DBMS", "ct1": 14, "ct2": 13, "ct3": 15, "avg": 42, "max": 60, "pct": 70.0},
    {"code": "MAT201", "name": "Mathematics", "ct1": 12, "ct2": 11, "ct3": 13, "avg": 36, "max": 60, "pct": 60.0},
    {"code": "ECE201", "name": "Digital Electronics", "ct1": 17, "ct2": 16, "ct3": 18, "avg": 51, "max": 60, "pct": 85.0},
    {"code": "PHY201", "name": "Physics", "ct1": 13, "ct2": 14, "ct3": 15, "avg": 42, "max": 60, "pct": 70.0},
  ];

  @override
  void initState() {
    super.initState();
    loadStudentCtMarks();
  }

  Future<void> loadStudentCtMarks() async {
    setState(() => loading = true);

    try {
      final sRoll = (widget.student['roll_no'] ?? '').toString();
      final sId = widget.student['id'];

      final rawCt = await ApiService.getRaw("${ApiService.baseUrl}/ct-marks");
      final myCt = rawCt.where((m) {
        final rMatch = sRoll.isNotEmpty && m['roll_no'].toString().toLowerCase() == sRoll.toLowerCase();
        final iMatch = sId != null && m['student_id'] == sId;
        return rMatch || iMatch;
      }).toList();

      if (myCt.isNotEmpty) {
        final Map<String, Map<String, dynamic>> bySub = {};

        for (var m in myCt) {
          final code = (m['subject_code'] ?? m['subject'] ?? 'SUB').toString();
          final ctNum = m['ct_number'] ?? 1;
          final obt = double.tryParse(m['marks_obtained']?.toString() ?? '0') ?? 0.0;

          bySub.putIfAbsent(code, () => {
            "code": code,
            "name": code,
            "ct1": 0.0,
            "ct2": 0.0,
            "ct3": 0.0,
            "max": 60.0,
          });

          if (ctNum == 1) bySub[code]!['ct1'] = obt;
          if (ctNum == 2) bySub[code]!['ct2'] = obt;
          if (ctNum == 3) bySub[code]!['ct3'] = obt;
        }

        final List<Map<String, dynamic>> computed = [];
        double totalPctSum = 0;

        bySub.forEach((code, data) {
          final c1 = (data['ct1'] as num).toDouble();
          final c2 = (data['ct2'] as num).toDouble();
          final c3 = (data['ct3'] as num).toDouble();
          final sum = c1 + c2 + c3;
          final pct = (sum / 60.0) * 100;
          totalPctSum += pct;

          computed.add({
            "code": code,
            "name": code,
            "ct1": c1.toInt(),
            "ct2": c2.toInt(),
            "ct3": c3.toInt(),
            "avg": sum.toInt(),
            "max": 60,
            "pct": pct,
          });
        });

        if (computed.isNotEmpty) {
          subjectMarks = computed;
          overallCtAverage = totalPctSum / computed.length;
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
        title: const Text("CT Marks Summary"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadStudentCtMarks,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Donut Chart Card (Screen 5 Layout)
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
                          // Radial Donut Chart
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: CustomPaint(
                              painter: _CtDonutPainter(
                                ct1: ct1Avg,
                                ct2: ct2Avg,
                                ct3: ct3Avg,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${overallCtAverage.toStringAsFixed(1)}%",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    Text(
                                      "Average\nMarks",
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
                                _legendRow("CT-1", "${ct1Avg.toStringAsFixed(1)}%", Colors.blue),
                                const SizedBox(height: 10),
                                _legendRow("CT-2", "${ct2Avg.toStringAsFixed(1)}%", Colors.green),
                                const SizedBox(height: 10),
                                _legendRow("CT-3", "${ct3Avg.toStringAsFixed(1)}%", Colors.orange),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Marks by Subject Table Header
                    const Text("Marks by Subject", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Subject Marks Table (Screen 5 Layout)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Table(
                          columnWidths: const {
                            0: FixedColumnWidth(110),
                            1: FixedColumnWidth(50),
                            2: FixedColumnWidth(50),
                            3: FixedColumnWidth(50),
                            4: FixedColumnWidth(50),
                            5: FixedColumnWidth(60),
                          },
                          border: TableBorder.all(color: Colors.grey.shade200),
                          children: [
                            // Table Header Row
                            TableRow(
                              decoration: BoxDecoration(color: Colors.blue.shade50),
                              children: const [
                                Padding(padding: EdgeInsets.all(8.0), child: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor))),
                                Padding(padding: EdgeInsets.all(8.0), child: Text("CT-1\n(20)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: primaryColor))),
                                Padding(padding: EdgeInsets.all(8.0), child: Text("CT-2\n(20)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: primaryColor))),
                                Padding(padding: EdgeInsets.all(8.0), child: Text("CT-3\n(20)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: primaryColor))),
                                Padding(padding: EdgeInsets.all(8.0), child: Text("Avg\n(60)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: primaryColor))),
                                Padding(padding: EdgeInsets.all(8.0), child: Text("%", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor))),
                              ],
                            ),

                            // Rows for each subject
                            ...subjectMarks.map((m) {
                              final double pct = (m['pct'] as num).toDouble();
                              final Color bg = pct >= 80
                                  ? Colors.green.shade50
                                  : (pct >= 70 ? Colors.orange.shade50 : Colors.red.shade50);
                              final Color fg = pct >= 80
                                  ? Colors.green.shade800
                                  : (pct >= 70 ? Colors.orange.shade800 : Colors.red.shade800);

                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m['code'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text(m['name'], style: TextStyle(fontSize: 9, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  Padding(padding: const EdgeInsets.all(8.0), child: Text("${m['ct1']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(8.0), child: Text("${m['ct2']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(8.0), child: Text("${m['ct3']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(8.0), child: Text("${m['avg']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                                        child: Text("${pct.toStringAsFixed(0)}%", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CT Wise Performance Grouped Bar Chart (Screen 5 Layout)
                    const Text("CT Wise Performance Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    Container(
                      height: 230,
                      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 20,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (val, meta) => Text("${val.toInt()}", style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < subjectMarks.length) {
                                    return Text(subjectMarks[idx]['code'], style: TextStyle(fontSize: 9, color: Colors.grey.shade700));
                                  }
                                  return const Text("");
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
                          barGroups: subjectMarks.asMap().entries.map((e) {
                            final i = e.key;
                            final m = e.value;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(toY: (m['ct1'] as num).toDouble(), color: Colors.blue, width: 6),
                                BarChartRodData(toY: (m['ct2'] as num).toDouble(), color: Colors.green, width: 6),
                                BarChartRodData(toY: (m['ct3'] as num).toDouble(), color: Colors.orange, width: 6),
                              ],
                            );
                          }).toList(),
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

  Widget _legendRow(String label, String value, Color color) {
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

class _CtDonutPainter extends CustomPainter {
  final double ct1, ct2, ct3;
  _CtDonutPainter({required this.ct1, required this.ct2, required this.ct3});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 14.0;

    final values = [ct1, ct2, ct3];
    final colors = [Colors.blue, Colors.green, Colors.orange];
    final total = values.fold(0.0, (prev, element) => prev + element);

    if (total == 0) return;

    double startAngle = -pi / 2;
    for (int i = 0; i < values.length; i++) {
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
  bool shouldRepaint(covariant _CtDonutPainter oldDelegate) => true;
}
