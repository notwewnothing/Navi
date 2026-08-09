import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/tactile.dart';

Future<void> showHabitEditSheet(BuildContext context, {Habit? habit}) {
  return showPixelSheet<void>(
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
  late final TextEditingController _nameController = TextEditingController(
    text: widget.habit?.name ?? '',
  )..addListener(() => setState(() {}));

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
    if (_seededDefaults) return;
    _seededDefaults = true;
    _reminderMinutes = widget.habit?.reminderMinutes ??
        SettingsScope.of(context).defaultReminderMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _hhmm(int minutes) {
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickTime() async {
    final p = context.palette;
    var hour = _reminderMinutes ~/ 60;
    var minute = _reminderMinutes % 60;
    final hourController = FixedExtentScrollController(initialItem: hour);
    final minuteController = FixedExtentScrollController(initialItem: minute);
    final result = await showPixelDialog<int>(
      context: context,
      title: 'REMINDER TIME',
      builder: (context) => SizedBox(
        height: 168,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PixelWheel(
              itemCount: 24,
              controller: hourController,
              labelFor: (i) => i.toString().padLeft(2, '0'),
              width: 68,
              fontSize: 40,
              onChanged: (i) => hour = i,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                ':',
                style: TextStyle(
                  fontFamily: kFontTerminal,
                  fontSize: 40,
                  color: p.accent,
                  height: 1,
                ),
              ),
            ),
            PixelWheel(
              itemCount: 60,
              controller: minuteController,
              labelFor: (i) => i.toString().padLeft(2, '0'),
              width: 68,
              fontSize: 40,
              onChanged: (i) => minute = i,
            ),
          ],
        ),
      ),
      actions: (context) => [
        DialogAction(label: 'CANCEL', onTap: () => Navigator.pop(context)),
        DialogAction(
          label: 'SET',
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, color: p.accent),
                const SizedBox(width: 10),
                Text(
                  widget.habit == null ? 'NEW HABIT' : 'EDIT HABIT',
                  style: p.h1.copyWith(fontSize: 12),
                ),
                const Spacer(),
                PixelIconButton(
                  glyph: Px.x,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PixelTextField(
              controller: _nameController,
              hint: 'NAME THE PROTOCOL...',
              capitalization: TextCapitalization.characters,
              autofocus: widget.habit == null,
            ),
            const SizedBox(height: 20),
            Text('ICON', style: p.h2),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final MapEntry(key: name, value: glyph)
                    in Px.habitIcons.entries)
                  _IconCell(
                    glyph: glyph,
                    selected: _icon == name,
                    onTap: () => setState(() => _icon = name),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('REQUIRE PHOTO PROOF', style: p.h2)),
                PixelSwitch(
                  value: _requirePhoto,
                  onChanged: (v) => setState(() => _requirePhoto = v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('REMINDER', style: p.h2)),
                PixelSwitch(
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
                      padding: const EdgeInsets.only(top: 12),
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
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: p.panelHi,
                                border: Border.all(color: p.accentDim),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PixelIcon(Px.bell, color: p.accent, size: 13),
                                  const SizedBox(width: 10),
                                  Text(
                                    _hhmm(_reminderMinutes),
                                    style: TextStyle(
                                      fontFamily: kFontTerminal,
                                      fontSize: 26,
                                      color: p.text,
                                      height: 1,
                                    ),
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
            const SizedBox(height: 18),
            Text('DAYS', style: p.h2),
            const SizedBox(height: 10),
            DayPicker(
              dayBits: _dayBits,
              onChanged: (v) => setState(() => _dayBits = v),
            ),
            const SizedBox(height: 18),
            Text('COLOR', style: p.h2),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (i, color) in habitDotColors.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
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
            const SizedBox(height: 24),
            PixelButton(
              label: 'SAVE',
              filled: true,
              expand: true,
              onTap: canSave ? _save : null,
            ),
          ],
        ),
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

  final PixelGlyph glyph;
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
            color: selected ? p.accentGhost : Colors.transparent,
            border: Border.all(
              color: selected ? p.accent : p.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: PixelIcon(
              glyph,
              color: selected ? p.accent : p.textDim,
              size: 17,
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
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.white : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Container(color: color),
        ),
      ),
    );
  }
}
