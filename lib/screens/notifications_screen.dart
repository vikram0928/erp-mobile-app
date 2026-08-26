import 'package:flutter/material.dart';
import '../services/api_service.dart';

const primaryColor = Color(0xFF3730A3);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notices = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotices();
  }

  Future<void> loadNotices() async {
    setState(() => loading = true);
    final data = await ApiService.getStudentNotifications();
    setState(() {
      notices = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mockNotices = [
      {
        "icon": Icons.calendar_month,
        "color": Colors.purple,
        "title": "Your next class is at 10:00 AM – Data Structures, P2",
        "time": "5 min ago",
        "unread": true,
      },
      {
        "icon": Icons.assignment_turned_in,
        "color": Colors.green,
        "title": "CT-1 marks have been uploaded for DBMS",
        "time": "1 hr ago",
        "unread": true,
      },
      {
        "icon": Icons.warning_amber_rounded,
        "color": Colors.orange,
        "title": "Your attendance is below the threshold in Mathematics",
        "time": "2 hrs ago",
        "unread": true,
      },
    ];

    final displayList = notices.isNotEmpty ? notices : mockNotices;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadNotices,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final n = displayList[index];
                  final title = n['title'] ?? n['notice_title'] ?? n['content'] ?? 'Notice';
                  final time = n['time'] ?? n['created_at'] ?? 'Today';
                  final isUnread = n['unread'] ?? true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_active, color: primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.toString(),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                time.toString(),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (isUnread == true)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
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
