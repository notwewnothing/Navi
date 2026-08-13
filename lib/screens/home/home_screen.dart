import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit.dart';
import '../../services/easter_eggs.dart';
import '../../services/habit_store.dart';
import '../../services/journal_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../models/journal_entry.dart';
import '../../theme/palette.dart';
import '../../widgets/commitment_board.dart';
import '../../widgets/glitch.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
import '../../widgets/tactile.dart';
import '../habits/habit_checkin_screen.dart';
import '../stats/screen_time_screen.dart';
import '../timer/timer_screen.dart';
import '../shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _journalController = TextEditingController();
  final _journalFocus = FocusNode();
  bool _journalActive = false;

  int _logoTaps = 0;
  DateTime _lastLogoTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _journalFocus.addListener(() {
      setState(() => _journalActive = _journalFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _journalController.dispose();
    _journalFocus.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    final now = DateTime.now();
    if (now.difference(_lastLogoTap) > const Duration(milliseconds: 450)) {
      _logoTaps = 0;
    }
    _lastLogoTap = now;
    _logoTaps++;
    if (_logoTaps >= 3) {
      _logoTaps = 0;
      EasterEggs.wiredBoot(context);
    }
  }

  Future<void> _saveQuickJournal() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;
    final journal = JournalScope.of(context);
    await journal.add(type: JournalType.text, body: text);
    _journalController.clear();
    _journalFocus.unfocus();
    if (!mounted) return;
    Sfx.complete();
    showPixelToast(context, 'COMMITTED TO THE WIRED', glyph: Px.check);
  }

  Future<void> _toggleHabit(Habit habit) async {
    final habits = HabitScope.of(context);
    final now = DateTime.now();
    if (habits.isDone(habit, now)) {
      HapticFeedback.selectionClick();
      await habits.uncheck(habit);
      return;
    }
    if (habit.requirePhoto) {
      Navigator.of(context).push(
        slideUpRoute(HabitCheckinScreen(habit: habit)),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final allDone = await habits.checkIn(habit);
    if (!mounted) return;
    if (allDone && habits.todayTotal() >= 7) {
      Sfx.knf();
      showPixelToast(context, "Let's all love Lain", glyph: Px.heart);
    } else if (allDone) {
      Sfx.knf();
      showPixelToast(context, 'ALL SIGNALS RECEIVED TODAY', glyph: Px.check);
    } else {
      Sfx.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = SettingsScope.of(context);
    final habits = HabitScope.of(context);
    final shell = context.findAncestorStateOfType<NaviShellState>();

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () =>
              EasterEggs.whisper(context, 'Your voice is reaching me'),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              Row(
                children: [
                  Tactile(
                    pressedScale: 0.94,
                    child: GestureDetector(
                      onTap: _onLogoTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, color: p.accent),
                          const SizedBox(width: 10),
                          Text('NAVI', style: p.logo),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  PixelIconButton(
                    glyph: Px.gear,
                    onTap: () => shell?.goTo(4),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GlitchText(
                settings.tagline,
                style: p.quote,
                intensity: 0.08,
                interval: const Duration(seconds: 7),
              ),
              const SizedBox(height: 22),

              Text('COMMITMENT LOG', style: p.h2),
              const SizedBox(height: 12),
              if (habits.habits.isEmpty)
                SizedBox(
                  height: 140,
                  child: EmptyState(message: "...i'm home"),
                )
              else
                CommitmentBoard(
                  levelFor: habits.boardLevel,
                  countFor: habits.completionsOn,
                ),
              const SizedBox(height: 26),

              Row(
                children: [
                  Text("TODAY'S PROGRESS", style: p.h2),
                  const Spacer(),
                  if (habits.todayTotal() > 0)
                    Text(
                      '${habits.todayDone()}/${habits.todayTotal()}',
                      style: p.label.copyWith(color: p.accent),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 118,
                child: habits.enabledHabits.isEmpty
                    ? PixelCard(
                        onTap: () => shell?.goTo(1),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PixelIcon(Px.plus, color: p.textDim, size: 14),
                              const SizedBox(width: 10),
                              Text(
                                'ADD YOUR FIRST HABIT',
                                style: p.label,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: habits.enabledHabits.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final habit = habits.enabledHabits[i];
                          return _HabitCard(
                            habit: habit,
                            done: habits.isDone(habit, DateTime.now()),
                            streak: habits.streak(habit),
                            scheduledToday:
                                habit.scheduledOn(DateTime.now()),
                            onToggle: () => _toggleHabit(habit),
                            onOpen: () => Navigator.of(context).push(
                              slideUpRoute(HabitCheckinScreen(habit: habit)),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 26),

              Text('QUICK JOURNAL', style: p.h2),
              const SizedBox(height: 12),
              PixelCard(
                highlighted: _journalActive,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelTextField(
                      controller: _journalController,
                      hint: 'Write something...',
                      maxLines: _journalActive ? 5 : 1,
                      fontSize: 20,
                      onChanged: (text) => EasterEggs.watchText(context, text),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: _journalActive
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  DialogAction(
                                    label: 'DISCARD',
                                    onTap: () {
                                      _journalController.clear();
                                      _journalFocus.unfocus();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  PixelButton(
                                    label: 'SAVE',
                                    height: 38,
                                    filled: true,
                                    onTap: _saveQuickJournal,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              Text('PROTOCOLS', style: p.h2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      label: 'FOCUS',
                      glyph: Px.eye,
                      expand: true,
                      onTap: () => Navigator.of(context).push(
                        slideUpRoute(
                          const TimerScreen(initialMode: TimerMode.focus),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PixelButton(
                      label: 'SLEEP',
                      glyph: Px.moon,
                      expand: true,
                      onTap: () => Navigator.of(context).push(
                        slideUpRoute(
                          const TimerScreen(initialMode: TimerMode.sleep),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PixelButton(
                      label: 'STATS',
                      glyph: Px.chart,
                      expand: true,
                      onTap: () => Navigator.of(context).push(
                        slideUpRoute(const ScreenTimeScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.done,
    required this.streak,
    required this.scheduledToday,
    required this.onToggle,
    required this.onOpen,
  });

  final Habit habit;
  final bool done;
  final int streak;
  final bool scheduledToday;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dotColor = habitDotColors[habit.colorIndex % habitDotColors.length];
    return SizedBox(
      width: 150,
      child: PixelCard(
        highlighted: done,
        onTap: onToggle,
        onLongPress: onOpen,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PixelIcon(
                  Px.habitIcon(habit.icon),
                  color: scheduledToday ? dotColor : p.textGhost,
                  size: 18,
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: PixelIcon(
                    done ? Px.check : Px.circle,
                    key: ValueKey(done),
                    color: done ? p.accent : p.textGhost,
                    size: 16,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              habit.name.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 19,
                height: 1.05,
                color: done ? p.text : p.textDim,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                PixelIcon(
                  Px.flame,
                  color: streak > 0 ? p.accentMid : p.textGhost,
                  size: 11,
                ),
                const SizedBox(width: 5),
                Text(
                  '$streak',
                  style: p.label.copyWith(
                    color: streak > 0 ? p.accentMid : p.textGhost,
                  ),
                ),
                const Spacer(),
                if (habit.requirePhoto)
                  PixelIcon(Px.camera, color: p.textGhost, size: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
