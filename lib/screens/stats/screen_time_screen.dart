import 'dart:math';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/day_stats.dart';
import '../../services/block_store.dart';
import '../../services/device_usage.dart';
import '../../services/session_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/glitch.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/tactile.dart';

typedef _AppUsage = ({String appName, String packageName, int seconds});

const _dayShort = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const _dayLong = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen>
    with WidgetsBindingObserver {
  late final List<DateTime> _week;
  late DateTime _selected;

  List<int>? _weekTotals;
  List<_AppUsage>? _apps;
  int _chartEpoch = 0;
  int _listEpoch = 0;
  int _appsRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _week = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    _selected = today;
    _loadWeek();
    _loadApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _loadWeek(silent: _weekTotals != null);
    _loadApps(silent: _apps != null && _apps!.isNotEmpty);
  }

  DateTime _dayEnd(DateTime day) => DateTime(day.year, day.month, day.day + 1);

  Future<void> _loadWeek({bool silent = false}) async {
    if (!silent && _weekTotals != null) setState(() => _weekTotals = null);
    final totals = await Future.wait([
      for (final day in _week) DeviceUsage.totalUsageSeconds(day, _dayEnd(day)),
    ]);
    if (!mounted) return;
    setState(() {
      if (!listEquals(_weekTotals, totals)) _chartEpoch++;
      _weekTotals = totals;
    });
  }

  Future<void> _loadApps({bool silent = false}) async {
    final request = ++_appsRequest;
    final day = _selected;
    if (!silent && _apps != null) setState(() => _apps = null);
    final apps = await DeviceUsage.appUsageSeconds(day, _dayEnd(day));
    if (!mounted || request != _appsRequest) return;
    setState(() {
      _apps = apps;
      _listEpoch++;
    });
  }

  void _selectDay(DateTime day) {
    if (day == _selected) return;
    HapticFeedback.selectionClick();
    Sfx.tick();
    setState(() => _selected = day);
    _loadApps();
  }

  Future<void> _openUsageSettings() async {
    Sfx.tick();
    try {
      final intent = AndroidIntent(
        action: 'android.settings.USAGE_ACCESS_SETTINGS',
      );
      await intent.launch();
    } catch (_) {}
  }

  String _dayTag(DateTime day) {
    if (day == _week.last) return 'TODAY';
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${_dayLong[day.weekday - 1]} $mm.$dd';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final block = BlockScope.of(context);
    final session = SessionScope.of(context);
    final blockedSet = <String>{
      for (final rule in block.rules) ...rule.packages,
      ...block.sleepPackages,
      ...session.blockedApps,
    };
    final todaySeconds = _weekTotals?.last ?? 0;
    final gate = _weekTotals != null && _weekTotals!.every((t) => t == 0);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PixelHeader(
              title: 'SCREEN TIME',
              leading: PixelIconButton(
                glyph: Px.left,
                onTap: () => Navigator.pop(context),
              ),
              actions: [
                if (todaySeconds > 0)
                  Text(
                    minutesLabel(todaySeconds ~/ 60),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 24,
                      height: 1,
                      color: p.accent,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: switch ((_weekTotals, gate)) {
                (null, _) => const _ScanningLabel(),
                (_, true) => _PermissionGate(onGrant: _openUsageSettings),
                _ => _content(p, blockedSet),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(NaviPalette p, Set<String> blockedSet) {
    final apps = _apps;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('LAST 7 DAYS', style: p.h2),
        const SizedBox(height: 14),
        _WeekChart(
          days: _week,
          totals: _weekTotals!,
          selected: _selected,
          epoch: _chartEpoch,
          onSelect: _selectDay,
        ),
        const SizedBox(height: 28),
        if (apps == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: _ScanningLabel(),
          )
        else ...[
          _distractionCard(apps, blockedSet),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('MOST USED', style: p.h2),
              const Spacer(),
              Text(_dayTag(_selected), style: p.labelAccent),
            ],
          ),
          const SizedBox(height: 14),
          if (apps.isEmpty)
            const SizedBox(
              height: 180,
              child: EmptyState(message: 'NO USAGE DATA'),
            )
          else
            _appList(apps, blockedSet),
        ],
      ],
    );
  }

  Widget _distractionCard(List<_AppUsage> apps, Set<String> blockedSet) {
    final totalSec = apps.fold(0, (sum, app) => sum + app.seconds);
    final blockedSec = apps
        .where((app) => blockedSet.contains(app.packageName))
        .fold(0, (sum, app) => sum + app.seconds);
    final pct = totalSec == 0 ? 0 : (blockedSec / totalSec * 100).round();
    return _DistractionCard(
      pct: pct,
      blockedSeconds: blockedSec,
      epoch: _listEpoch,
    );
  }

  Widget _appList(List<_AppUsage> apps, Set<String> blockedSet) {
    final top = apps.take(15).toList();
    final maxSec = top.first.seconds;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_listEpoch),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      builder: (context, t, _) => Column(
        children: [
          for (final (i, app) in top.indexed)
            _AppUsageRow(
              app: app,
              fraction: maxSec > 0 ? app.seconds / maxSec : 0,
              reveal: _staggered(t, i),
              isBlocked: blockedSet.contains(app.packageName),
            ),
        ],
      ),
    );
  }

  static double _staggered(double t, int i) {
    final start = i * 0.045;
    return Curves.easeOutCubic.transform(
      ((t - start) / 0.35).clamp(0.0, 1.0),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({
    required this.days,
    required this.totals,
    required this.selected,
    required this.epoch,
    required this.onSelect,
  });

  final List<DateTime> days;
  final List<int> totals;
  final DateTime selected;
  final int epoch;
  final ValueChanged<DateTime> onSelect;

  static const _maxBlocks = 12;
  static const _blockSide = 8.0;
  static const _blockGap = 3.0;
  static const _stackHeight =
      _maxBlocks * _blockSide + (_maxBlocks - 1) * _blockGap;

  @override
  Widget build(BuildContext context) {
    final maxTotal = totals.fold(0, max);
    return TweenAnimationBuilder<double>(
      key: ValueKey(epoch),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      builder: (context, t, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, day) in days.indexed)
            Expanded(child: _bar(context, i, day, maxTotal, t)),
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    int i,
    DateTime day,
    int maxTotal,
    double t,
  ) {
    final p = context.palette;
    final total = totals[i];
    final isSelected = day == selected;
    final isToday = day == days.last;
    final target = total <= 0 || maxTotal <= 0
        ? 0
        : (total / maxTotal * _maxBlocks).round().clamp(1, _maxBlocks);
    final tc = Curves.easeOutCubic.transform(
      ((t - i * 0.05) / 0.65).clamp(0.0, 1.0),
    );
    final lit = (target * tc).round();
    final color = isSelected ? p.accent : p.accentDim;

    return Tactile(
      pressedScale: 0.92,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(day),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                opacity: isSelected && total > 0 ? 1 : 0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    minutesLabel(total ~/ 60),
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 15,
                      height: 1,
                      color: p.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _stackHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (lit == 0)
                    Container(width: _blockSide, height: 2, color: p.border)
                  else
                    for (var b = 0; b < lit; b++) ...[
                      if (b > 0) const SizedBox(height: _blockGap),
                      Container(
                        width: _blockSide,
                        height: _blockSide,
                        color: color,
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _dayShort[day.weekday - 1],
              style: TextStyle(
                fontFamily: kFontPixel,
                fontSize: 7,
                letterSpacing: 1,
                height: 1.2,
                color: isSelected
                    ? p.accent
                    : isToday
                    ? p.textDim
                    : p.textGhost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistractionCard extends StatelessWidget {
  const _DistractionCard({
    required this.pct,
    required this.blockedSeconds,
    required this.epoch,
  });

  final int pct;
  final int blockedSeconds;
  final int epoch;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hot = pct > 40;
    final tone = hot ? p.danger : p.accent;
    return PixelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelIcon(Px.block, color: p.textDim, size: 12),
              const SizedBox(width: 8),
              Text('DISTRACTION SCORE', style: p.h2),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            key: ValueKey('$epoch/$pct'),
            tween: Tween(begin: 0, end: pct.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              '${v.round()}%',
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 62,
                height: 1,
                color: tone,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PixelProgressBar(value: pct / 100, height: 8, color: tone),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('TIME LOST TO BLOCKED APPS', style: p.label),
              const Spacer(),
              Text(
                minutesLabel(blockedSeconds ~/ 60),
                style: TextStyle(
                  fontFamily: kFontTerminal,
                  fontSize: 16,
                  height: 1,
                  color: p.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({
    required this.app,
    required this.fraction,
    required this.reveal,
    required this.isBlocked,
  });

  final _AppUsage app;
  final double fraction;
  final double reveal;
  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final h = app.seconds ~/ 3600;
    final m = (app.seconds % 3600) ~/ 60;
    final label = '${h}H ${m.toString().padLeft(2, '0')}M';
    return Opacity(
      opacity: reveal,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - reveal)),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Column(
            children: [
              Row(
                children: [
                  AppIconImage(packageName: app.packageName, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app.appName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontTerminal,
                        fontSize: 21,
                        height: 1.05,
                        color: p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isBlocked) ...[
                    PixelIcon(
                      Px.block,
                      color: p.danger.withValues(alpha: 0.7),
                      size: 11,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 20,
                      height: 1.05,
                      color: p.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: PixelProgressBar(
                  value: fraction.clamp(0.0, 1.0),
                  height: 5,
                  segments: 30,
                  color: p.accentDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionGate extends StatelessWidget {
  const _PermissionGate({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: PixelCard(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 130,
                child: EmptyState(
                  message: 'THE WIRED CANNOT SEE YOUR DEVICE',
                  glyph: Px.eye,
                ),
              ),
              const SizedBox(height: 20),
              PixelButton(
                label: 'GRANT USAGE ACCESS',
                filled: true,
                expand: true,
                onTap: onGrant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningLabel extends StatelessWidget {
  const _ScanningLabel();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SCANNING THE WIRED...',
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 19,
                height: 1,
                color: p.textDim,
              ),
            ),
            const SizedBox(width: 8),
            BlinkingCursor(width: 9, height: 16, color: p.accentDim),
          ],
        ),
      ),
    );
  }
}
