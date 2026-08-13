import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/schedule_event.dart';
import '../../services/schedule_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/tactile.dart';

Color eventTypeColor(NaviPalette p, EventType type) => switch (type) {
  EventType.focus => p.focusDot,
  EventType.sleep => p.sleepDot,
  EventType.alarm => p.alarmDot,
  EventType.appBlock => p.blockDot,
  EventType.custom => p.journalDot,
};

String hhmm(int minutes) {
  final m = minutes % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

Future<void> showEventEditSheet(
  BuildContext context, {
  ScheduleEvent? event,
  DateTime? day,
  int? startMin,
  int? endMin,
}) {
  return showPixelSheet<void>(
    context: context,
    builder: (context) => _EventEditSheet(
      event: event,
      day: day,
      startMin: startMin,
      endMin: endMin,
    ),
  );
}

enum _TimeField { start, end }

class _EventEditSheet extends StatefulWidget {
  const _EventEditSheet({this.event, this.day, this.startMin, this.endMin});

  final ScheduleEvent? event;
  final DateTime? day;
  final int? startMin;
  final int? endMin;

  @override
  State<_EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<_EventEditSheet> {
  late final TextEditingController _titleCtrl;
  late EventType _type;
  late int _startMin;
  late int _endMin;
  late EventRepeat _repeat;
  late int _dayBits;
  late List<String> _packages;
  late int _snooze;
  late DateTime _anchorDay;

  _TimeField? _editing;
  FixedExtentScrollController? _hourCtrl;
  FixedExtentScrollController? _minCtrl;
  final _retired = <FixedExtentScrollController>[];

  static const _monthsShort = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    final now = DateTime.now();
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _type = e?.type ?? EventType.focus;
    _startMin = e?.startMin ?? widget.startMin ?? ((now.hour + 1) % 24) * 60;
    _endMin = e?.endMin ?? widget.endMin ?? (_startMin + 60) % 1440;
    _repeat = e?.repeat ?? EventRepeat.never;
    _dayBits = e?.dayBits ?? 0;
    _packages = [...?e?.packages];
    _snooze = e?.snoozeMinutes ?? 10;
    _anchorDay =
        widget.day ?? e?.anchorDay ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _hourCtrl?.dispose();
    _minCtrl?.dispose();
    for (final c in _retired) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleField(_TimeField field) {
    setState(() {
      if (_editing == field) {
        _editing = null;
        return;
      }
      _editing = field;
      final value = field == _TimeField.start ? _startMin : _endMin;
      if (_hourCtrl != null) _retired.add(_hourCtrl!);
      if (_minCtrl != null) _retired.add(_minCtrl!);
      _hourCtrl = FixedExtentScrollController(initialItem: value ~/ 60);
      _minCtrl = FixedExtentScrollController(initialItem: value % 60);
    });
  }

  void _wheelChanged({int? hour, int? minute}) {
    final field = _editing;
    if (field == null) return;
    setState(() {
      final current = field == _TimeField.start ? _startMin : _endMin;
      final h = hour ?? current ~/ 60;
      final m = minute ?? current % 60;
      final value = h * 60 + m;
      if (field == _TimeField.start) {
        _startMin = value;
      } else {
        _endMin = value;
      }
    });
  }

  void _setType(EventType type) {
    setState(() {
      _type = type;
      if (type == EventType.alarm && _editing == _TimeField.end) {
        _editing = null;
      }
    });
  }

  void _setRepeat(EventRepeat repeat) {
    setState(() {
      _repeat = repeat;
      if (repeat == EventRepeat.custom && _dayBits == 0) {
        _dayBits = 1 << (_anchorDay.weekday - 1);
      }
    });
  }

  Future<void> _pickApps() async {
    final picked = await showAppPickerSheet(context, initial: _packages);
    if (picked != null && mounted) {
      setState(() => _packages = picked);
    }
  }

  Future<void> _save() async {
    final store = ScheduleScope.of(context);
    final nav = Navigator.of(context);
    final title = _titleCtrl.text.trim().isEmpty
        ? _type.label
        : _titleCtrl.text.trim();
    final endMin = _type == EventType.alarm ? _startMin : _endMin;
    var dayBits = _dayBits;
    if (_repeat == EventRepeat.custom && dayBits == 0) {
      dayBits = 1 << (_anchorDay.weekday - 1);
    }
    if (widget.event case final event?) {
      event
        ..title = title
        ..type = _type
        ..startMin = _startMin
        ..endMin = endMin
        ..repeat = _repeat
        ..dayBits = dayBits
        ..packages = _packages
        ..snoozeMinutes = _snooze;
      await store.update(event);
    } else {
      await store.add(
        title: title,
        type: _type,
        startMin: _startMin,
        endMin: endMin,
        repeat: _repeat,
        dayBits: dayBits,
        anchorDay: _anchorDay,
        packages: _packages,
        snoozeMinutes: _snooze,
      );
    }
    Sfx.complete();
    nav.pop();
  }

  Future<void> _delete() async {
    final store = ScheduleScope.of(context);
    final nav = Navigator.of(context);
    await store.remove(widget.event!);
    Sfx.glitch();
    nav.pop();
  }

  String get _durationLabel {
    // overnight events wrap around, a full day reads 24H not 0H
    var d = (_endMin - _startMin) % 1440;
    if (d == 0) d = 1440;
    final h = d ~/ 60;
    final m = d % 60;
    return [if (h > 0) '${h}H', if (m > 0) '${m}M'].join(' ');
  }

  String get _anchorLabel =>
      '${_monthsShort[_anchorDay.month - 1]} ${_anchorDay.day} ${_anchorDay.year}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isAlarm = _type == EventType.alarm;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, color: eventTypeColor(p, _type)),
                const SizedBox(width: 10),
                Text(
                  _isEditing ? 'EDIT EVENT' : 'NEW EVENT',
                  style: p.h2.copyWith(color: p.text),
                ),
                const Spacer(),
                if (_repeat == EventRepeat.never)
                  Text(
                    _anchorLabel,
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 16,
                      color: p.textDim,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            PixelTextField(
              controller: _titleCtrl,
              hint: 'Event title...',
              fontSize: 22,
            ),
            const SizedBox(height: 20),

            Text('TYPE', style: p.h2),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in EventType.values)
                  PixelChip(
                    label: type.label,
                    selected: _type == type,
                    onTap: () => _setType(type),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Text('TIME', style: p.h2),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimeChip(
                    label: 'START',
                    minutes: _startMin,
                    active: _editing == _TimeField.start,
                    onTap: () => _toggleField(_TimeField.start),
                  ),
                ),
                if (!isAlarm) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeChip(
                      label: 'END',
                      minutes: _endMin,
                      active: _editing == _TimeField.end,
                      onTap: () => _toggleField(_TimeField.end),
                    ),
                  ),
                ],
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _editing == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        height: 132,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PixelWheel(
                              itemCount: 24,
                              controller: _hourCtrl!,
                              labelFor: (i) => i.toString().padLeft(2, '0'),
                              fontSize: 38,
                              onChanged: (i) => _wheelChanged(hour: i % 24),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontFamily: kFontTerminal,
                                  fontSize: 38,
                                  color: p.accent,
                                  height: 1,
                                ),
                              ),
                            ),
                            PixelWheel(
                              itemCount: 60,
                              controller: _minCtrl!,
                              labelFor: (i) => i.toString().padLeft(2, '0'),
                              fontSize: 38,
                              onChanged: (i) => _wheelChanged(minute: i % 60),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (!isAlarm)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Text('DURATION', style: p.label),
                    const Spacer(),
                    Text(
                      _durationLabel,
                      style: TextStyle(
                        fontFamily: kFontTerminal,
                        fontSize: 17,
                        color: p.accentMid,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            Text('REPEAT', style: p.h2),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final repeat in EventRepeat.values)
                  PixelChip(
                    label: repeat.label,
                    selected: _repeat == repeat,
                    onTap: () => _setRepeat(repeat),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _repeat == EventRepeat.custom
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: DayPicker(
                        dayBits: _dayBits,
                        onChanged: (bits) => setState(() => _dayBits = bits),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: switch (_type) {
                EventType.appBlock => Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('APPS', style: p.h2),
                        const SizedBox(height: 10),
                        PixelButton(
                          label: 'SELECT APPS (${_packages.length})',
                          glyph: Px.grid,
                          expand: true,
                          height: 44,
                          onTap: _pickApps,
                        ),
                      ],
                    ),
                  ),
                EventType.alarm => Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('SNOOZE', style: p.h2),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final m in const [5, 10, 15]) ...[
                              PixelChip(
                                label: '$m MIN',
                                selected: _snooze == m,
                                onTap: () => setState(() => _snooze = m),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text('SOUND', style: p.label),
                            const Spacer(),
                            PixelIcon(Px.bell, color: p.accent, size: 12),
                            const SizedBox(width: 8),
                            Text(
                              'BLAST',
                              style: TextStyle(
                                fontFamily: kFontTerminal,
                                fontSize: 20,
                                color: p.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                _ => const SizedBox(width: double.infinity),
              },
            ),
            const SizedBox(height: 26),

            Row(
              children: [
                if (_isEditing)
                  PixelButton(
                    label: 'DELETE',
                    danger: true,
                    height: 44,
                    onTap: _delete,
                  ),
                const Spacer(),
                DialogAction(
                  label: 'CANCEL',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                PixelButton(
                  label: 'SAVE',
                  filled: true,
                  height: 44,
                  onTap: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.minutes,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.95,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Sfx.tick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? p.accentGhost.withValues(alpha: 0.4)
                : Colors.transparent,
            border: Border.all(
              color: active ? p.accent : p.border,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: p.label.copyWith(color: active ? p.accent : p.textDim),
              ),
              const SizedBox(height: 4),
              Text(
                hhmm(minutes),
                style: TextStyle(
                  fontFamily: kFontTerminal,
                  fontSize: 30,
                  height: 1,
                  color: active ? p.accent : p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
