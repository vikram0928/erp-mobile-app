import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../wedgets/academic_filter_widget.dart';

const primaryColor = Color(0xFF1D63D1);

class CtMarksScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CtMarksScreen({super.key, required this.user});

  @override
  State<CtMarksScreen> createState() => _CtMarksScreenState();
}

class _CtMarksScreenState extends State<CtMarksScreen> with SingleTickerProviderStateMixin {
  late TabController tabController;

  AcademicFilterResult? filterResult;
  dynamic selectedSubject;
  int ctNumber = 1;
  double maxMarks = 20;
  List<dynamic> students = [];
  Map<int, TextEditingController> markControllers = {};

  bool loadingStudents = false;
  bool submitting = false;

  List<dynamic> viewMarks = [];
  bool loadingView = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    for (var c in markControllers.values) {
      c.dispose();
    }
    super.dispose();
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
      students = [];
      markControllers = {};
    });

    try {
      final data = await ApiService.getStudents(result.studentDeptId, result.year);
      setState(() {
        students = data;
        for (var s in data) {
          markControllers[s['id']] = TextEditingController();
        }
        loadingStudents = false;
      });
    } catch (e) {
      setState(() => loadingStudents = false);
    }
  }

  Future<void> submitMarks() async {
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a subject first.")),
      );
      return;
    }

    setState(() => submitting = true);

    final records = students
        .where((s) => markControllers[s['id']]!.text.trim().isNotEmpty)
        .map((s) => {
              "student_id": s['id'],
              "marks_obtained": double.tryParse(markControllers[s['id']]!.text.trim()) ?? 0,
            })
        .toList();

    if (records.isEmpty) {
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter marks for at least one student.")),
      );
      return;
    }

    final result = await ApiService.submitCtMarks(
      subjectId: selectedSubject['id'] ?? selectedSubject['subject_id'] ?? 1,
      ctNumber: ctNumber,
      maxMarks: maxMarks,
      academicYear: "2026-27",
      uploadedBy: widget.user['id'],
      records: records,
    );

    setState(() => submitting = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? "Marks saved successfully! ✅")),
    );

    if (result['success'] == true) {
      for (var c in markControllers.values) {
        c.clear();
      }
    }
  }

  Future<void> loadViewMarks() async {
    setState(() => loadingView = true);
    try {
      final data = await ApiService.getCtMarks();
      setState(() {
        viewMarks = data;
        loadingView = false;
      });
    } catch (e) {
      setState(() => loadingView = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptCode = (widget.user['dept_code'] ?? widget.user['dept_name'] ?? widget.user['department'] ?? 'CSE').toString();
    final deptId = widget.user['dept_id'] is int ? widget.user['dept_id'] as int : int.tryParse(widget.user['dept_id']?.toString() ?? '1') ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("CT Marks"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: tabController,
          indicatorColor: Colors.white,
          onTap: (i) {
            if (i == 1) loadViewMarks();
          },
          tabs: const [
            Tab(text: "Upload"),
            Tab(text: "View Marks"),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          // Upload Tab
          SingleChildScrollView(
            child: Column(
              children: [
                // Top Academic Filter Card
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

                // CT Config Card (CT1, CT2, CT3 & Max Marks)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Test / Exam", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              initialValue: ctNumber,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text("CT 1")),
                                DropdownMenuItem(value: 2, child: Text("CT 2")),
                                DropdownMenuItem(value: 3, child: Text("CT 3 / CTE")),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => ctNumber = v);
                              },
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Max Marks", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: maxMarks.toInt().toString(),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final d = double.tryParse(v);
                                if (d != null) setState(() => maxMarks = d);
                              },
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                if (loadingStudents)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (students.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        "Select Year/Branch, Semester, and Subject to load student marks entry list.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else ...[
                  // Student Marks Entry Table / List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final sId = student['id'] as int;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    student['roll_no'] ?? '',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: markControllers[sId],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: "/${maxMarks.toInt()}",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Save Marks Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: submitting ? null : submitMarks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Save Marks", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // View Marks Tab
          loadingView
              ? const Center(child: CircularProgressIndicator())
              : viewMarks.isEmpty
                  ? const Center(child: Text("No CT Marks recorded yet.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: viewMarks.length,
                      itemBuilder: (context, i) {
                        final m = viewMarks[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: ListTile(
                              title: Text(m['student_name'] ?? 'Student Marks'),
                              subtitle: Text("Roll: ${m['roll_no'] ?? '-'}  |  CT: ${m['ct_number'] ?? '1'}"),
                              trailing: Text(
                                "${m['marks_obtained'] ?? 0} / ${m['max_marks'] ?? 20}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}