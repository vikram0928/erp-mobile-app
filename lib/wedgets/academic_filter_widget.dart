import 'package:flutter/material.dart';
import '../services/api_service.dart';

const primaryColor = Color(0xFF1D63D1);

const Map<String, int> branchDeptIds = {
  "CSE": 1,
  "EE": 2,
  "EL": 3,
  "MN": 5,
};

class AcademicFilterResult {
  final int subjectDeptId;
  final int studentDeptId;
  final String year;
  final String semester;
  final dynamic subject;
  final dynamic department;

  AcademicFilterResult({
    required this.subjectDeptId,
    required this.studentDeptId,
    required this.year,
    required this.semester,
    this.subject,
    this.department,
  });
}

class AcademicFilterWidget extends StatefulWidget {
  final int facultyDeptId;
  final String facultyDeptCode;
  final bool showDepartment;
  final bool showSubject;
  final int? facultyIdForSubjectFilter;
  final void Function(AcademicFilterResult) onChanged;

  const AcademicFilterWidget({
    super.key,
    required this.facultyDeptId,
    required this.facultyDeptCode,
    required this.onChanged,
    this.showDepartment = false,
    this.showSubject = true,
    this.facultyIdForSubjectFilter,
  });

  @override
  State<AcademicFilterWidget> createState() => _AcademicFilterWidgetState();
}

class _AcademicFilterWidgetState extends State<AcademicFilterWidget> {
  static const years = ["Y2", "Y3", "Y4"];
  static const branches = ["CSE", "EE", "EL", "MN"];

  List<dynamic> departments = [];
  dynamic selectedDepartment;
  bool loadingDepartments = false;

  late int currentDeptId;
  late String currentDeptCode;

  String? selectedYearOrBranch;
  String? selectedSemester;
  dynamic selectedSubject;
  List<dynamic> subjects = [];
  bool loadingSubjects = false;

  @override
  void initState() {
    super.initState();
    currentDeptId = widget.facultyDeptId;
    currentDeptCode = widget.facultyDeptCode;

    if (widget.showDepartment) {
      _loadDepartments();
    }
  }

  Future<void> _loadDepartments() async {
    setState(() => loadingDepartments = true);
    try {
      final data = await ApiService.getDepartments();
      setState(() {
        departments = data;
        loadingDepartments = false;
        if (data.isNotEmpty) {
          selectedDepartment = data.firstWhere(
            (d) => (d['id'] == widget.facultyDeptId || d['dept_code'] == widget.facultyDeptCode),
            orElse: () => data.first,
          );
          if (selectedDepartment != null) {
            currentDeptId = selectedDepartment['id'] ?? widget.facultyDeptId;
            currentDeptCode = (selectedDepartment['dept_code'] ?? selectedDepartment['code'] ?? widget.facultyDeptCode).toString();
          }
        }
      });
    } catch (_) {
      setState(() => loadingDepartments = false);
    }
  }

  bool get isBranchMode {
    final code = currentDeptCode.toUpperCase();
    return code == "AS" || code == "APPLIED SCIENCES" || code == "APPLIED SCIENCE";
  }

  void _onDepartmentChanged(dynamic dept) {
    setState(() {
      selectedDepartment = dept;
      currentDeptId = dept['id'] ?? widget.facultyDeptId;
      currentDeptCode = (dept['dept_code'] ?? dept['code'] ?? widget.facultyDeptCode).toString();
      selectedYearOrBranch = null;
      selectedSemester = null;
      selectedSubject = null;
      subjects = [];
    });
  }

  void _onYearOrBranchChanged(String value) {
    setState(() {
      selectedYearOrBranch = value;
      selectedSemester = null;
      selectedSubject = null;
      subjects = [];
    });
  }

  void _onSemesterChanged(String value) {
    setState(() {
      selectedSemester = value;
      selectedSubject = null;
    });
    if (widget.showSubject) {
      _loadSubjects();
    } else {
      _emitChange();
    }
  }

  Future<void> _loadSubjects() async {
    if (!widget.showSubject || selectedYearOrBranch == null || selectedSemester == null) return;

    setState(() => loadingSubjects = true);

    final subjectDeptId = currentDeptId;
    final year = isBranchMode ? "Y1" : selectedYearOrBranch!;

    try {
      var url = "${ApiService.baseUrl}/subjects?dept_id=$subjectDeptId&year=$year&semester=$selectedSemester";
      if (widget.facultyIdForSubjectFilter != null) {
        url += "&faculty_id=${widget.facultyIdForSubjectFilter}";
      }
      final data = await ApiService.getRaw(url);
      setState(() {
        subjects = data;
        loadingSubjects = false;
      });
    } catch (e) {
      setState(() => loadingSubjects = false);
    }
  }

  void _emitChange() {
    if (selectedYearOrBranch == null || selectedSemester == null) return;

    final subjectDeptId = currentDeptId;
    final studentDeptId =
        isBranchMode ? (branchDeptIds[selectedYearOrBranch] ?? currentDeptId) : currentDeptId;
    final year = isBranchMode ? "Y1" : selectedYearOrBranch!;

    widget.onChanged(AcademicFilterResult(
      subjectDeptId: subjectDeptId,
      studentDeptId: studentDeptId,
      year: year,
      semester: selectedSemester!,
      subject: selectedSubject,
      department: selectedDepartment,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final step1Options = isBranchMode ? branches : years;
    final step1Label = isBranchMode ? "Sub Branch" : "Year";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showDepartment) ...[
          const Text("Department", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (loadingDepartments)
            const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
          else
            DropdownButtonFormField<dynamic>(
              initialValue: selectedDepartment,
              hint: const Text("Select Department"),
              items: departments
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text("${d['dept_name'] ?? d['name']} (${d['dept_code'] ?? d['code'] ?? ''})"),
                      ))
                  .toList(),
              onChanged: _onDepartmentChanged,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          const SizedBox(height: 14),
        ],

        Text(step1Label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedYearOrBranch,
          hint: Text("Select $step1Label"),
          items: step1Options
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v != null) _onYearOrBranchChanged(v);
          },
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        const Text("Semester", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedSemester,
          hint: const Text("Select Semester"),
          items: const [
            DropdownMenuItem(value: "odd", child: Text("Odd Semester")),
            DropdownMenuItem(value: "even", child: Text("Even Semester")),
          ],
          onChanged: selectedYearOrBranch == null
              ? null
              : (v) {
                  if (v != null) _onSemesterChanged(v);
                },
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),

        if (widget.showSubject) ...[
          const SizedBox(height: 14),
          const Text("Subject", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (loadingSubjects)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else
            DropdownButtonFormField<dynamic>(
              initialValue: selectedSubject,
              hint: const Text("Select Subject"),
              items: subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text("${s['subject_name']} (${s['subject_code']})")))
                  .toList(),
              onChanged: (selectedSemester == null || subjects.isEmpty)
                  ? null
                  : (v) {
                      setState(() => selectedSubject = v);
                      _emitChange();
                    },
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
        ],
      ],
    );
  }
}