import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../wedgets/academic_filter_widget.dart';
import 'student_detail_screen.dart';

const primaryColor = Color(0xFF1D63D1);

class StudentsListScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const StudentsListScreen({super.key, required this.user});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  AcademicFilterResult? filterResult;
  List<dynamic> students = [];
  List<dynamic> filteredStudents = [];
  String searchQuery = "";
  bool loading = false;
  String error = "";

  Future<void> _onFilterChanged(AcademicFilterResult result) async {
    setState(() {
      filterResult = result;
    });
    await loadStudents(result);
  }

  Future<void> loadStudents(AcademicFilterResult result) async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final data = await ApiService.getStudents(result.studentDeptId, result.year);
      setState(() {
        students = data;
        filteredStudents = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Could not load students for selected filter.";
        loading = false;
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

  @override
  Widget build(BuildContext context) {
    final deptCode = (widget.user['dept_code'] ?? widget.user['dept_name'] ?? widget.user['department'] ?? 'CSE').toString();
    final deptId = widget.user['dept_id'] is int ? widget.user['dept_id'] as int : int.tryParse(widget.user['dept_id']?.toString() ?? '1') ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Department -> Year/Branch -> Semester Filter Card (Screen 9 Layout)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: AcademicFilterWidget(
                facultyDeptId: deptId,
                facultyDeptCode: deptCode,
                showDepartment: true, // Shows Department selector dropdown
                showSubject: false,   // Students tab filters by Dept -> Year/Branch -> Semester
                onChanged: _onFilterChanged,
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: _applySearch,
                decoration: InputDecoration(
                  hintText: "Search student by name or roll no.",
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

            if (loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              )
            else if (filterResult == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    "Select Department, Year/Branch & Semester above to view student roster.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (filteredStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text("No students found in this class.", style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              // Student Card Roster (Screen 9 Layout)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
                  final name = student['name'] ?? 'Student';
                  final roll = student['roll_no'] ?? '';
                  final sNo = (index + 1).toString().padLeft(2, '0');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(sNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryColor.withValues(alpha: 0.1),
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        "Roll No: $roll",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: primaryColor),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(student: student),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}