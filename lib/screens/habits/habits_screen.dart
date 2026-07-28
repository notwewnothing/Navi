import 'package:flutter/material.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

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
            const SizedBox(height: 40),
            Text(
              'HABITS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 12),
            ...habits.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HabitCard(
                  icon: h.icon,
                  name: h.name,
                  streak: h.streak,
                  done: h.done,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitData {
  final String icon;
  final String name;
  final int streak;
  final bool done;
  const _HabitData({
    required this.icon,
    required this.name,
    required this.streak,
    required this.done,
  });
}

final habits = [
  const _HabitData(icon: 'W', name: 'Work Out', streak: 5, done: false),
  const _HabitData(icon: 'R', name: 'Read', streak: 12, done: true),
  const _HabitData(icon: 'M', name: 'Meditate', streak: 3, done: false),
  const _HabitData(icon: 'C', name: 'Code', streak: 8, done: true),
  const _HabitData(icon: 'H', name: 'Hydrate', streak: 15, done: false),
  const _HabitData(icon: 'L', name: 'Walk', streak: 4, done: false),
  const _HabitData(icon: 'J', name: 'Journal', streak: 7, done: true),
  const _HabitData(icon: 'S', name: 'Stretch', streak: 2, done: false),
];

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done ? Colors.white38 : Colors.grey.shade700,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? Colors.white : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Streak',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
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
          ),
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            color: done ? Colors.white : Colors.grey,
            size: 22,
          ),
        ],
      ),
    );
  }
}
