import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/tactile.dart';

Future<void> showHabitEditSheet(BuildContext context, {Habit? habit}) {
  return showNdSheet<void>(
    context: context,
    builder: (context) => _HabitEditSheet(habit: habit),
  );
}

class _HabitEditSheet extends StatefulWidget {
  const _HabitEditSheet({this.habit});

  final Habit? habit;

  @override
  State<_HabitEditSheet> createState() => _HabitEditSheetState();
}

class _HabitEditSheetState extends State<_HabitEditSheet> {
  // the listener only drives the Save button's enabled state, so the
  // description controller doesn't need one
  late final TextEditingController _nameController = TextEditingController(
    text: widget.habit?.name ?? '',
  )..addListener(() => setState(() {}));

  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.habit?.description ?? '');

  late String _icon = widget.habit?.icon ?? 'flame';
  late bool _requirePhoto = widget.habit?.requirePhoto ?? false;
  late bool _reminderOn = widget.habit?.reminderMinutes != null;
  late int _dayBits = widget.habit?.dayBits ?? 0x7f;
  late int _colorIndex = widget.habit?.colorIndex ?? 0;

  int _reminderMinutes = 9 * 60;
  bool _seededDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SettingsScope isn't reachable from initState, seed the reminder default once dependencies arrive
    if (_seededDefaults) return;
    _seededDefaults = true;
    _reminderMinutes =
        widget.habit?.reminderMinutes ??
        SettingsScope.of(context).defaultReminderMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _hhmm(int minutes) {
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickTime() async {
    var hour = _reminderMinutes ~/ 60;
    var minute = _reminderMinutes % 60;
    final hourController = FixedExtentScrollController(initialItem: hour);
    final minuteController = FixedExtentScrollController(initialItem: minute);
    final result = await showNdDialog<int>(
      context: context,
      title: 'Reminder time',
      builder: (context) => SizedBox(
        height: 176,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NdWheel(
              itemCount: 24,
              controller: hourController,
              labelFor: (i) => i.toString().padLeft(2, '0'),
              width: 72,
              fontSize: 40,
              onChanged: (i) => hour = i,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NdSpace.xs),
              child: Text(
                ':',
                style: context.palette.dot(
                  36,
                  color: context.palette.textGhost,
                ),
              ),
            ),
            NdWheel(
              itemCount: 60,
              controller: minuteController,
              labelFor: (i) => i.toString().padLeft(2, '0'),
              width: 72,
              fontSize: 40,
              onChanged: (i) => minute = i,
            ),
          ],
        ),
      ),
      actions: (context) => [
        DialogAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
        DialogAction(
          label: 'Set',
          emphasized: true,
          onTap: () => Navigator.pop(context, hour * 60 + minute),
        ),
      ],
    );
    hourController.dispose();
    minuteController.dispose();
    if (result != null && mounted) {
      setState(() => _reminderMinutes = result);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final store = HabitScope.of(context);
    if (widget.habit == null) {
      await store.addHabit(
        name: name,
        description: _descriptionController.text.trim(),
        icon: _icon,
        requirePhoto: _requirePhoto,
        reminderMinutes: _reminderOn ? _reminderMinutes : null,
        dayBits: _dayBits,
        colorIndex: _colorIndex,
      );
    } else {
      final habit = widget.habit!;
      habit
        ..name = name
        ..description = _descriptionController.text.trim()
        ..icon = _icon
        ..requirePhoto = _requirePhoto
        ..reminderMinutes = _reminderOn ? _reminderMinutes : null
        ..dayBits = _dayBits
        ..colorIndex = _colorIndex;
      await store.updateHabit(habit);
    }
    if (!mounted) return;
    Sfx.complete();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canSave = _nameController.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NdSheetHeader(
            title: widget.habit == null ? 'New habit' : 'Edit habit',
            actions: [
              NdIconButton(glyph: Nd.x, onTap: () => Navigator.pop(context)),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                NdSpace.page,
                0,
                NdSpace.page,
                NdSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NdTextField(
                    controller: _nameController,
                    hint: 'e.g. Read for 20 minutes',
                    capitalization: TextCapitalization.sentences,
                    autofocus: widget.habit == null,
                  ),
                  const SizedBox(height: NdSpace.md),
                  NdTextField(
                    controller: _descriptionController,
                    hint: 'Short description (optional)',
                    capitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    fontSize: 14,
                  ),
                  const SizedBox(height: NdSpace.xl),
                  Text('ICON', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  GridView.count(
                    crossAxisCount: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: NdSpace.sm,
                    crossAxisSpacing: NdSpace.sm,
                    children: [
                      for (final MapEntry(key: name, value: glyph)
                          in Nd.habitIcons.entries)
                        _IconCell(
                          glyph: glyph,
                          selected: _icon == name,
                          onTap: () => setState(() => _icon = name),
                        ),
                    ],
                  ),
                  const SizedBox(height: NdSpace.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Require photo proof', style: p.row),
                            const SizedBox(height: 2),
                            Text(
                              'Check-in asks for a photo first',
                              style: p.label.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: NdSpace.md),
                      NdSwitch(
                        value: _requirePhoto,
                        onChanged: (v) => setState(() => _requirePhoto = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: NdSpace.lg),
                  Row(
                    children: [
                      Expanded(child: Text('Daily reminder', style: p.row)),
                      const SizedBox(width: NdSpace.md),
                      NdSwitch(
                        value: _reminderOn,
                        onChanged: (v) => setState(() => _reminderOn = v),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _reminderOn
                        ? Padding(
                            padding: const EdgeInsets.only(top: NdSpace.md),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Tactile(
                                pressedScale: 0.94,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Sfx.tick();
                                    _pickTime();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: NdSpace.lg,
                                      vertical: NdSpace.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.panelHi,
                                      border: Border.all(color: p.borderHi),
                                      borderRadius: BorderRadius.circular(
                                        NdRadius.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        NdIcon(
                                          Nd.bell,
                                          color: p.accent,
                                          size: 16,
                                        ),
                                        const SizedBox(width: NdSpace.md),
                                        Text(
                                          _hhmm(_reminderMinutes),
                                          style: p.dot(22, color: p.text),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: NdSpace.xl),
                  Text('DAYS', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  DayPicker(
                    dayBits: _dayBits,
                    onChanged: (v) => setState(() => _dayBits = v),
                  ),
                  const SizedBox(height: NdSpace.xl),
                  Text('COLOUR', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  Row(
                    children: [
                      for (final (i, color) in habitDotColors.indexed) ...[
                        if (i > 0) const SizedBox(width: NdSpace.md),
                        Expanded(
                          child: _ColorCell(
                            color: color,
                            selected: _colorIndex == i,
                            onTap: () => setState(() => _colorIndex = i),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: NdSpace.xl),
                  NdButton(
                    label: widget.habit == null
                        ? 'Create habit'
                        : 'Save changes',
                    filled: true,
                    expand: true,
                    onTap: canSave ? _save : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  final NdGlyph glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.85,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Sfx.tick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? p.accent : Colors.transparent,
            border: Border.all(color: selected ? p.accent : p.border),
          ),
          child: Center(
            child: NdIcon(
              glyph,
              color: selected ? p.onAccent : p.textDim,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorCell extends StatelessWidget {
  const _ColorCell({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.85,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Sfx.tick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? p.text : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
