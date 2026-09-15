import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/routes.dart';
import '../shell.dart';
import 'habit_checkin_screen.dart';
import 'habit_edit_sheet.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = HabitScope.of(context);
    final habits = store.habits;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NdHeader(
              title: 'Habits',
              subtitle: habits.isEmpty
                  ? null
                  : '${store.enabledHabits.length} active of ${habits.length}',
            ),
            Expanded(
              child: habits.isEmpty
                  ? EmptyState(
                      message:
                          'No habits yet.\nStart with one you can do daily.',
                      glyph: Nd.grid,
                      actionLabel: 'Add a habit',
                      onAction: () => showHabitEditSheet(context),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        NdSpace.page,
                        NdSpace.xs,
                        NdSpace.page,
                        kNavContentInset,
                      ),
                      itemCount: habits.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: NdSpace.md),
                      itemBuilder: (context, i) => _Reveal(
                        index: i,
                        child: _HabitRow(habit: habits[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = HabitScope.of(context);
    final dotColor = habitDotColors[habit.colorIndex % habitDotColors.length];
    final streak = store.streak(habit);
    final resting = store.isRestDay(habit, DateTime.now());
    return Dismissible(
      key: ValueKey('habit-${habit.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: p.accentDim,
          borderRadius: BorderRadius.circular(NdRadius.card),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: NdSpace.xl),
        child: NdIcon(Nd.moon, color: p.text, size: 22),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: p.danger,
          borderRadius: BorderRadius.circular(NdRadius.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: NdSpace.xl),
        child: const NdIcon(Nd.trash, color: Colors.white, size: 22),
      ),
      // a rest day is not a dismissal, so swiping right undoes itself
      confirmDismiss: (direction) async {
        if (direction != DismissDirection.startToEnd) return true;
        HapticFeedback.mediumImpact();
        Sfx.tick();
        if (resting) {
          await store.uncheck(habit);
          if (context.mounted) {
            showNdToast(context, 'Rest day cleared', glyph: Nd.check);
          }
        } else {
          await store.skipDay(habit);
          if (context.mounted) {
            showNdToast(
              context,
              'Resting "${habit.name}" today',
              glyph: Nd.moon,
              actionLabel: 'Undo',
              onAction: () => store.uncheck(habit),
            );
          }
        }
        return false;
      },
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        Sfx.tick();
        final logs = await store.removeHabit(habit, keepMedia: true);
        if (!context.mounted) return;
        showNdToast(
          context,
          'Deleted "${habit.name}"',
          glyph: Nd.trash,
          actionLabel: 'Undo',
          onAction: () => store.restoreHabit(habit, logs),
          onExpire: () => store.purgeLogMedia(logs),
        );
      },
      child: NdCard(
        padding: const EdgeInsets.all(NdSpace.lg),
        // tap edits, long-press checks in, no labels because the chrome is minimal
        onTap: () => showHabitEditSheet(context, habit: habit),
        onLongPress: () => Navigator.of(
          context,
        ).push(slideUpRoute(HabitCheckinScreen(habit: habit))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.panelHi,
                border: Border.all(color: p.border),
              ),
              child: Center(
                child: NdIcon(
                  Nd.habitIcon(habit.icon),
                  color: habit.enabled ? dotColor : p.textGhost,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: NdSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.row.copyWith(
                      color: habit.enabled ? p.text : p.textDim,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (resting) ...[
                        NdIcon(Nd.moon, color: p.accent, size: 11),
                        const SizedBox(width: NdSpace.xs),
                      ],
                      Flexible(
                        child: Text(
                          resting
                              ? (store.isPaused(habit, DateTime.now())
                                    ? 'Paused'
                                    : 'Resting today')
                              : habitScheduleLabel(habit),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: resting
                              ? p.label.copyWith(color: p.accent)
                              : p.label,
                        ),
                      ),
                      if (habit.requirePhoto) ...[
                        const SizedBox(width: NdSpace.sm),
                        NdIcon(Nd.camera, color: p.textGhost, size: 13),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: NdSpace.sm),
            NdIcon(
              Nd.flame,
              color: streak > 0 ? p.accent : p.textGhost,
              size: 16,
            ),
            const SizedBox(width: NdSpace.xs),
            Text(
              '$streak',
              style: p.dot(18, color: streak > 0 ? p.accent : p.textGhost),
            ),
            const SizedBox(width: NdSpace.sm),
            NdSwitch(
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
