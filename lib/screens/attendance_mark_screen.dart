import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../wedgets/academic_filter_widget.dart';

const primaryColor = Color(0xFF1D63D1);

enum AttendanceStage { filter, marking, review }

class AttendanceMarkScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final dynamic initialSubject;

  const AttendanceMarkScreen({
    super.key,
    required this.user,
    this.initialSubject,
  });

  @override
  State<AttendanceMarkScreen> createState() => _AttendanceMarkScreenState();
}

class _AttendanceMarkScreenState extends State<AttendanceMarkScreen> {
  AttendanceStage stage = AttendanceStage.filter;

  AcademicFilterResult? filterResult;
  dynamic selectedSubject;
  List<dynamic> students = [];
  List<dynamic> filteredStudents = [];
  Map<int, String> attendance = {}; // student_id -> "present" / "absent"
  String searchQuery = "";
  String classDate = "";

  bool loadingStudents = false;
  bool saving = false;
  bool finalizing = false;
  String error = "";

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    classDate =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // If initialSubject is passed from Today Classes / Home -> directly enter marking stage!
    if (widget.initialSubject != null) {
      selectedSubject = widget.initialSubject;
      _loadStudentsDirectly(widget.initialSubject);
    }
  }

  Future<void> _loadStudentsDirectly(dynamic sub) async {
    setState(() {
      loadingStudents = true;
      error = "";
    });

    try {
      final subObj = sub['subject'] ?? sub;
      final deptId = subObj['dept_id'] ?? sub['dept_id'] ?? widget.user['dept_id'] ?? 1;
      final year = subObj['year'] ?? sub['year'] ?? 'Y2';

      final dId = deptId is int ? deptId : int.tryParse(deptId.toString()) ?? 1;

      final data = await ApiService.getStudents(dId, year.toString());
      setState(() {
        students = data;
        filteredStudents = data;
        // Default ALL students to ABSENT (Issue 2)
        attendance = {for (var s in data) s['id']: "absent"};
        loadingStudents = false;
        stage = AttendanceStage.marking;
      });
    } catch (e) {
      setState(() {
        error = "Could not load students for selected class.";
        loadingStudents = false;
      });
    }
  }

  Future<void> _onFilterChanged(AcademicFilterResult result) async {
    setState(() {
      filterResult = result;
      selectedSubject = result.subject;
    });

    if (result.subject != null) {
      await loadStudentsForFilter(result);
    }
  }

  Future<void> loadStudentsForFilter(AcademicFilterResult result) async {
    setState(() {
      loadingStudents = true;
      error = "";
    });

    try {
      final data = await ApiService.getStudents(result.studentDeptId, result.year);
      setState(() {
        students = data;
        filteredStudents = data;
        // Default ALL students to ABSENT (Issue 2)
        attendance = {for (var s in data) s['id']: "absent"};
        loadingStudents = false;
        stage = AttendanceStage.marking;
      });
    } catch (e) {
      setState(() {
        error = "Could not load students for selected filter.";
        loadingStudents = false;
      });
    }
  }

  void _applySearch(String query) {
    setState(() {
      searchQuery = query;
      if (query.trim().isEmpty) {
        filteredStudents = students;
      } else {
        final q = query.toLowerCase();
        filteredStudents = students.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final roll = (s['roll_no'] ?? '').toString().toLowerCase();
          return name.contains(q) || roll.contains(q);
        }).toList();
      }
    });
  }

  Future<void> saveDraft() async {
    if (selectedSubject == null) return;
    setState(() => saving = true);

    final subObj = selectedSubject['subject'] ?? selectedSubject;
    final subId = subObj['id'] ?? subObj['subject_id'] ?? selectedSubject['id'] ?? 1;

    final records = students
        .map((s) => {"student_id": s['id'], "status": attendance[s['id']] ?? "absent"})
        .toList();

    final result = await ApiService.submitAttendance(
      subjectId: subId,
      classDate: classDate,
      periodNo: 1,
      markedBy: widget.user['id'],
      records: records,
    );

    setState(() => saving = false);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance draft saved successfully! ✅")),
      );
      setState(() => stage = AttendanceStage.review);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Failed to save draft")),
      );
    }
  }

  Future<void> finalSubmit() async {
    if (selectedSubject == null) return;
    setState(() => finalizing = true);

    final subObj = selectedSubject['subject'] ?? selectedSubject;
    final subId = subObj['id'] ?? subObj['subject_id'] ?? selectedSubject['id'] ?? 1;

    final records = students
        .map((s) => {"student_id": s['id'], "status": attendance[s['id']] ?? "absent"})
        .toList();

    await ApiService.submitAttendance(
      subjectId: subId,
      classDate: classDate,
      periodNo: 1,
      markedBy: widget.user['id'],
      records: records,
    );

    final result = await ApiService.finalizeAttendance(
      subjectId: subId,
      classDate: classDate,
      periodNo: 1,
    );

    setState(() => finalizing = false);

    if (!mounted) return;

    if (result['success'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text("Attendance Locked"),
            ],
          ),
          content: Text(
            "Present: ${attendance.values.where((v) => v == 'present').length} / ${students.length}\n"
            "Absent: ${attendance.values.where((v) => v == 'absent').length} / ${students.length}\n\n"
            "Attendance has been finalized and recorded in ERP.",
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Done", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Failed to finalize attendance")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptCode = (widget.user['dept_code'] ?? widget.user['dept_name'] ?? widget.user['department'] ?? 'CSE').toString();
    final deptId = widget.user['dept_id'] is int ? widget.user['dept_id'] as int : int.tryParse(widget.user['dept_id']?.toString() ?? '1') ?? 1;

    final subObj = selectedSubject != null ? (selectedSubject['subject'] ?? selectedSubject) : null;
    final subName = subObj != null ? (subObj['subject_name'] ?? selectedSubject['subject_name'] ?? 'Subject') : 'Subject';
    final subCode = subObj != null ? (subObj['subject_code'] ?? selectedSubject['subject_code'] ?? '') : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Take Attendance"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                stage = AttendanceStage.filter;
                students = [];
                filteredStudents = [];
              });
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Filter Box (Only shown if initialSubject wasn't passed)
            if (widget.initialSubject == null) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: AcademicFilterWidget(
                  facultyDeptId: deptId,
                  facultyDeptCode: deptCode,
                  showSubject: true,
                  facultyIdForSubjectFilter: widget.user['id'],
                  onChanged: _onFilterChanged,
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (loadingStudents)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              )
            else if (stage == AttendanceStage.filter)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    "Please select Year/Branch, Semester, and Subject above to load student sheet.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else ...[
              // Subject Info Header Card (Screen 4 Layout)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            subName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                        if (subCode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subCode,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Date: $classDate  |  Total Enrolled: ${students.length}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),

                    // Badges (Total, Present, Absent)
                    Row(
                      children: [
                        _buildSummaryBadge("Total Students", students.length.toString(), Colors.blue),
                        const SizedBox(width: 8),
                        _buildSummaryBadge(
                          "Present",
                          attendance.values.where((v) => v == "present").length.toString(),
                          Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _buildSummaryBadge(
                          "Absent",
                          attendance.values.where((v) => v == "absent").length.toString(),
                          Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: _applySearch,
                  decoration: InputDecoration(
                    hintText: "Search by name or roll no.",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Student List with P/A Toggle Chips
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
                  final sId = student['id'] as int;
                  final status = attendance[sId] ?? "absent"; // Default ABSENT
                  final isPresent = status == "present";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPresent ? Colors.green.shade200 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            (student['name'] ?? 'S')[0].toUpperCase(),
                            style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                student['roll_no'] ?? '',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Status Toggle (P / A Chip)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => attendance[sId] = "present");
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isPresent ? Colors.green : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "P",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPresent ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() => attendance[sId] = "absent");
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !isPresent ? Colors.red : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "A",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !isPresent ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Bottom Actions Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : saveDraft,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: saving
                            ? const SizedBox(
                                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Save Draft"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: finalizing ? null : finalSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: finalizing
                            ? const SizedBox(
                                height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Lock Attendance", style: TextStyle(color: Colors.white)),
                      ),
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

  Widget _buildSummaryBadge(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }
}