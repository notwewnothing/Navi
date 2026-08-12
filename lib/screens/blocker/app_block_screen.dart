import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/block_rule.dart';
import '../../models/schedule_event.dart';
import '../../services/app_blocker.dart';
import '../../services/block_store.dart';
import '../../services/schedule_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/glitch.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import 'rule_edit_sheet.dart';

class AppBlockScreen extends StatefulWidget {
  const AppBlockScreen({super.key});

  @override
  State<AppBlockScreen> createState() => _AppBlockScreenState();
}

class _AppBlockScreenState extends State<AppBlockScreen>
    with WidgetsBindingObserver {
  late Future<bool> _serviceOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _serviceOn = AppBlocker.isAccessibilityEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _serviceOn = AppBlocker.isAccessibilityEnabled());
    }
  }

  Future<bool?> _confirmDelete() {
    return showPixelDialog<bool>(
      context: context,
      title: 'DELETE RULE',
      builder: (context) => Text(
        'Sever this rule? The blocked apps go free.',
        style: context.palette.body,
      ),
      actions: (context) => [
        DialogAction(
          label: 'CANCEL',
          onTap: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: 'DELETE',
          danger: true,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Future<void> _pickSleepApps(BlockStore store) async {
    final result = await showAppPickerSheet(
      context,
      initial: store.sleepPackages,
    );
    if (result == null) return;
    await store.setSleepBlock(packages: result);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = BlockScope.of(context);
    final schedule = ScheduleScope.of(context);
    final rules = store.rules;
    final sleepEvents = schedule.sleepEvents;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PixelHeader(
              title: 'APP BLOCKING',
              leading: PixelIconButton(
                glyph: Px.left,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                children: [
                  _Reveal(
                    index: 0,
                    child: _StatusBanner(
                      future: _serviceOn,
                      onEnable: () {
                        Sfx.tick();
                        AppBlocker.openAccessibilitySettings();
                      },
                    ),
                  ),
                  const SizedBox(height: 26),

                  _Reveal(
                    index: 1,
                    child: Row(
                      children: [
                        Text('BLOCK RULES', style: p.h2),
                        const Spacer(),
                        if (rules.isNotEmpty)
                          Text(
                            '${rules.length}',
                            style: p.label.copyWith(color: p.accent),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (rules.isEmpty)
                    const _Reveal(
                      index: 2,
                      child: SizedBox(
                        height: 170,
                        child: EmptyState(
                          message: 'No rules. The world is open.',
                          glyph: Px.block,
                        ),
                      ),
                    )
                  else
                    for (final (i, rule) in rules.indexed)
                      _Reveal(
                        index: 2 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey('block-rule-${rule.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: p.danger.withValues(alpha: 0.12),
                                border: Border.all(color: p.danger),
                              ),
                              child: PixelIcon(
                                Px.trash,
                                color: p.danger,
                                size: 18,
                              ),
                            ),
                            confirmDismiss: (_) async =>
                                await _confirmDelete() ?? false,
                            onDismissed: (_) {
                              HapticFeedback.mediumImpact();
                              Sfx.glitch();
                              store.removeRule(rule);
                              showPixelToast(
                                context,
                                'RULE DELETED',
                                glyph: Px.trash,
                              );
                            },
                            child: _RuleCard(
                              rule: rule,
                              onTap: () =>
                                  showRuleEditSheet(context, rule: rule),
                              onToggle: () => store.toggleRule(rule),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 22),

                  _Reveal(
                    index: 3 + rules.length,
                    child: Text('SLEEP BLOCKING', style: p.h2),
                  ),
                  const SizedBox(height: 12),
                  _Reveal(
                    index: 4 + rules.length,
                    child: _SleepBlockCard(
                      store: store,
                      sleepEvents: sleepEvents,
                      onPickApps: () => _pickSleepApps(store),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PixelFab(
        onTap: () => showRuleEditSheet(context),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.future, required this.onEnable});

  final Future<bool> future;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<bool>(
      future: future,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        final online = snapshot.data ?? false;
        return PixelCard(
          highlighted: ready && online,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            child: !ready
                ? Row(
                    key: const ValueKey('probing'),
                    children: [
                      const BlinkingCursor(width: 8, height: 14),
                      const SizedBox(width: 12),
                      Text('LINKING...', style: p.label),
                    ],
                  )
                : online
                ? Row(
                    key: const ValueKey('online'),
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.accent,
                          boxShadow: [
                            BoxShadow(
                              color: p.accent.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLOCKER ONLINE',
                              style: TextStyle(
                                fontFamily: kFontPixel,
                                fontSize: 9,
                                letterSpacing: 1.5,
                                color: p.accent,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Accessibility link active. Rules enforced.',
                              style: p.bodyDim.copyWith(fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                      PixelIcon(Px.check, color: p.accent, size: 16),
                    ],
                  )
                : Column(
                    key: const ValueKey('offline'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BlinkingCursor(width: 10, height: 10, color: p.danger),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'BLOCKER OFFLINE',
                              style: TextStyle(
                                fontFamily: kFontPixel,
                                fontSize: 9,
                                letterSpacing: 1.5,
                                color: p.danger,
                                height: 1.4,
                              ),
                            ),
                          ),
                          PixelIcon(Px.x, color: p.danger, size: 14),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The accessibility service is disconnected. '
                        'Nothing is blocked.',
                        style: p.bodyDim.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 12),
                      PixelButton(
                        label: 'ENABLE',
                        glyph: Px.bolt,
                        danger: true,
                        expand: true,
                        height: 44,
                        onTap: onEnable,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onTap,
    required this.onToggle,
  });

  final BlockRule rule;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  static String _daySummary(int bits) {
    const names = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    return switch (bits & 0x7f) {
      0x7f => 'EVERY DAY',
      0x1f => 'MON—FRI',
      0x60 => 'WEEKENDS',
      0 => 'NO DAYS',
      final b => [
        for (var i = 0; i < 7; i++)
          if ((b >> i) & 1 == 1) names[i],
      ].join(' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PixelCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: rule.enabled ? 1 : 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppIconStack(packages: rule.packages, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '${rule.packages.length} '
                        'APP${rule.packages.length == 1 ? '' : 'S'}',
                        style: p.label.copyWith(color: p.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    rule.timeLabel,
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 26,
                      color: rule.enabled ? p.text : p.textDim,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(_daySummary(rule.dayBits), style: p.label),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          PixelSwitch(value: rule.enabled, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}

class _SleepBlockCard extends StatelessWidget {
  const _SleepBlockCard({
    required this.store,
    required this.sleepEvents,
    required this.onPickApps,
  });

  final BlockStore store;
  final List<ScheduleEvent> sleepEvents;
  final VoidCallback onPickApps;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = store.sleepBlockEnabled;
    return PixelCard(
      highlighted: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelIcon(
                Px.moon,
                color: enabled ? p.sleepDot : p.textGhost,
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SLEEP BLOCKING',
                      style: TextStyle(
                        fontFamily: kFontPixel,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: enabled ? p.text : p.textDim,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Lock apps away while you sleep.',
                      style: p.bodyDim.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PixelSwitch(
                value: enabled,
                onChanged: (v) => store.setSleepBlock(enabled: v),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !enabled
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      PixelButton(
                        label: 'APPS (${store.sleepPackages.length})',
                        glyph: Px.grid,
                        expand: true,
                        height: 44,
                        onTap: onPickApps,
                      ),
                      if (store.sleepPackages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        AppIconStack(packages: store.sleepPackages, size: 22),
                      ],
                      const SizedBox(height: 12),
                      if (sleepEvents.isEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PixelIcon(Px.x, color: p.danger, size: 11),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'NO SLEEP BLOCKS SCHEDULED — '
                                'ADD ONE IN SCHEDULE',
                                style: p.label.copyWith(
                                  color: p.danger.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        for (final event in sleepEvents)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  color: p.sleepDot,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'BLOCKS DURING: ${event.timeLabel}',
                                  style: TextStyle(
                                    fontFamily: kFontTerminal,
                                    fontSize: 18,
                                    color: p.textDim,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
          ),
        ],
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
    final delay = index * 80;
    final total = 360 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
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
