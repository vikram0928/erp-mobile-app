import 'package:flutter/material.dart';
import '../services/api_service.dart';

const primaryColor = Color(0xFF3730A3);

class StudentTodayClassesScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentTodayClassesScreen({super.key, required this.student});

  @override
  State<StudentTodayClassesScreen> createState() => _StudentTodayClassesScreenState();
}

class _StudentTodayClassesScreenState extends State<StudentTodayClassesScreen> {
  bool loading = true;
  List<dynamic> todayClasses = [];

  static const Map<int, String> weekdayMap = {
    1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun"
  };

  @override
  void initState() {
    super.initState();
    loadTodayClasses();
  }

  Future<void> loadTodayClasses() async {
    setState(() => loading = true);
    final dayStr = weekdayMap[DateTime.now().weekday] ?? "Mon";

    try {
      final deptId = widget.student['dept_id'] ?? widget.student['department']?['id'] ?? 1;
      final year = widget.student['current_year'] ?? widget.student['year'] ?? "Y3";

      final rawTimetable = await ApiService.getRaw("${ApiService.baseUrl}/timetables?dept_id=$deptId&year=$year");
      final dayList = rawTimetable.where((e) => (e['day_of_week'] ?? '').toString().toLowerCase() == dayStr.toLowerCase()).toList();

      dayList.sort((a, b) => (a['period_no'] ?? 0).compareTo(b['period_no'] ?? 0));

      setState(() {
        todayClasses = dayList;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Today Classes"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadTodayClasses,
              child: todayClasses.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                "No classes scheduled for today.",
                                style: TextStyle(color: Colors.grey, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: todayClasses.length,
                      itemBuilder: (context, index) {
                        final item = todayClasses[index];

                        final subObj = item['subject'] ?? item;
                        final name = subObj['subject_name'] ?? item['name'] ?? '-';
                        final code = subObj['subject_code'] ?? item['code'] ?? '-';
                        final period = "P${item['period_no'] ?? (index + 1)}";

                        // Room number
                        var rawRoom = (item['room'] ?? item['room_no'] ?? '-').toString();
                        if (rawRoom != '-' && !rawRoom.toLowerCase().startsWith('room')) {
                          rawRoom = "Room: $rawRoom";
                        }

                        // Faculty name
                        String facultyName = '-';
                        if (item['faculty'] is Map) {
                          facultyName = (item['faculty']['name'] ?? item['faculty']['faculty_name'] ?? '-').toString();
                        } else if (item['faculty_name'] != null && item['faculty_name'].toString().isNotEmpty) {
                          facultyName = item['faculty_name'].toString();
                        } else if (item['faculty'] is String && item['faculty'].toString().isNotEmpty) {
                          facultyName = item['faculty'].toString();
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
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
                                        Text(
                                          name.toString(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          code.toString(),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      period,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Divider(height: 1, color: Colors.grey.shade100),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.meeting_room_outlined, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        rawRoom,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: primaryColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        facultyName,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
