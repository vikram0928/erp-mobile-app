import 'package:flutter/material.dart';
import '../services/api_service.dart';

const primaryColor = Color(0xFF3730A3);

class StudentScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentScheduleScreen({super.key, required this.student});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  bool loading = true;
  List<dynamic> timetableEntries = [];
  List<dynamic> uniqueSubjectEntries = [];
  Map<String, Map<int, dynamic>> gridMatrix = {}; // day -> period_no -> entry

  final ScrollController _horizontalScrollController = ScrollController();

  static const List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  static const List<int> periods = [1, 2, 3, 4, 5, 6, 7];

  static const Map<int, String> periodTimeHeaders = {
    1: "P1\n09:00",
    2: "P2\n10:00",
    3: "P3\n11:00",
    4: "P4\n12:00",
    5: "P5\n02:00",
    6: "P6\n03:00",
    7: "P7\n04:00",
  };

  @override
  void initState() {
    super.initState();
    loadSchedule();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  String _getShortSubjectName(dynamic entry) {
    if (entry == null) return "-";
    final subObj = entry is Map ? (entry['subject'] ?? entry) : entry;
    if (subObj is! Map) return "-";

    final name = (subObj['subject_name'] ?? subObj['name'] ?? '').toString();
    final code = (subObj['subject_code'] ?? subObj['code'] ?? '').toString();

    final lower = name.toLowerCase();

    // --- Your actual subjects ---
    if (lower.contains("dbms lab") || lower.contains("database management system lab")) return "DBMS\nLAB";
    if (lower.contains("daa lab") || lower.contains("design and analysis of algorithm lab")) return "DAA\nLAB";
    if (lower.contains("web t lab") || lower.contains("web technology lab")) return "WEB\nLAB";
    if (lower.contains("mini project") || lower.contains("mini p")) return "MINI\nPROJ";
    if (lower.contains("database") || lower.contains("dbms")) return "DBMS";
    if (lower.contains("daa") || lower.contains("design and analysis")) return "DAA";
    if (lower.contains("machine learning") || lower.contains(" ml") || lower == "ml") return "ML";
    if (lower.contains("web technology") || lower.contains("web t")) return "WEB T";
    if (lower.contains("object oriented") || lower.contains("oop") || lower.contains("c++")) return "OOP";
    if (lower.contains("constitution") || lower.contains("costi")) return "COSTI";
    // --- Common fallbacks ---
    if (lower.contains("data structure")) return "DS";
    if (lower.contains("mathematics") || lower.contains("math")) return "MATH";
    if (lower.contains("physics")) return "PHY";
    if (lower.contains("network")) return "CN";
    if (lower.contains("operating system")) return "OS";
    if (lower.contains("algorithm")) return "ALGO";

    if (code.isNotEmpty) return code.length <= 6 ? code : code.substring(0, 6);
    if (name.isNotEmpty) {
      if (name.length <= 6) return name.toUpperCase();
      final words = name.split(' ');
      if (words.length > 1) {
        return words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
      }
      return name.substring(0, 4).toUpperCase();
    }
    return "-";
  }

  Future<void> loadSchedule() async {
    setState(() => loading = true);

    try {
      final deptId = widget.student['dept_id'] ?? widget.student['department']?['id'] ?? 1;
      final year = widget.student['current_year'] ?? widget.student['year'] ?? "Y3";

      final rawTimetable = await ApiService.getRaw("${ApiService.baseUrl}/timetables?dept_id=$deptId&year=$year");

      final Map<String, Map<int, dynamic>> matrix = {};
      for (var d in days) {
        matrix[d] = {};
      }

      final Map<String, dynamic> uniqueMap = {};

      if (rawTimetable.isNotEmpty) {
        for (var entry in rawTimetable) {
          if (entry is! Map) continue;
          final day = (entry['day_of_week'] ?? '').toString();
          final p = entry['period_no'] is int
              ? entry['period_no'] as int
              : int.tryParse(entry['period_no']?.toString() ?? '0') ?? 0;
          if (days.contains(day) && p >= 1 && p <= 7) {
            matrix[day]![p] = entry;
          }

          final subObj = entry['subject'] ?? entry;
          final code = (subObj['subject_code'] ?? entry['subject_code'] ?? '').toString();
          final key = code.isNotEmpty ? code : (entry['subject_id'] ?? entry['id'] ?? '').toString();
          if (key.isNotEmpty && !uniqueMap.containsKey(key)) {
            uniqueMap[key] = entry;
          }
        }
      }

      // Default mock fallback schedule using your actual subjects
      if (uniqueMap.isEmpty) {
        final mockSubjects = [
          {"code": "CSE401", "name": "Database Management System",        "short": "DBMS",       "faculty": "Mr. Verma"},
          {"code": "CSE402", "name": "Design and Analysis of Algorithms",   "short": "DAA",        "faculty": "Ms. Sharma"},
          {"code": "CSE403", "name": "Machine Learning",                    "short": "ML",         "faculty": "Dr. Mehta"},
          {"code": "CSE404", "name": "Web Technology",                      "short": "WEB T",      "faculty": "Mr. Singh"},
          {"code": "CSE405", "name": "Object Oriented Programming / C++",   "short": "OOP",        "faculty": "Ms. Gupta"},
          {"code": "CSE406", "name": "Constitution of India",               "short": "COSTI",      "faculty": "Dr. Kumar"},
          {"code": "CSE407", "name": "DAA Lab",                             "short": "DAA LAB",    "faculty": "Ms. Sharma"},
          {"code": "CSE408", "name": "DBMS Lab",                            "short": "DBMS LAB",   "faculty": "Mr. Verma"},
          {"code": "CSE409", "name": "Mini Project",                        "short": "MINI PROJ",  "faculty": "Mr. Rajput"},
          {"code": "CSE410", "name": "Web Technology Lab",                  "short": "WEB LAB",    "faculty": "Mr. Singh"},
        ];

        for (var s in mockSubjects) {
          uniqueMap[s['code']!] = s;
        }

        // Realistic weekly timetable: Rows = Days, Columns = Periods (P1-P7)
        // Theory subjects in P1-P4, Labs/Project in P5-P7
        final weekSchedule = {
          "Mon": {1: "DBMS", 2: "DAA",  3: "ML",   4: "WEB T",    5: "DAA LAB",   6: "DAA LAB",  7: "-"},
          "Tue": {1: "OOP",  2: "DBMS", 3: "DAA",  4: "COSTI",    5: "DBMS LAB",  6: "DBMS LAB", 7: "-"},
          "Wed": {1: "ML",   2: "WEB T",3: "OOP",  4: "DBMS",     5: "WEB LAB",   6: "WEB LAB",  7: "-"},
          "Thu": {1: "DAA",  2: "ML",   3: "COSTI",4: "OOP",      5: "MINI PROJ", 6: "MINI PROJ",7: "MINI PROJ"},
          "Fri": {1: "WEB T",2: "OOP",  3: "DBMS", 4: "DAA",      5: "-",         6: "-",        7: "-"},
          "Sat": {1: "ML",   2: "COSTI",3: "WEB T",4: "-",         5: "-",         6: "-",        7: "-"},
        };

        for (var day in days) {
          final dayPeriods = weekSchedule[day] ?? {};
          for (var p in periods) {
            final short = dayPeriods[p] ?? "-";
            if (short == "-") continue;
            final matched = mockSubjects.firstWhere(
              (s) => s['short'] == short,
              orElse: () => <String, String>{},
            );
            if (matched.isNotEmpty) {
              matrix[day]![p] = {
                "subject_code": matched['code'],
                "subject_name": matched['name'],
                "faculty_name": matched['faculty'],
                "short": matched['short'],
              };
            }
          }
        }
      }

      setState(() {
        timetableEntries = rawTimetable;
        uniqueSubjectEntries = uniqueMap.values.toList();
        gridMatrix = matrix;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptName = widget.student['department']?['name'] ??
        widget.student['department']?['code'] ??
        widget.student['dept_name'] ??
        'CSE';
    final currentYear = widget.student['current_year'] ?? widget.student['year'] ?? '3rd Year';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Weekly Schedule"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: loadSchedule,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Timetable Matrix",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Department: $deptName",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$currentYear",
                              style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Swipe Helper Prompt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.swipe_left, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "Swipe horizontally for periods P1-P7 ➔",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Timetable Matrix: Rows = Days, Columns = Periods (P1-P7)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Table(
                            columnWidths: const {
                              0: FixedColumnWidth(68), // Days Column (Row Header)
                              1: FixedColumnWidth(84), // P1
                              2: FixedColumnWidth(84), // P2
                              3: FixedColumnWidth(84), // P3
                              4: FixedColumnWidth(84), // P4
                              5: FixedColumnWidth(84), // P5
                              6: FixedColumnWidth(84), // P6
                              7: FixedColumnWidth(84), // P7
                            },
                            border: TableBorder.all(color: Colors.grey.shade200),
                            children: [
                              // Table Header Row: Columns = Periods (P1 ... P7)
                              TableRow(
                                decoration: BoxDecoration(color: Colors.blue.shade50),
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      "Day",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  ...periods.map(
                                    (p) => Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Text(
                                        periodTimeHeaders[p] ?? "P$p",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Table Body Rows: Rows = Days (Mon, Tue, Wed, Thu, Fri, Sat)
                              ...days.map((d) {
                                return TableRow(
                                  children: [
                                    // Day Name (Row Label)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                                      child: Text(
                                        d,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    // Periods P1 to P7 Elements for this Day
                                    ...periods.map((p) {
                                      final entry = gridMatrix[d]?[p];
                                      final hasClass = entry != null;
                                      final shortName = _getShortSubjectName(entry);

                                      return Container(
                                        margin: const EdgeInsets.all(3),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: hasClass && shortName != "-"
                                              ? primaryColor
                                              : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: hasClass && shortName != "-"
                                            ? Center(
                                                child: Text(
                                                  shortName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              )
                                            : const Center(
                                                child: Text(
                                                  "-",
                                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                              ),
                                      );
                                    }),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Subject Legend Table
                    const Text("Subject Mappings", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < uniqueSubjectEntries.length; i++) ...[
                            _buildSubjectTile(uniqueSubjectEntries[i], i + 1),
                            if (i < uniqueSubjectEntries.length - 1)
                              Divider(height: 1, color: Colors.grey.shade100),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSubjectTile(dynamic entry, int index) {
    if (entry is! Map) {
      return const SizedBox.shrink();
    }
    final subObj = entry['subject'] ?? entry;
    final code = (subObj['subject_code'] ?? entry['code'] ?? 'CSE301').toString();
    final name = (subObj['subject_name'] ?? entry['name'] ?? 'Data Structures').toString();
    final shortName = _getShortSubjectName(entry);

    String faculty = 'Faculty';
    if (entry['faculty'] is Map) {
      faculty = (entry['faculty']['name'] ?? 'Faculty').toString();
    } else if (entry['faculty_name'] != null) {
      faculty = entry['faculty_name'].toString();
    } else if (entry['faculty'] is String) {
      faculty = entry['faculty'].toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              shortName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  "Code: $code",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            faculty,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
