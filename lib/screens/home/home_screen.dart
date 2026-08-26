import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/habit_dot_grid.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/routes.dart';
import '../habits/habit_checkin_screen.dart';
import '../habits/habit_edit_sheet.dart';
import '../journal/journal_entry_editor.dart';
import '../schedule/event_edit_sheet.dart';
import '../settings/settings_screen.dart';
import '../stats/screen_time_screen.dart';
import '../timer/timer_screen.dart';
import '../shell.dart';

/// PLACEHOLDER. The "Distracted today" card is not wired to any data source —
/// every value below is static. Replace with real screen-time data.
// TODO(navi): wire "Distracted today" to DeviceUsage / SessionStore.
const _kDistractedPlaceholder = (
  value: '55 mins',
  trendUp: true,
  delta: '(more than yesterday by 12mins)',
);

enum _QuickAdd { habit, journal, event }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _toggleHabit(Habit habit) async {
    final habits = HabitScope.of(context);
    final now = DateTime.now();
    if (habits.isDone(habit, now)) {
      HapticFeedback.selectionClick();
      await habits.uncheck(habit);
      return;
    }
    if (habit.requirePhoto) {
      Navigator.of(
        context,
      ).push(slideUpRoute(HabitCheckinScreen(habit: habit)));
      return;
    }
    HapticFeedback.mediumImpact();
    final allDone = await habits.checkIn(habit);
    if (!mounted) return;
    Sfx.complete();
    if (allDone) {
      showNdToast(context, 'Every habit done today', glyph: Nd.check);
    }
  }

  Future<void> _showQuickAdd() async {
    // resolve the choice first, then open the second sheet — nesting one modal
    // inside another stacks barriers and squeezes the inner sheet
    final choice = await showNdSheet<_QuickAdd>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NdSheetHeader(title: 'Quick add'),
            for (final (glyph, label, value) in const [
              (Nd.grid, 'New habit', _QuickAdd.habit),
              (Nd.book, 'New journal entry', _QuickAdd.journal),
              (Nd.calendar, 'New schedule event', _QuickAdd.event),
            ])
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NdSpace.page,
                  0,
                  NdSpace.page,
                  NdSpace.md,
                ),
                child: _QuickAddRow(
                  glyph: glyph,
                  label: label,
                  onTap: () => Navigator.pop(sheetContext, value),
                ),
              ),
            const SizedBox(height: NdSpace.md),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _QuickAdd.habit:
        showHabitEditSheet(context);
      case _QuickAdd.journal:
        showJournalEntrySheet(context);
      case _QuickAdd.event:
        showEventEditSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = SettingsScope.of(context);
    final store = HabitScope.of(context);
    final shell = context.findAncestorStateOfType<NaviShellState>();
    final now = DateTime.now();

    // resolve once — enabledHabits allocates a fresh list on every access
    final enabled = store.enabledHabits;
    final scheduled = [
      for (final h in enabled)
        if (h.scheduledOn(now)) h,
    ];
    final done = scheduled.where((h) => store.isDone(h, now)).length;
    final cards = enabled.take(4).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NdSpace.page,
            NdSpace.md,
            NdSpace.page,
            kNavContentInset,
          ),
          children: [
            _Header(
              onStats: () => Navigator.of(
                context,
              ).push(slideUpRoute(const ScreenTimeScreen())),
              onQuickAdd: _showQuickAdd,
              onSettings: () => Navigator.of(context).push(
                slideUpRoute(
                  SettingsScreen(onManageHabits: () => shell?.goTo(1)),
                ),
              ),
            ),
            const SizedBox(height: NdSpace.xl),

            _GreetingBlock(name: settings.displayName),
            const SizedBox(height: NdSpace.xl),

            Row(
              children: [
                Expanded(
                  child: NdButton(
                    label: 'Focus Session',
                    glyph: Nd.eye,
                    expand: true,
                    height: 60,
                    onTap: () => Navigator.of(context).push(
                      slideUpRoute(
                        const TimerScreen(initialMode: TimerMode.focus),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NdSpace.md),
                Expanded(
                  child: NdButton(
                    label: 'Sleep Session',
                    glyph: Nd.moon,
                    expand: true,
                    height: 60,
                    onTap: () => Navigator.of(context).push(
                      slideUpRoute(
                        const TimerScreen(initialMode: TimerMode.sleep),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NdSpace.xl),

            _SectionHeader(
              label: 'Stats:',
              onSeeAll: () => Navigator.of(
                context,
              ).push(slideUpRoute(const ScreenTimeScreen())),
            ),
            const SizedBox(height: NdSpace.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _TodayStatCard(
                      done: done,
                      scheduled: scheduled,
                      store: store,
                      day: now,
                    ),
                  ),
                  const SizedBox(width: NdSpace.md),
                  const Expanded(child: _DistractedStatCard()),
                ],
              ),
            ),
            const SizedBox(height: NdSpace.xl),

            _SectionHeader(
              label: 'Habits:',
              onSeeAll: enabled.isEmpty ? null : () => shell?.goTo(1),
            ),
            const SizedBox(height: NdSpace.md),
            if (cards.isEmpty)
              NdCard(
                onTap: () => showHabitEditSheet(context),
                child: Row(
                  children: [
                    NdIcon(Nd.plus, color: p.accent, size: 22),
                    const SizedBox(width: NdSpace.md),
                    Expanded(child: Text('Add your first habit', style: p.row)),
                    NdIcon(Nd.right, color: p.textGhost, size: 20),
                  ],
                ),
              )
            else
              for (var row = 0; row * 2 < cards.length; row++) ...[
                if (row > 0) const SizedBox(height: NdSpace.md),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _HomeHabitCard(
                          habit: cards[row * 2],
                          store: store,
                          day: now,
                          onToggle: () => _toggleHabit(cards[row * 2]),
                          onOpen: () => Navigator.of(context).push(
                            slideUpRoute(
                              HabitCheckinScreen(habit: cards[row * 2]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: NdSpace.md),
                      // filler keeps a lone odd card at half width
                      Expanded(
                        child: row * 2 + 1 < cards.length
                            ? _HomeHabitCard(
                                habit: cards[row * 2 + 1],
                                store: store,
                                day: now,
                                onToggle: () =>
                                    _toggleHabit(cards[row * 2 + 1]),
                                onOpen: () => Navigator.of(context).push(
                                  slideUpRoute(
                                    HabitCheckinScreen(
                                      habit: cards[row * 2 + 1],
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: NdSpace.xl),

            Text('QUICK NOTE:', style: p.h2),
            const SizedBox(height: NdSpace.md),
            NdCard(
              padding: const EdgeInsets.all(NdSpace.md),
              child: Row(
                children: [
                  for (final (i, (glyph, label, capture)) in const [
                    (Nd.textLines, 'Text', JournalCapture.text),
                    (Nd.camera, 'Photo', JournalCapture.photo),
                    (Nd.video, 'Video', JournalCapture.video),
                    (Nd.mic, 'Voice', JournalCapture.voice),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: NdSpace.sm),
                    Expanded(
                      child: _NoteTile(
                        glyph: glyph,
                        label: label,
                        onTap: () =>
                            showJournalEntrySheet(context, start: capture),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onStats,
    required this.onQuickAdd,
    required this.onSettings,
  });

  final VoidCallback onStats;
  final VoidCallback onQuickAdd;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: NdSpace.md),
        // shrinks instead of pushing the action buttons off at large text scales
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('NAVI', style: p.logo, maxLines: 1),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: p.panel,
            border: Border.all(color: p.border),
            borderRadius: BorderRadius.circular(NdRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NdIconButton(
                glyph: Nd.chart,
                size: 20,
                tooltip: 'Stats',
                onTap: onStats,
              ),
              NdIconButton(
                glyph: Nd.plus,
                size: 22,
                tooltip: 'Quick add',
                onTap: onQuickAdd,
              ),
            ],
          ),
        ),
        const SizedBox(width: NdSpace.sm),
        NdIconButton(
          glyph: Nd.gear,
          radius: NdRadius.small,
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ],
    );
  }
}

/// Owns its own ticking clock so a minute rollover repaints two lines of text
/// rather than the whole page (including four dot grids).
class _GreetingBlock extends StatefulWidget {
  const _GreetingBlock({required this.name});

  final String name;

  @override
  State<_GreetingBlock> createState() => _GreetingBlockState();
}

class _GreetingBlockState extends State<_GreetingBlock> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      final n = DateTime.now();
      // only rebuild when the displayed minute actually moves
      if (n.minute == _now.minute && n.hour == _now.hour) return;
      if (mounted) setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _greeting(int hour) {
    if (hour < 5) return 'Still up';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${_days[_now.weekday - 1]} ${_now.day} ${_months[_now.month - 1]} · '
        '${two(_now.hour)}:${two(_now.minute)} · ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting(_now.hour)}, ${widget.name}',
          style: p.h1.copyWith(fontSize: 24),
        ),
        const SizedBox(height: NdSpace.xs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: stamp, style: p.bodyDim),
              TextSpan(
                text: 'LOGGED IN',
                style: p.micro.copyWith(color: p.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.onSeeAll});

  final String label;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Text(label, style: p.h2),
        const Spacer(),
        if (onSeeAll != null) _TextLink(label: 'See all', onTap: onSeeAll!),
      ],
    );
  }
}

class _TodayStatCard extends StatelessWidget {
  const _TodayStatCard({
    required this.done,
    required this.scheduled,
    required this.store,
    required this.day,
  });

  final int done;
  final List<Habit> scheduled;
  final HabitStore store;
  final DateTime day;

  // past ~12 the bars get too thin to read, so cap and count the remainder
  static const _maxBars = 12;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = scheduled.length;
    final shown = total > _maxBars ? _maxBars : total;
    return NdCard(
      padding: const EdgeInsets.all(NdSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TODAY', style: p.h2),
              const Spacer(),
              NdIcon(Nd.flame, color: p.accent, size: 18),
            ],
          ),
          const SizedBox(height: NdSpace.md),
          // scales down rather than overflowing once the counts get wide
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$done', style: p.dot(44, color: p.text)),
                Text(' / $total', style: p.dot(22, color: p.textGhost)),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(height: NdSpace.md),
          if (total == 0)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: p.panelHi,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: NdSpace.sm),
                Text('none', style: p.micro.copyWith(color: p.textGhost)),
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < shown; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isDone = store.isDone(scheduled[i], day);
                        return Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDone ? p.accent : Colors.transparent,
                            border: Border.all(
                              color: isDone ? p.accent : p.borderHi,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (total > shown) ...[
                  const SizedBox(width: NdSpace.sm),
                  Text(
                    '+${total - shown}',
                    style: p.micro.copyWith(color: p.textGhost),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _DistractedStatCard extends StatelessWidget {
  // takes no data, on purpose — see _kDistractedPlaceholder
  const _DistractedStatCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NdCard(
      padding: const EdgeInsets.all(NdSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('DISTRACTED\nTODAY', style: p.h2)),
              NdIcon(Nd.hourglass, color: p.textDim, size: 18),
            ],
          ),
          const Spacer(),
          const SizedBox(height: NdSpace.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  _kDistractedPlaceholder.value,
                  maxLines: 1,
                  style: p.dot(30, color: p.danger),
                ),
                const SizedBox(width: NdSpace.xs),
                NdIcon(
                  _kDistractedPlaceholder.trendUp ? Nd.up : Nd.down,
                  color: p.danger,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: NdSpace.xs),
          Text(
            _kDistractedPlaceholder.delta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: p.micro.copyWith(color: p.textGhost),
          ),
        ],
      ),
    );
  }
}

class _HomeHabitCard extends StatelessWidget {
  const _HomeHabitCard({
    required this.habit,
    required this.store,
    required this.day,
    required this.onToggle,
    required this.onOpen,
  });

  final Habit habit;
  final HabitStore store;
  final DateTime day;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = habitDotColors[habit.colorIndex % habitDotColors.length];
    final done = store.isDone(habit, day);
    final createdDay = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );
    final subtitle = habit.description.trim().isNotEmpty
        ? habit.description.trim()
        : habitScheduleLabel(habit, withReminder: false);

    return NdCard(
      highlighted: done,
      onTap: onToggle,
      onLongPress: onOpen,
      padding: const EdgeInsets.all(NdSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.panelHi,
                  border: Border.all(color: p.border),
                  borderRadius: BorderRadius.circular(NdRadius.small),
                ),
                child: Center(
                  child: NdIcon(
                    Nd.habitIcon(habit.icon),
                    color: color,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  // pads a 28dp circle out to a 44dp tap target
                  padding: const EdgeInsets.all(8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Container(
                      key: ValueKey(done),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? p.accent : Colors.transparent,
                        border: Border.all(color: done ? p.accent : p.borderHi),
                      ),
                      child: Center(
                        child: NdIcon(
                          done ? Nd.check : Nd.plus,
                          color: done ? p.onAccent : p.textGhost,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NdSpace.sm),
          Text(
            habit.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: p.row.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: p.label.copyWith(fontSize: 11),
          ),
          const SizedBox(height: NdSpace.md),
          HabitDotGrid(
            color: color,
            isDone: (d) => store.isDone(habit, d),
            isActive: (d) => habit.scheduledOn(d) && !d.isBefore(createdDay),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final NdGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NdCard(
      onTap: onTap,
      radius: NdRadius.small,
      padding: const EdgeInsets.symmetric(vertical: NdSpace.md),
      child: Column(
        children: [
          NdIcon(glyph, color: p.text, size: 22),
          const SizedBox(height: NdSpace.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: p.label.copyWith(fontSize: 11, color: p.text),
          ),
        ],
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final NdGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NdCard(
      onTap: onTap,
      radius: NdRadius.inner,
      padding: const EdgeInsets.all(NdSpace.lg),
      child: Row(
        children: [
          NdIcon(glyph, color: p.accent, size: 20),
          const SizedBox(width: NdSpace.lg),
          Expanded(child: Text(label, style: p.row)),
          NdIcon(Nd.right, color: p.textGhost, size: 20),
        ],
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NdSpace.sm,
          vertical: NdSpace.xs,
        ),
        child: Row(
          children: [
            Text(label, style: p.label.copyWith(color: p.text)),
            const SizedBox(width: 2),
            NdIcon(Nd.right, color: p.text, size: 16),
          ],
        ),
      ),
    );
  }
}
