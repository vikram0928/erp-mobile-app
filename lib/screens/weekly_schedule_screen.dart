import 'package:flutter/material.dart';
import '../services/api_service.dart';

const primaryColor = Color(0xFF1D63D1);

class WeeklyScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const WeeklyScheduleScreen({super.key, required this.user});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  bool loading = true;
  String error = "";

  List<dynamic> timetableEntries = [];
  List<dynamic> uniqueSubjectEntries = [];
  Map<String, Map<int, dynamic>> gridMatrix = {}; // day -> period_no -> entry

  final ScrollController _horizontalScrollController = ScrollController();

  static const List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  static const List<int> periods = [1, 2, 3, 4, 5, 6];

  static const Map<int, String> timeSlots = {
    1: "09:00 - 09:50",
    2: "10:00 - 10:50",
    3: "11:00 - 11:50",
    4: "12:00 - 12:50",
    5: "02:00 - 02:50",
    6: "03:00 - 03:50",
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

  Future<void> loadSchedule() async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final facultyId = widget.user['id'] is int
          ? widget.user['id'] as int
          : int.tryParse(widget.user['id']?.toString() ?? '1') ?? 1;

      final all = await ApiService.getFacultyTimetable(facultyId);

      // Build grid matrix: day -> period_no -> entry
      final Map<String, Map<int, dynamic>> matrix = {};
      for (var d in days) {
        matrix[d] = {};
      }

      // Extract unique subjects for the lower detail table
      final Map<String, dynamic> uniqueMap = {};

      for (var entry in all) {
        final day = (entry['day_of_week'] ?? '').toString();
        final p = entry['period_no'] is int ? entry['period_no'] as int : int.tryParse(entry['period_no']?.toString() ?? '0') ?? 0;
        if (days.contains(day) && p > 0) {
          matrix[day]![p] = entry;
        }

        final subObj = entry['subject'] ?? entry;
        final code = (subObj['subject_code'] ?? entry['subject_code'] ?? '').toString();
        final key = code.isNotEmpty ? code : (entry['subject_id'] ?? entry['id']).toString();
        if (key.isNotEmpty && !uniqueMap.containsKey(key)) {
          uniqueMap[key] = entry;
        }
      }

      setState(() {
        timetableEntries = all;
        uniqueSubjectEntries = uniqueMap.values.toList();
        gridMatrix = matrix;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Could not load weekly schedule matrix.";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(child: Text(error, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: loadSchedule,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Header & Department Chip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Timetable Matrix", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  "Department: ${widget.user['dept_name'] ?? widget.user['dept_code'] ?? 'CSE'}",
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
                              child: const Text("Odd Semester", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Swipe Helper Prompt
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.swipe_left, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              "Swipe horizontally to view full week (Mon - Sat)",
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Matrix Table View (Screen 6 Layout) with Smooth Horizontal Scrollbar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Table(
                                  columnWidths: const {
                                    0: FixedColumnWidth(78),
                                    1: FixedColumnWidth(92),
                                    2: FixedColumnWidth(92),
                                    3: FixedColumnWidth(92),
                                    4: FixedColumnWidth(92),
                                    5: FixedColumnWidth(92),
                                    6: FixedColumnWidth(92),
                                  },
                                  border: TableBorder.all(color: Colors.grey.shade200),
                                  children: [
                                    // Table Header Row (Days)
                                    TableRow(
                                      decoration: BoxDecoration(color: Colors.blue.shade50),
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text("Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                                        ),
                                        ...days.map(
                                          (d) => Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor), textAlign: TextAlign.center),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Period Rows
                                    ...periods.map((p) {
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                            child: Text(
                                              timeSlots[p] ?? "P$p",
                                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          ...days.map((d) {
                                            final entry = gridMatrix[d]?[p];
                                            final hasClass = entry != null;

                                            final subObj = entry != null ? (entry['subject'] ?? entry) : null;
                                            final code = subObj != null ? (subObj['subject_code'] ?? entry?['subject_code'] ?? 'CS201') : '';
                                            final room = entry?['room'] ?? entry?['room_no'] ?? 'A-205';

                                            return Container(
                                              margin: const EdgeInsets.all(3),
                                              padding: const EdgeInsets.all(6),
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: hasClass ? _colorForSubject(code.toString()) : Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: hasClass
                                                  ? Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          code.toString(),
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          "$room",
                                                          style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.9)),
                                                        ),
                                                      ],
                                                    )
                                                  : const Center(
                                                      child: Text("-", style: TextStyle(color: Colors.grey, fontSize: 10)),
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
                        ),

                        const SizedBox(height: 24),

                        // Lower Information Table (Unique Subject Details List)
                        const Text("Subject & Room Details", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: uniqueSubjectEntries.isEmpty ? 1 : uniqueSubjectEntries.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, i) {
                              if (uniqueSubjectEntries.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text("No subject mappings found.", style: TextStyle(color: Colors.grey)),
                                );
                              }

                              final entry = uniqueSubjectEntries[i];
                              final subObj = entry['subject'] ?? entry;
                              final code = subObj['subject_code'] ?? entry['subject_code'] ?? 'CS201';
                              final name = subObj['subject_name'] ?? entry['subject_name'] ?? 'Data Structures';
                              final room = entry['room'] ?? entry['room_no'] ?? 'A-205';
                              final year = entry['year'] ?? subObj['year'] ?? '2nd Year';

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                                  child: Text("${i + 1}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor)),
                                ),
                                title: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text("Code: $code  |  Year: $year", style: const TextStyle(fontSize: 11)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text("Room $room", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Color _colorForSubject(String code) {
    final colors = [
      const Color(0xFF1D63D1),
      const Color(0xFF2E7D32),
      const Color(0xFFD84315),
      const Color(0xFF6A1B9A),
      const Color(0xFF00838F),
    ];
    final hash = code.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }
}