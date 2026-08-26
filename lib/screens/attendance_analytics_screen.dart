import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../wedgets/academic_filter_widget.dart';

const primaryColor = Color(0xFF1D63D1);

class AttendanceAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool filterLowAttendanceOnly;

  const AttendanceAnalyticsScreen({
    super.key,
    required this.user,
    this.filterLowAttendanceOnly = false,
  });

  @override
  State<AttendanceAnalyticsScreen> createState() => _AttendanceAnalyticsScreenState();
}

class _AttendanceAnalyticsScreenState extends State<AttendanceAnalyticsScreen> {
  AcademicFilterResult? filterResult;
  dynamic selectedSubject;

  List<dynamic> students = [];
  List<dynamic> attendanceRaw = [];
  List<String> dateColumns = []; // Unique "YYYY-MM-DD / P1" strings
  Map<String, Map<String, String>> matrixData = {}; // roll_no -> dateCol -> "present"/"absent"
  Map<String, double> studentPercentageMap = {}; // roll_no -> pct

  bool loadingData = false;
  double attendanceThreshold = 75;
  String searchQuery = "";

  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSystemThreshold();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemThreshold() async {
    try {
      final settings = await ApiService.getSystemSettings();
      final t = double.tryParse(settings['attendance_limit']?.toString() ?? "");
      if (t != null) {
        setState(() => attendanceThreshold = t);
      }
    } catch (_) {}
  }

  Future<void> _onFilterChanged(AcademicFilterResult result) async {
    setState(() {
      filterResult = result;
      selectedSubject = result.subject;
    });

    if (result.subject != null) {
      await _loadAttendanceMatrix(result);
    }
  }

  Future<void> _loadAttendanceMatrix(AcademicFilterResult result) async {
    setState(() {
      loadingData = true;
      students = [];
      dateColumns = [];
      matrixData = {};
      studentPercentageMap = {};
    });

    try {
      final subObj = result.subject;
      final subCode = (subObj['subject_code'] ?? '').toString();
      final subId = subObj['id'] ?? subObj['subject_id'];

      // 1. Fetch Students
      final studentList = await ApiService.getStudents(result.studentDeptId, result.year);

      // 2. Fetch All Attendance
      final rawRecords = await ApiService.getRaw("${ApiService.baseUrl}/attendance");
      final subjectRecords = rawRecords.where((a) {
        final codeMatch = subCode.isNotEmpty && (a['subject_code'] == subCode || a['subject'] == subCode);
        final idMatch = subId != null && a['subject_id'] == subId;
        return codeMatch || idMatch;
      }).toList();

      // 3. Extract unique date/period columns (e.g. "23 May / P1")
      final Set<String> colSet = {};
      for (var r in subjectRecords) {
        final d = (r['class_date'] ?? r['date'] ?? '').toString();
        final p = (r['period_no'] ?? r['period'] ?? '1').toString();
        if (d.isNotEmpty) {
          colSet.add("$d / P$p");
        }
      }

      final sortedCols = colSet.toList()..sort();

      // 4. Build Matrix & compute per-student %
      final Map<String, Map<String, String>> mat = {};
      final Map<String, double> pctMap = {};

      for (var st in studentList) {
        final roll = (st['roll_no'] ?? '').toString();
        mat[roll] = {};
      }

      for (var r in subjectRecords) {
        final roll = (r['roll_no'] ?? '').toString();
        final d = (r['class_date'] ?? r['date'] ?? '').toString();
        final p = (r['period_no'] ?? r['period'] ?? '1').toString();
        final colKey = "$d / P$p";
        final status = (r['status'] ?? 'absent').toString().toLowerCase();

        if (mat.containsKey(roll)) {
          mat[roll]![colKey] = status;
        }
      }

      // Calculate percentage for each student
      for (var st in studentList) {
        final roll = (st['roll_no'] ?? '').toString();
        final records = mat[roll] ?? {};
        if (sortedCols.isNotEmpty) {
          int presentCount = 0;
          for (var col in sortedCols) {
            if (records[col] == 'present') presentCount++;
          }
          pctMap[roll] = (presentCount / sortedCols.length) * 100;
        } else {
          pctMap[roll] = 0.0;
        }
      }

      setState(() {
        students = studentList;
        attendanceRaw = subjectRecords;
        dateColumns = sortedCols;
        matrixData = mat;
        studentPercentageMap = pctMap;
        loadingData = false;
      });
    } catch (e) {
      setState(() => loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptCode = (widget.user['dept_code'] ?? widget.user['dept_name'] ?? widget.user['department'] ?? 'CSE').toString();
    final deptId = widget.user['dept_id'] is int ? widget.user['dept_id'] as int : int.tryParse(widget.user['dept_id']?.toString() ?? '1') ?? 1;

    // Filter students by search or threshold
    final displayStudents = students.where((st) {
      final roll = (st['roll_no'] ?? '').toString();
      final name = (st['name'] ?? '').toString().toLowerCase();
      final pct = studentPercentageMap[roll] ?? 0.0;

      final matchesSearch = searchQuery.isEmpty ||
          name.contains(searchQuery.toLowerCase()) ||
          roll.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesThreshold = !widget.filterLowAttendanceOnly || pct < attendanceThreshold;

      return matchesSearch && matchesThreshold;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Attendance Register"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Academic Filter Box
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: AcademicFilterWidget(
                facultyDeptId: deptId,
                facultyDeptCode: deptCode,
                showDepartment: true,
                showSubject: true,
                facultyIdForSubjectFilter: widget.user['id'],
                onChanged: _onFilterChanged,
              ),
            ),
            const SizedBox(height: 12),

            if (selectedSubject != null) ...[
              // Search & Threshold Alert Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: "Search roll no. or name",
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        "< ${attendanceThreshold.toStringAsFixed(0)}% Alert",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (loadingData)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (selectedSubject == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    "Select Department, Year/Branch, Semester & Subject above to view attendance register.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (displayStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text("No attendance records found for this selection.", style: TextStyle(color: Colors.grey)),
                ),
              )
            else ...[
              // Swipe Helper Prompt
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Classes: ${dateColumns.length}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                    ),
                    Row(
                      children: [
                        Icon(Icons.swipe_left, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "Swipe dates horizontally ➔",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // PINNED COLUMNS ATTENDANCE REGISTER (Left Static | Middle Scrollable Dates | Right Static Total %)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PINNED LEFT COLUMNS (Roll No & Name — NON-MOVABLE)
                      Container(
                        width: 215,
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Column(
                          children: [
                            // Header Row
                            Container(
                              height: 44,
                              color: Colors.blue.shade50,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                children: const [
                                  SizedBox(
                                    width: 90,
                                    child: Text("Roll No", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor), textAlign: TextAlign.center),
                                  ),
                                  SizedBox(
                                    width: 115,
                                    child: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor)),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey.shade300),
                            // Student Rows
                            ...displayStudents.map((st) {
                              final roll = (st['roll_no'] ?? '').toString();
                              final name = (st['name'] ?? '').toString();
                              final pct = studentPercentageMap[roll] ?? 0.0;
                              final isLow = pct < attendanceThreshold;

                              return Container(
                                height: 44,
                                color: isLow ? Colors.red.shade50.withValues(alpha: 0.3) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text(roll, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                                    ),
                                    SizedBox(
                                      width: 115,
                                      child: Text(name, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      // 2. HORIZONTALLY SCROLLABLE DATES COLUMNS (Date1/P1, Date2/P2 ... — MOVABLE)
                      Expanded(
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                // Date Header Row
                                Container(
                                  height: 44,
                                  color: Colors.blue.shade50,
                                  child: Row(
                                    children: dateColumns.isEmpty
                                        ? [
                                            const SizedBox(
                                              width: 100,
                                              child: Center(child: Text("No Dates", style: TextStyle(fontSize: 11, color: Colors.grey))),
                                            )
                                          ]
                                        : dateColumns.map((col) => Container(
                                              width: 85,
                                              padding: const EdgeInsets.symmetric(horizontal: 2),
                                              child: Center(
                                                child: Text(
                                                  col,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: primaryColor),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )).toList(),
                                  ),
                                ),
                                Divider(height: 1, color: Colors.grey.shade300),
                                // Student Date Status Rows
                                ...displayStudents.map((st) {
                                  final roll = (st['roll_no'] ?? '').toString();
                                  final pct = studentPercentageMap[roll] ?? 0.0;
                                  final isLow = pct < attendanceThreshold;

                                  return Container(
                                    height: 44,
                                    color: isLow ? Colors.red.shade50.withValues(alpha: 0.3) : Colors.white,
                                    child: Row(
                                      children: dateColumns.isEmpty
                                          ? [
                                              const SizedBox(
                                                width: 100,
                                                child: Center(child: Text("-", style: TextStyle(color: Colors.grey))),
                                              )
                                            ]
                                          : dateColumns.map((col) {
                                              final status = matrixData[roll]?[col];
                                              final isPresent = status == 'present';
                                              final isRecorded = status != null;

                                              return SizedBox(
                                                width: 85,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: !isRecorded
                                                          ? Colors.grey.shade100
                                                          : isPresent
                                                              ? Colors.green.shade100
                                                              : Colors.red.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      !isRecorded
                                                          ? "-"
                                                          : isPresent
                                                              ? "P"
                                                              : "A",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: !isRecorded
                                                            ? Colors.grey
                                                            : isPresent
                                                                ? Colors.green.shade800
                                                                : Colors.red.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 3. PINNED RIGHT COLUMN (Total % — NON-MOVABLE)
                      Container(
                        width: 70,
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Column(
                          children: [
                            // Header Row
                            Container(
                              height: 44,
                              color: Colors.blue.shade50,
                              alignment: Alignment.center,
                              child: const Text("Total %", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green), textAlign: TextAlign.center),
                            ),
                            Divider(height: 1, color: Colors.grey.shade300),
                            // Student Total % Rows
                            ...displayStudents.map((st) {
                              final roll = (st['roll_no'] ?? '').toString();
                              final pct = studentPercentageMap[roll] ?? 0.0;
                              final isLow = pct < attendanceThreshold;

                              return Container(
                                height: 44,
                                color: isLow ? Colors.red.shade50.withValues(alpha: 0.3) : Colors.white,
                                alignment: Alignment.center,
                                child: Text(
                                  "${pct.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isLow ? Colors.red : Colors.green,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
