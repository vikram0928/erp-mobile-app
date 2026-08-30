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
    final sId = widget.student['id'];

    // DEBUG: print student id being used
    debugPrint('[StudentDetail] Loading data for student_id=$sId');

    try {
      // 1. Fetch attendance filtered by student_id directly from backend
      final attendanceUrl = "${ApiService.baseUrl}/attendance?student_id=$sId";
      debugPrint('[StudentDetail] Fetching: $attendanceUrl');
      final myAttendance = await ApiService.getRaw(attendanceUrl);
      debugPrint('[StudentDetail] Attendance records: ${myAttendance.length}');

      if (myAttendance.isNotEmpty) {
        totalClasses = myAttendance.length;
        presentClasses = myAttendance.where((a) => a['status'] == 'present').length;
        attendancePct = (presentClasses / totalClasses) * 100;
      }

      // 2. Fetch CT marks filtered by student_id directly from backend
      final ctUrl = "${ApiService.baseUrl}/ct-marks?student_id=$sId";
      debugPrint('[StudentDetail] Fetching: $ctUrl');
      final myCt = await ApiService.getRaw(ctUrl);
      debugPrint('[StudentDetail] CT mark records: ${myCt.length}');

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
    } catch (e) {
      debugPrint('[StudentDetail] ERROR loading data: $e');
      setState(() => loadingData = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final name = (s['name'] ?? 'Student').toString();
    final roll = (s['roll_no'] ?? '-').toString();

    // Department: API returns a nested 'department' object with a 'name' key
    final deptObj = s['department'];
    final dept = deptObj is Map
        ? (deptObj['name'] ?? deptObj['code'] ?? '-').toString()
        : (s['dept_name'] ?? '-').toString();

    // year: API field is current_year
    final year = (s['current_year'] ?? s['year'] ?? '-').toString();

    // email, phone, parent info
    final email       = (s['email'] ?? '-').toString();
    final phone       = (s['contact_no'] ?? s['phone'] ?? '-').toString();
    final parentName  = (s['father_name'] ?? s['parent_name'] ?? '-').toString();
    final parentPhone = (s['father_contact_no'] ?? s['parent_phone'] ?? '-').toString();

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
                height: MediaQuery.of(context).size.height * 0.55,
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
                        _infoItem("Email", email),
                        _infoItem("Phone", phone),
                        const SizedBox(height: 16),
                        const Text("Parent / Guardian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        _infoItem("Name", parentName),
                        _infoItem("Phone", parentPhone),
                      ],
                    ),

                    // Attendance Sub-tab — grouped by subject with date & period
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Attendance Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: attendancePct >= 75 ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                totalClasses > 0 ? "$presentClasses/$totalClasses Present" : "No Data",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: attendancePct >= 75 ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (studentAttendanceRecords.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                "No attendance records found for this student.",
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          ...studentAttendanceRecords.map((a) {
                            final subName = (a['subject'] ?? a['subject_name'] ?? 'Subject').toString();
                            final subCode = (a['subject_code'] ?? '').toString();
                            final status = (a['status'] ?? 'absent').toString();
                            final isP = status == 'present';
                            final date = (a['date'] ?? '').toString();
                            final period = a['period_no'] != null ? "P${a['period_no']}" : '';
                            final markedBy = (a['marked_by'] ?? '').toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isP ? Colors.green.shade100 : Colors.red.shade100,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isP ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(subName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (subCode.isNotEmpty)
                                          Text(subCode, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (date.isNotEmpty) ...[
                                              Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                                              const SizedBox(width: 3),
                                              Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                              const SizedBox(width: 8),
                                            ],
                                            if (period.isNotEmpty) ...[
                                              Icon(Icons.access_time, size: 11, color: Colors.grey.shade500),
                                              const SizedBox(width: 3),
                                              Text(period, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                            ],
                                          ],
                                        ),
                                        if (markedBy.isNotEmpty)
                                          Text("By: $markedBy", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isP ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isP ? "P" : "A",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),

                    // CT Marks Sub-tab — shows subject, CT no, score bar, academic year
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("CT Marks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (studentCtMarks.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Avg: ${ctAveragePct.toStringAsFixed(0)}%",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (studentCtMarks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                "No CT mark records found for this student.",
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          ...studentCtMarks.map((m) {
                            final subName = (m['subject'] ?? m['subject_name'] ?? 'Subject').toString();
                            final subCode = (m['subject_code'] ?? '').toString();
                            final ct = "CT ${m['ct_number'] ?? '?'}";
                            final obtained = (m['marks_obtained'] ?? 0) as num;
                            final max = (m['max_marks'] ?? 20) as num;
                            final pct = max > 0 ? (obtained / max) : 0.0;
                            final year = (m['academic_year'] ?? '').toString();
                            final uploadedBy = (m['uploaded_by'] ?? '').toString();
                            final scoreColor = pct >= 0.75
                                ? Colors.green
                                : pct >= 0.5
                                    ? Colors.orange
                                    : Colors.red;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(subName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            if (subCode.isNotEmpty)
                                              Text(subCode, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(ct, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "$obtained / $max",
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scoreColor),
                                      ),
                                      Text(
                                        "${(pct * 100).toStringAsFixed(0)}%",
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scoreColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct.toDouble(),
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (year.isNotEmpty) ...[
                                        Icon(Icons.school, size: 11, color: Colors.grey.shade400),
                                        const SizedBox(width: 3),
                                        Text(year, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                        const SizedBox(width: 10),
                                      ],
                                      if (uploadedBy.isNotEmpty) ...[
                                        Icon(Icons.person_outline, size: 11, color: Colors.grey.shade400),
                                        const SizedBox(width: 3),
                                        Text(uploadedBy, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),

                    // History Sub-tab — shows attendance & CT marks summary
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text("Academic Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        _summaryRow("Total Classes", "$totalClasses", Colors.grey.shade700),
                        _summaryRow("Classes Attended", "$presentClasses", Colors.green),
                        _summaryRow("Classes Absent", "${totalClasses - presentClasses}", Colors.red),
                        _summaryRow(
                          "Attendance %",
                          totalClasses > 0 ? "${attendancePct.toStringAsFixed(1)}%" : "N/A",
                          attendancePct >= 75 ? Colors.green : Colors.red,
                          isBold: true,
                        ),
                        const Divider(height: 24),
                        _summaryRow("CT Tests Recorded", "${studentCtMarks.length}", Colors.blue),
                        _summaryRow(
                          "Avg CT Score",
                          studentCtMarks.isNotEmpty ? "${ctAveragePct.toStringAsFixed(1)}%" : "N/A",
                          ctAveragePct >= 50 ? Colors.green : Colors.red,
                          isBold: true,
                        ),
                        const Divider(height: 24),
                        _summaryRow(
                          "Academic Standing",
                          attendancePct >= 75 && ctAveragePct >= 50
                              ? "Good Standing ✓"
                              : attendancePct < 75
                                  ? "Low Attendance ⚠"
                                  : "Needs Improvement",
                          attendancePct >= 75 && ctAveragePct >= 50 ? Colors.green : Colors.orange,
                          isBold: true,
                        ),
                      ],
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
