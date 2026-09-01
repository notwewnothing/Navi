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
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
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
    // accessibility state is cached at initState, re-evaluate when returning from system settings
    if (state == AppLifecycleState.resumed) {
      setState(() => _serviceOn = AppBlocker.isAccessibilityEnabled());
    }
  }

  Future<bool?> _confirmDelete() {
    return showNdDialog<bool>(
      context: context,
      title: 'Delete this rule?',
      builder: (context) => Text(
        'The apps it covers stop being blocked at these times.',
        style: context.palette.bodyDim,
      ),
      actions: (context) => [
        DialogAction(
          label: 'Cancel',
          onTap: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: 'Delete',
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
            NdHeader(
              title: 'App blocking',
              leading: NdIconButton(
                glyph: Nd.left,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  NdSpace.page,
                  NdSpace.xs,
                  NdSpace.page,
                  110,
                ),
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
                  const SizedBox(height: NdSpace.xxl),

                  _Reveal(
                    index: 1,
                    child: Row(
                      children: [
                        Text('BLOCK RULES', style: p.h2),
                        const Spacer(),
                        if (rules.isNotEmpty)
                          Text(
                            '${rules.length}',
                            style: p.micro.copyWith(color: p.accent),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: NdSpace.md),
                  if (rules.isEmpty)
                    _Reveal(
                      index: 2,
                      child: SizedBox(
                        height: 210,
                        child: EmptyState(
                          message:
                              'No rules yet.\nA rule blocks chosen apps at set times.',
                          glyph: Nd.block,
                          actionLabel: 'Add a rule',
                          onAction: () => showRuleEditSheet(context),
                        ),
                      ),
                    )
                  else
                    for (final (i, rule) in rules.indexed)
                      _Reveal(
                        index: 2 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: NdSpace.md),
                          child: Dismissible(
                            key: ValueKey('block-rule-${rule.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: NdSpace.xl),
                              decoration: BoxDecoration(
                                color: p.danger,
                                borderRadius: BorderRadius.circular(
                                  NdRadius.card,
                                ),
                              ),
                              child: const NdIcon(
                                Nd.trash,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            confirmDismiss: (_) async =>
                                await _confirmDelete() ?? false,
                            onDismissed: (_) {
                              HapticFeedback.mediumImpact();
                              Sfx.tick();
                              store.removeRule(rule);
                              showNdToast(
                                context,
                                'Rule deleted',
                                glyph: Nd.trash,
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
                  const SizedBox(height: NdSpace.xl),

                  _Reveal(
                    index: 3 + rules.length,
                    child: Text('SLEEP BLOCKING', style: p.h2),
                  ),
                  const SizedBox(height: NdSpace.md),
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
      floatingActionButton: NdFab(
        label: 'New rule',
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
        return NdCard(
          highlighted: ready && online,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            child: !ready
                ? Row(
                    key: const ValueKey('probing'),
                    children: [
                      const NdPulseDot(size: 8),
                      const SizedBox(width: NdSpace.md),
                      Text('Checking service...', style: p.label),
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
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: NdSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Blocking is active', style: p.row),
                            const SizedBox(height: 3),
                            Text(
                              'Your rules are being enforced.',
                              style: p.label.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      NdIcon(Nd.check, color: p.accent, size: 20),
                    ],
                  )
                : Column(
                    key: const ValueKey('offline'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          NdPulseDot(size: 10, color: p.danger),
                          const SizedBox(width: NdSpace.md),
                          Expanded(
                            child: Text(
                              'Blocking is off',
                              style: p.row.copyWith(color: p.danger),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NdSpace.sm),
                      Text(
                        'NAVI needs its accessibility service enabled. Until '
                        'then no app is blocked.',
                        style: p.bodyDim,
                      ),
                      const SizedBox(height: NdSpace.lg),
                      NdButton(
                        label: 'Open accessibility settings',
                        glyph: Nd.bolt,
                        danger: true,
                        filled: true,
                        expand: true,
                        height: 46,
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
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return switch (bits & 0x7f) {
      0x7f => 'Every day',
      0x1f => 'Weekdays',
      0x60 => 'Weekends',
      0 => 'No days selected',
      final b => [
        for (var i = 0; i < 7; i++)
          if ((b >> i) & 1 == 1) names[i],
      ].join(' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NdCard(
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
                      AppIconStack(packages: rule.packages, size: 24),
                      const SizedBox(width: NdSpace.md),
                      Text(
                        '${rule.packages.length} '
                        'app${rule.packages.length == 1 ? '' : 's'}',
                        style: p.label.copyWith(color: p.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: NdSpace.md),
                  Text(
                    rule.timeLabel,
                    style: p.dot(26, color: rule.enabled ? p.text : p.textDim),
                  ),
                  const SizedBox(height: NdSpace.xs),
                  Text(_daySummary(rule.dayBits), style: p.label),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          NdSwitch(value: rule.enabled, onChanged: (_) => onToggle()),
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
    return NdCard(
      highlighted: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NdIcon(
                Nd.moon,
                color: enabled ? p.sleepDot : p.textGhost,
                size: 22,
              ),
              const SizedBox(width: NdSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep blocking',
                      style: p.row.copyWith(
                        color: enabled ? p.text : p.textDim,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Locks apps away during scheduled sleep.',
                      style: p.label.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NdSpace.md),
              NdSwitch(
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
                      const SizedBox(height: NdSpace.lg),
                      NdButton(
                        label: store.sleepPackages.isEmpty
                            ? 'Choose apps'
                            : '${store.sleepPackages.length} app'
                                  '${store.sleepPackages.length == 1 ? '' : 's'} selected',
                        glyph: Nd.grid,
                        expand: true,
                        height: 46,
                        onTap: onPickApps,
                      ),
                      if (store.sleepPackages.isNotEmpty) ...[
                        const SizedBox(height: NdSpace.md),
                        AppIconStack(packages: store.sleepPackages, size: 24),
                      ],
                      const SizedBox(height: NdSpace.lg),
                      if (sleepEvents.isEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NdIcon(Nd.x, color: p.danger, size: 15),
                            const SizedBox(width: NdSpace.sm),
                            Expanded(
                              child: Text(
                                'No sleep events scheduled yet — add one on '
                                'the Schedule tab for this to take effect.',
                                style: p.label.copyWith(color: p.danger),
                              ),
                            ),
                          ],
                        )
                      else
                        for (final event in sleepEvents)
                          Padding(
                            padding: const EdgeInsets.only(top: NdSpace.xs),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: p.sleepDot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: NdSpace.md),
                                Text(
                                  'Blocks during ${event.timeLabel}',
                                  style: p.label,
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
