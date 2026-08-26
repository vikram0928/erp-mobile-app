import 'package:flutter/material.dart';

const primaryColor = Color(0xFF1D63D1);

class FacultyHomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final ValueChanged<int> onNavigate;

  const FacultyHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'Faculty';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          Text(
            'Hello Mr. $name',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Welcome back',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 28),

          _homeCard(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Attendance Sheet',
            subtitle: 'Take, view and edit attendance',
            onTap: () {
              // Next step: Attendance Sheet page.
            },
          ),

          const SizedBox(height: 14),

          _homeCard(
            context,
            icon: Icons.edit_note_outlined,
            title: 'CT Marks',
            subtitle: 'Upload, view and update CT marks',
            onTap: () {
              // Next step: CT Marks page.
            },
          ),

          const SizedBox(height: 14),

          _homeCard(
            context,
            icon: Icons.analytics_outlined,
            title: 'Overview',
            subtitle: 'Attendance and academic insights',
            onTap: () {
              // Next step: Overview page.
            },
          ),

          const SizedBox(height: 28),

          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _quickCard(
                  icon: Icons.today,
                  title: 'Today Classes',
                  onTap: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickCard(
                  icon: Icons.calendar_month,
                  title: 'Schedule',
                  onTap: () => onNavigate(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _homeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.dashboard_outlined,
                color: primaryColor,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}