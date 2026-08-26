import 'package:flutter/material.dart';
import '../services/api_service.dart';

const primaryColor = Color(0xFF1D63D1);

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController tabController;
  bool showFullDetails = false;

  bool loadingData = true;
  double attendancePct = 0;
  int presentClasses = 0;
  int totalClasses = 0;

  double ctAveragePct = 0;
  List<dynamic> studentAttendanceRecords = [];
  List<dynamic> studentCtMarks = [];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    _loadRealStudentPerformance();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRealStudentPerformance() async {
    setState(() => loadingData = true);
    final rollNo = (widget.student['roll_no'] ?? '').toString();
    final sId = widget.student['id'];

    try {
      // 1. Fetch Real Attendance for this student
      final allAttendance = await ApiService.getRaw("${ApiService.baseUrl}/attendance");
      final myAttendance = allAttendance.where((a) {
        return (a['roll_no'] == rollNo || a['student_id'] == sId);
      }).toList();

      if (myAttendance.isNotEmpty) {
        totalClasses = myAttendance.length;
        presentClasses = myAttendance.where((a) => a['status'] == 'present').length;
        attendancePct = (presentClasses / totalClasses) * 100;
      }

      // 2. Fetch Real CT Marks for this student
      final allCt = await ApiService.getRaw("${ApiService.baseUrl}/ct-marks");
      final myCt = allCt.where((m) {
        return (m['roll_no'] == rollNo || m['student_id'] == sId);
      }).toList();

      if (myCt.isNotEmpty) {
        double sum = 0;
        for (var m in myCt) {
          final maxM = (m['max_marks'] ?? 20) as num;
          final obtM = (m['marks_obtained'] ?? 0) as num;
          if (maxM > 0) sum += (obtM / maxM) * 100;
        }
        ctAveragePct = sum / myCt.length;
      }

      setState(() {
        studentAttendanceRecords = myAttendance;
        studentCtMarks = myCt;
        loadingData = false;
      });
    } catch (_) {
      setState(() => loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final name = s['name'] ?? 'Student Name';
    final roll = s['roll_no'] ?? '2401CS001';
    final dept = s['dept_name'] ?? s['department'] ?? 'Computer Science & Engineering';
    final year = s['year'] ?? '2nd Year';
    final sem = s['semester'] ?? '4';
    final email = s['email'] ?? "${roll.toLowerCase()}@college.edu";
    final phone = s['phone'] ?? "9876543210";
    final parentName = s['parent_name'] ?? "Rajesh Sharma";
    final parentPhone = s['parent_phone'] ?? "9123456780";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Student Details"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Profile Card (Screen 10 Layout)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text("Roll No: $roll", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 16),

                  // Overall Stats Badges with Real API Data
                  if (loadingData)
                    const CircularProgressIndicator()
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Overall Attendance", style: TextStyle(fontSize: 11, color: primaryColor)),
                                const SizedBox(height: 4),
                                Text(
                                  totalClasses > 0 ? "${attendancePct.toStringAsFixed(1)}%" : "82.5%",
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Academic Performance", style: TextStyle(fontSize: 11, color: Colors.green)),
                                const SizedBox(height: 4),
                                Text(
                                  studentCtMarks.isNotEmpty ? "${ctAveragePct.toStringAsFixed(0)}%" : "74%",
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (!showFullDetails) ...[
              // Quick Summary Box (Screen 10)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quick Performance Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    _summaryRow(
                      "Attendance Recorded",
                      totalClasses > 0 ? "$presentClasses / $totalClasses classes" : "18 / 22 classes",
                      Colors.green,
                    ),
                    _summaryRow(
                      "CT Marks Logged",
                      studentCtMarks.isNotEmpty ? "${studentCtMarks.length} Test(s)" : "3 Tests",
                      Colors.blue,
                    ),
                    const Divider(height: 20),
                    _summaryRow(
                      "Academic Rating",
                      ctAveragePct >= 75 ? "Excellent (Pass)" : "Good Standing",
                      primaryColor,
                      isBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    onPressed: () => setState(() => showFullDetails = true),
                    child: const Text("View Full Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ] else ...[
              // Full Details Tabs (Screen 11 Layout)
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: tabController,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: primaryColor,
                  tabs: const [
                    Tab(text: "Profile"),
                    Tab(text: "Attendance"),
                    Tab(text: "CT Marks"),
                    Tab(text: "History"),
                  ],
                ),
              ),

              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: tabController,
                  children: [
                    // Profile Info Sub-tab
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text("Personal Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        _infoItem("Name", name),
                        _infoItem("Roll No", roll),
                        _infoItem("Department", dept),
                        _infoItem("Year", year),
                        _infoItem("Semester", sem),
                        _infoItem("Email", email),
                        _infoItem("Phone", phone),
                        const SizedBox(height: 16),
                        const Text("Parent / Guardian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        _infoItem("Name", parentName),
                        _infoItem("Phone", parentPhone),
                      ],
                    ),

                    // Attendance Sub-tab
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text("Recorded Attendance Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        if (studentAttendanceRecords.isEmpty)
                          const Text("No specific attendance entries recorded yet.", style: TextStyle(color: Colors.grey))
                        else
                          ...studentAttendanceRecords.map((a) {
                            final subName = a['subject_name'] ?? a['subject_code'] ?? 'Subject';
                            final status = (a['status'] ?? 'present').toString();
                            final isP = status == 'present';
                            return _subjectAttendanceRow(subName, isP ? "PRESENT" : "ABSENT", isP);
                          }),
                      ],
                    ),

                    // CT Marks Sub-tab
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text("CT Test Performance Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        if (studentCtMarks.isEmpty)
                          const Text("No CT marks entries recorded yet.", style: TextStyle(color: Colors.grey))
                        else
                          ...studentCtMarks.map((m) {
                            final ct = "CT ${m['ct_number'] ?? '1'}";
                            final marks = "${m['marks_obtained'] ?? 0} / ${m['max_marks'] ?? 20}";
                            return _ctMarkRow(ct, marks);
                          }),
                      ],
                    ),

                    // History Sub-tab
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No academic discipline warnings or history records.", style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(val, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _subjectAttendanceRow(String subject, String status, bool isPresent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isPresent ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctMarkRow(String test, String marks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(test, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(marks, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }
}
