import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import '../widgets/nd_icons.dart';
import '../widgets/nd_widgets.dart';
import '../widgets/tactile.dart';

import 'habits/habit_edit_sheet.dart';
import 'habits/habits_screen.dart';
import 'home/home_screen.dart';
import 'journal/journal_entry_editor.dart';
import 'journal/journal_screen.dart';
import 'schedule/event_edit_sheet.dart';
import 'schedule/schedule_screen.dart';

/// Vertical space the floating nav overlays. Every tab's scrollable content
/// pads its bottom by this so the last row clears the capsule.
const double kNavContentInset = 96;

class NaviShell extends StatefulWidget {
  const NaviShell({super.key});

  @override
  State<NaviShell> createState() => NaviShellState();
}

class NaviShellState extends State<NaviShell> {
  int _index = 0;

  static const _tabs = [
    (Nd.home, 'Home'),
    (Nd.grid, 'Habits'),
    (Nd.book, 'Journal'),
    (Nd.calendar, 'Schedule'),
  ];

  void goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  /// The floating circle creates whatever the current tab is about.
  void _create() {
    switch (_index) {
      case 1:
        showHabitEditSheet(context);
      case 3:
        showEventEditSheet(context);
      case 0:
      case 2:
      default:
        showJournalEntrySheet(context);
    }
  }

  String get _createLabel => switch (_index) {
    1 => 'New habit',
    3 => 'New event',
    _ => 'New entry',
  };

  @override
  Widget build(BuildContext context) {
    // this context sits above the Scaffold, so the inset is the real one
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // viewPadding rather than padding: padding collapses to 0 with the
    // keyboard up, which would make the bar jump
    final systemInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          // keeps every tab alive so switching doesn't reset scroll or state
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                HabitsScreen(),
                JournalScreen(),
                ScheduleScreen(),
              ],
            ),
          ),
          Positioned(
            left: NdSpace.page,
            right: NdSpace.page,
            bottom: systemInset + NdSpace.md,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              offset: keyboardOpen ? const Offset(0, 1.6) : Offset.zero,
              child: IgnorePointer(
                ignoring: keyboardOpen,
                child: Row(
                  children: [
                    Expanded(
                      child: _NavCapsule(
                        index: _index,
                        tabs: _tabs,
                        onTap: (i) {
                          if (i == _index) return;
                          HapticFeedback.selectionClick();
                          Sfx.tick();
                          setState(() => _index = i);
                        },
                      ),
                    ),
                    const SizedBox(width: NdSpace.md),
                    Tooltip(
                      message: _createLabel,
                      child: NdFab(onTap: _create),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCapsule extends StatelessWidget {
  const _NavCapsule({
    required this.index,
    required this.tabs,
    required this.onTap,
  });

  final int index;
  final List<(NdGlyph, String)> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NdRadius.pill),
      child: BackdropFilter(
        // whatever scrolls under the bar stays readable as a soft wash
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                p.panelHi.withValues(alpha: 0.72),
                p.panel.withValues(alpha: 0.58),
              ],
            ),
            border: Border.all(color: p.border.withValues(alpha: 0.8)),
            borderRadius: BorderRadius.circular(NdRadius.pill),
          ),
          child: Row(
            children: [
              for (final (i, tab) in tabs.indexed)
                Expanded(
                  child: _NavItem(
                    glyph: tab.$1,
                    label: tab.$2,
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final NdGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.onAccent : p.textGhost;
    return Tactile(
      pressedScale: 0.92,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: Tooltip(
            message: label,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? p.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    scale: selected ? 1.08 : 1,
                    child: NdIcon(glyph, color: color, size: 23),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
