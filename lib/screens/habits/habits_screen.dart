import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
import 'habit_checkin_screen.dart';
import 'habit_edit_sheet.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = HabitScope.of(context);
    final habits = store.habits;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelHeader(
              title: 'HABITS',
              actions: [
                if (habits.isNotEmpty)
                  Text(
                    '${store.enabledHabits.length} ACTIVE',
                    style: p.label.copyWith(color: p.accentMid),
                  ),
              ],
            ),
            Expanded(
              child: habits.isEmpty
                  ? const EmptyState(
                      message: 'You have no habits... are you really here?',
                      glyph: Px.grid,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
                      itemCount: habits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _Reveal(
                        index: i,
                        child: _HabitRow(habit: habits[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: PixelFab(
        onTap: () => showHabitEditSheet(context),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habit});

  final Habit habit;

  static const _dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  String get _meta {
    final bits = habit.dayBits & 0x7f;
    final schedule = switch (bits) {
      0x7f => 'EVERY DAY',
      0x1f => 'WEEKDAYS',
      0x60 => 'WEEKENDS',
      0 => 'UNSCHEDULED',
      _ => [
        for (var i = 0; i < 7; i++)
          if ((bits >> i) & 1 == 1) _dayNames[i],
      ].join(' '),
    };
    final r = habit.reminderMinutes;
    if (r == null) return schedule;
    final hh = (r ~/ 60).toString().padLeft(2, '0');
    final mm = (r % 60).toString().padLeft(2, '0');
    return '$schedule / $hh:$mm';
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final p = context.palette;
    final confirmed = await showPixelDialog<bool>(
      context: context,
      title: 'DELETE HABIT?',
      builder: (context) => Text(
        'ITS LOG VANISHES FROM THE WIRED.',
        style: p.body,
      ),
      actions: (context) => [
        DialogAction(
          label: 'KEEP',
          onTap: () => Navigator.pop(context, false),
        ),
        DialogAction(
          label: 'DELETE',
          danger: true,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = HabitScope.of(context);
    final dotColor = habitDotColors[habit.colorIndex % habitDotColors.length];
    final streak = store.streak(habit);
    return Dismissible(
      key: ValueKey('habit-${habit.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: p.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const PixelIcon(Px.trash, color: Colors.black, size: 20),
      ),
      confirmDismiss: (_) {
        HapticFeedback.mediumImpact();
        return _confirmDelete(context);
      },
      onDismissed: (_) {
        Sfx.glitch();
        store.removeHabit(habit);
        showPixelToast(context, 'ERASED FROM THE WIRED', glyph: Px.trash);
      },
      child: PixelCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => showHabitEditSheet(context, habit: habit),
        onLongPress: () => Navigator.of(context).push(
          slideUpRoute(HabitCheckinScreen(habit: habit)),
        ),
        child: Row(
          children: [
            PixelIcon(
              Px.habitIcon(habit.icon),
              color: habit.enabled ? dotColor : p.textGhost,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.row.copyWith(
                      fontSize: 22,
                      color: habit.enabled ? p.text : p.textDim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: p.label,
                        ),
                      ),
                      if (habit.requirePhoto) ...[
                        const SizedBox(width: 6),
                        PixelIcon(Px.camera, color: p.textGhost, size: 10),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PixelIcon(
              Px.flame,
              color: streak > 0 ? p.accentMid : p.textGhost,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 20,
                height: 1,
                color: streak > 0 ? p.accentMid : p.textGhost,
              ),
            ),
            const SizedBox(width: 12),
            PixelSwitch(
              value: habit.enabled,
              onChanged: (_) => store.toggleHabit(habit),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delayMs = 80 * index;
    final totalMs = 320 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
