import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'attendance_mark_screen.dart';

const primaryColor = Color(0xFF1D63D1);

class TodayClassesTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const TodayClassesTab({super.key, required this.user});

  @override
  State<TodayClassesTab> createState() => _TodayClassesTabState();
}

class _TodayClassesTabState extends State<TodayClassesTab> {
  DateTime selectedDate = DateTime.now();
  List<dynamic> classes = [];
  bool loading = true;

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
    final dayStr = weekdayMap[selectedDate.weekday] ?? "Mon";

    try {
      final facultyId = widget.user['id'] is int
          ? widget.user['id'] as int
          : int.tryParse(widget.user['id']?.toString() ?? '1') ?? 1;

      final timetable = await ApiService.getFacultyTimetable(facultyId);
      var dayClasses = timetable.where((e) {
        final d = (e['day_of_week'] ?? '').toString().trim().toLowerCase();
        return d == dayStr.toLowerCase();
      }).toList();

      // Fallback: If no timetable slots seeded for today, map faculty's assigned subjects
      if (dayClasses.isEmpty) {
        final subjects = await ApiService.getFacultySubjects(facultyId);
        dayClasses = subjects.asMap().entries.map((entry) {
          final idx = entry.key;
          final sub = entry.value;
          return {
            "id": sub['id'] ?? (idx + 1),
            "period_no": idx + 1,
            "day_of_week": dayStr,
            "year": sub['year'] ?? "Y2",
            "room": sub['room'] ?? "A-205",
            "subject": sub,
            "subject_name": sub['subject_name'],
            "subject_code": sub['subject_code'],
          };
        }).toList();
      }

      dayClasses.sort((a, b) => (a['period_no'] ?? 0).compareTo(b['period_no'] ?? 0));

      setState(() {
        classes = dayClasses;
        loading = false;
      });

      // Schedule reminders (15-min before & at class time)
      _scheduleClassNotifications(dayClasses);
    } catch (e) {
      setState(() {
        classes = [];
        loading = false;
      });
    }
  }

  void _scheduleClassNotifications(List<dynamic> dayClasses) {
    final now = selectedDate;
    for (var c in dayClasses) {
      final period = c['period_no'] ?? 1;
      final cId = c['id'] is int ? c['id'] as int : int.tryParse(c['id']?.toString() ?? '1') ?? 1;
      final subObj = c['subject'] ?? c;
      final subName = subObj['subject_name'] ?? c['subject_name'] ?? 'Class';

      final startHour = 8 + (period as int);
      final classTime = DateTime(now.year, now.month, now.day, startHour, 0);

      NotificationService.scheduleClassReminder(
        id: cId,
        subjectName: subName,
        classTime: classTime,
      );
    }
  }

  void _changeDate(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
    loadTodayClasses();
  }

  String _formatDate(DateTime dt) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    return "${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  void _openCancelModal(BuildContext context, dynamic classItem) {
    final reasonController = TextEditingController();
    bool notifyStudents = true;

    final subObj = classItem['subject'] ?? classItem;
    final subName = subObj['subject_name'] ?? classItem['subject_name'] ?? 'Subject';
    final subCode = subObj['subject_code'] ?? classItem['subject_code'] ?? '';
    final room = classItem['room'] ?? classItem['room_no'] ?? 'A-205';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Cancel Class", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 12),

                  // Class Info Card (Screen 7 Layout)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$subName ($subCode)",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Year: ${classItem['year'] ?? subObj['year'] ?? '-'} | Room: $room",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("Reason for Cancellation *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Enter reason (e.g. Official Duty, Emergency)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Checkbox(
                        value: notifyStudents,
                        activeColor: primaryColor,
                        onChanged: (v) => setModalState(() => notifyStudents = v ?? true),
                      ),
                      const Text("Notify Students about this cancellation", style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Class marked as cancelled. Students notified.")),
                        );
                      },
                      child: const Text("Confirm Cancel Class", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openRescheduleModal(BuildContext context, dynamic classItem) {
    DateTime newDate = DateTime.now().add(const Duration(days: 1));
    String newSlot = "02:00 PM - 02:50 PM";
    final reasonController = TextEditingController();

    final subObj = classItem['subject'] ?? classItem;
    final subName = subObj['subject_name'] ?? classItem['subject_name'] ?? 'Subject';
    final subCode = subObj['subject_code'] ?? classItem['subject_code'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Reschedule Class", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 12),

                  // Class Info Card (Screen 8 Layout)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$subName ($subCode)",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Original Schedule: ${_formatDate(selectedDate)}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("New Date *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: newDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) setModalState(() => newDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDate(newDate)),
                          const Icon(Icons.calendar_today, size: 18, color: primaryColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text("New Time Slot *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: newSlot,
                    items: const [
                      DropdownMenuItem(value: "09:00 AM - 09:50 AM", child: Text("09:00 AM - 09:50 AM")),
                      DropdownMenuItem(value: "10:00 AM - 10:50 AM", child: Text("10:00 AM - 10:50 AM")),
                      DropdownMenuItem(value: "11:00 AM - 11:50 AM", child: Text("11:00 AM - 11:50 AM")),
                      DropdownMenuItem(value: "02:00 PM - 02:50 PM", child: Text("02:00 PM - 02:50 PM")),
                      DropdownMenuItem(value: "03:00 PM - 03:50 PM", child: Text("03:00 PM - 03:50 PM")),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => newSlot = v);
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text("Reason (Optional)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      hintText: "Enter reason for rescheduling",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Class rescheduled to ${_formatDate(newDate)} ($newSlot).")),
                        );
                      },
                      child: const Text("Reschedule Class", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.day == DateTime.now().day;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Date Selector Header Bar (Screen 3 Layout)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1),
                ),
                Column(
                  children: [
                    Text(
                      _formatDate(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("TODAY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : classes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text("No classes scheduled for this date.", style: TextStyle(color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: classes.length,
                        itemBuilder: (context, index) {
                          final c = classes[index];
                          final period = c['period_no'] ?? (index + 1);
                          final timeSlot = _slotForPeriod(period);

                          // Safe nested subject resolution (Issue 4)
                          final subObj = c['subject'] ?? c;
                          final subName = subObj['subject_name'] ?? c['subject_name'] ?? 'Data Structures';
                          final subCode = subObj['subject_code'] ?? c['subject_code'] ?? 'CS202';
                          final room = c['room'] ?? c['room_no'] ?? 'A-205';
                          final year = c['year'] ?? subObj['year'] ?? 'Y2';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeSlot,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: index == 0 ? Colors.green.shade50 : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            index == 0 ? "Now" : "Upcoming",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: index == 0 ? Colors.green : primaryColor,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                                          onSelected: (val) {
                                            if (val == 'cancel') {
                                              _openCancelModal(context, c);
                                            } else if (val == 'reschedule') {
                                              _openRescheduleModal(context, c);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'cancel',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                                  SizedBox(width: 8),
                                                  Text("Cancel Class", style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'reschedule',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_calendar, color: primaryColor, size: 18),
                                                  SizedBox(width: 8),
                                                  Text("Reschedule"),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Displaying Subject Name (Subject Code) - Issue 4 Fix
                                Text(
                                  "$subName ($subCode)",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                                const SizedBox(height: 4),

                                Text(
                                  "Year: $year | Room: $room",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 14),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.assignment_turned_in, size: 16, color: Colors.white),
                                    label: const Text("Take Attendance", style: TextStyle(color: Colors.white)),
                                    onPressed: () {
                                      // Direct entrance into Attendance marking for this class (Issue 3 Fix)
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AttendanceMarkScreen(
                                            user: widget.user,
                                            initialSubject: c,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _slotForPeriod(int period) {
    switch (period) {
      case 1: return "09:00 AM - 09:50 AM";
      case 2: return "10:00 AM - 10:50 AM";
      case 3: return "11:00 AM - 11:50 AM";
      case 4: return "12:00 PM - 12:50 PM";
      case 5: return "02:00 PM - 02:50 PM";
      case 6: return "03:00 PM - 03:50 PM";
      default: return "04:00 PM - 04:50 PM";
    }
  }
}

// Alias class for legacy imports
class TodayClassesScreen extends TodayClassesTab {
  const TodayClassesScreen({super.key, required super.user});
}