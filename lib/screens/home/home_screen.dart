import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'NAVI',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            const Center(
              child: Text(
                'HI',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "TODAY'S PROGRESS",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final habits = [
                    ('Work Out', '#1', 5),
                    ('Read', '#2', 12),
                    ('Meditate', '#3', 3),
                  ];
                  final (name, icon, streak) = habits[i];
                  return _HabitCard(
                    icon: icon,
                    name: name,
                    streak: streak,
                    done: i == 2,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final String icon;
  final String name;
  final int streak;
  final bool done;

  const _HabitCard({
    required this.icon,
    required this.name,
    required this.streak,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done ? Colors.white38 : Colors.grey.shade700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                color: done ? Colors.white : Colors.grey,
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: done ? Colors.white : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Streak', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: TextStyle(
                  fontSize: 12,
                  color: streak > 0 ? Colors.orange.shade300 : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
