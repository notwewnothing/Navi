import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/schedule_event.dart';
import '../../services/schedule_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
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
  return showNdSheet<void>(
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
    Sfx.tick();
    nav.pop();
  }

  String get _durationLabel {
    // overnight events wrap around, a full day reads 24H not 0H
    var d = (_endMin - _startMin) % 1440;
    if (d == 0) d = 1440;
    final h = d ~/ 60;
    final m = d % 60;
    return [if (h > 0) '${h}h', if (m > 0) '${m}m'].join(' ');
  }

  String get _anchorLabel =>
      '${_anchorDay.day} ${_monthsShort[_anchorDay.month - 1]} ${_anchorDay.year}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isAlarm = _type == EventType.alarm;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NdSheetHeader(
            title: _isEditing ? 'Edit event' : 'New event',
            actions: [
              if (_repeat == EventRepeat.never)
                Padding(
                  padding: const EdgeInsets.only(right: NdSpace.sm),
                  child: Text(_anchorLabel, style: p.label),
                ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                NdSpace.page,
                0,
                NdSpace.page,
                NdSpace.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NdTextField(controller: _titleCtrl, hint: 'Event title'),
                  const SizedBox(height: NdSpace.xl),

                  Text('TYPE', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  Wrap(
                    spacing: NdSpace.sm,
                    runSpacing: NdSpace.sm,
                    children: [
                      for (final type in EventType.values)
                        NdChip(
                          label: type.label,
                          selected: _type == type,
                          onTap: () => _setType(type),
                        ),
                    ],
                  ),
                  const SizedBox(height: NdSpace.xl),

                  Text('TIME', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeChip(
                          label: 'Starts',
                          minutes: _startMin,
                          active: _editing == _TimeField.start,
                          onTap: () => _toggleField(_TimeField.start),
                        ),
                      ),
                      if (!isAlarm) ...[
                        const SizedBox(width: NdSpace.md),
                        Expanded(
                          child: _TimeChip(
                            label: 'Ends',
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
                            padding: const EdgeInsets.only(top: NdSpace.md),
                            child: SizedBox(
                              height: 140,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  NdWheel(
                                    itemCount: 24,
                                    controller: _hourCtrl!,
                                    labelFor: (i) =>
                                        i.toString().padLeft(2, '0'),
                                    fontSize: 38,
                                    onChanged: (i) =>
                                        _wheelChanged(hour: i % 24),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: NdSpace.xs,
                                    ),
                                    child: Text(
                                      ':',
                                      style: p.dot(34, color: p.textGhost),
                                    ),
                                  ),
                                  NdWheel(
                                    itemCount: 60,
                                    controller: _minCtrl!,
                                    labelFor: (i) =>
                                        i.toString().padLeft(2, '0'),
                                    fontSize: 38,
                                    onChanged: (i) =>
                                        _wheelChanged(minute: i % 60),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  if (!isAlarm)
                    Padding(
                      padding: const EdgeInsets.only(top: NdSpace.md),
                      child: Row(
                        children: [
                          Text('Duration', style: p.label),
                          const Spacer(),
                          Text(
                            _durationLabel,
                            style: p.label.copyWith(color: p.accent),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: NdSpace.xl),

                  Text('REPEAT', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  Wrap(
                    spacing: NdSpace.sm,
                    runSpacing: NdSpace.sm,
                    children: [
                      for (final repeat in EventRepeat.values)
                        NdChip(
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
                            padding: const EdgeInsets.only(top: NdSpace.md),
                            child: DayPicker(
                              dayBits: _dayBits,
                              onChanged: (bits) =>
                                  setState(() => _dayBits = bits),
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
                        padding: const EdgeInsets.only(top: NdSpace.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('APPS TO BLOCK', style: p.h2),
                            const SizedBox(height: NdSpace.md),
                            NdButton(
                              label: _packages.isEmpty
                                  ? 'Choose apps'
                                  : '${_packages.length} app'
                                        '${_packages.length == 1 ? '' : 's'} selected',
                              glyph: Nd.grid,
                              expand: true,
                              height: 48,
                              onTap: _pickApps,
                            ),
                          ],
                        ),
                      ),
                      EventType.alarm => Padding(
                        padding: const EdgeInsets.only(top: NdSpace.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('SNOOZE', style: p.h2),
                            const SizedBox(height: NdSpace.md),
                            Row(
                              children: [
                                for (final m in const [5, 10, 15]) ...[
                                  NdChip(
                                    label: '$m min',
                                    selected: _snooze == m,
                                    onTap: () => setState(() => _snooze = m),
                                  ),
                                  const SizedBox(width: NdSpace.sm),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      _ => const SizedBox(width: double.infinity),
                    },
                  ),
                ],
              ),
            ),
          ),
          // pinned so Save stays reachable however tall the form gets
          Container(
            padding: const EdgeInsets.fromLTRB(
              NdSpace.page,
              NdSpace.md,
              NdSpace.page,
              NdSpace.md,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Row(
              children: [
                if (_isEditing)
                  NdButton(
                    label: 'Delete',
                    danger: true,
                    height: 46,
                    onTap: _delete,
                  ),
                const Spacer(),
                DialogAction(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: NdSpace.xs),
                NdButton(label: 'Save', filled: true, height: 46, onTap: _save),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(
            horizontal: NdSpace.lg,
            vertical: NdSpace.md,
          ),
          decoration: BoxDecoration(
            color: p.panelHi,
            borderRadius: BorderRadius.circular(NdRadius.inner),
            border: Border.all(color: active ? p.accent : p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: p.micro.copyWith(color: active ? p.accent : p.textDim),
              ),
              const SizedBox(height: NdSpace.xs),
              Text(
                hhmm(minutes),
                style: p.dot(28, color: active ? p.accent : p.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
