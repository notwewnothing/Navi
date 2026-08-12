import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/block_rule.dart';
import '../../services/block_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/tactile.dart';

Future<void> showRuleEditSheet(BuildContext context, {BlockRule? rule}) {
  final store = BlockScope.of(context);
  return showPixelSheet<void>(
    context: context,
    builder: (_) => _RuleEditSheet(store: store, rule: rule),
  );
}

enum _Field { start, end }

class _RuleEditSheet extends StatefulWidget {
  const _RuleEditSheet({required this.store, this.rule});

  final BlockStore store;
  final BlockRule? rule;

  @override
  State<_RuleEditSheet> createState() => _RuleEditSheetState();
}

class _RuleEditSheetState extends State<_RuleEditSheet> {
  late List<String> _packages = [...(widget.rule?.packages ?? const [])];
  late int _startMin = widget.rule?.startMin ?? 22 * 60;
  late int _endMin = widget.rule?.endMin ?? 6 * 60;
  late int _dayBits = widget.rule?.dayBits ?? 0x7f;
  late bool _enabled = widget.rule?.enabled ?? true;
  _Field? _open;

  late final _startHour =
      FixedExtentScrollController(initialItem: _startMin ~/ 60);
  late final _startMinute =
      FixedExtentScrollController(initialItem: _startMin % 60);
  late final _endHour = FixedExtentScrollController(initialItem: _endMin ~/ 60);
  late final _endMinute =
      FixedExtentScrollController(initialItem: _endMin % 60);

  bool get _editing => widget.rule != null;
  bool get _overnight => _endMin < _startMin;

  @override
  void dispose() {
    _startHour.dispose();
    _startMinute.dispose();
    _endHour.dispose();
    _endMinute.dispose();
    super.dispose();
  }

  static String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:'
      '${(min % 60).toString().padLeft(2, '0')}';

  void _toggleField(_Field field) {
    setState(() => _open = _open == field ? null : field);
  }

  Future<void> _pickApps() async {
    final result = await showAppPickerSheet(context, initial: _packages);
    if (result == null || !mounted) return;
    setState(() => _packages = result);
  }

  Future<void> _save() async {
    if (_packages.isEmpty) return;
    final rule = widget.rule;
    if (rule == null) {
      await widget.store.addRule(
        packages: _packages,
        startMin: _startMin,
        endMin: _endMin,
        dayBits: _dayBits,
      );
    } else {
      rule
        ..packages = _packages
        ..startMin = _startMin
        ..endMin = _endMin
        ..dayBits = _dayBits
        ..enabled = _enabled;
      await widget.store.updateRule(rule);
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Sfx.complete();
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final rule = widget.rule;
    if (rule == null) return;
    final confirmed = await showPixelDialog<bool>(
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
    if (confirmed != true || !mounted) return;
    await widget.store.removeRule(rule);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Sfx.glitch();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
                Text(
                  _editing ? 'EDIT RULE' : 'NEW RULE',
                  style: p.h2.copyWith(color: p.text),
                ),
                const Spacer(),
                if (_editing) ...[
                  Text('ACTIVE', style: p.label),
                  const SizedBox(width: 10),
                  PixelSwitch(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),

            PixelButton(
              label: 'SELECT APPS (${_packages.length})',
              glyph: Px.grid,
              expand: true,
              height: 46,
              onTap: _pickApps,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _packages.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'AT LEAST 1 APP REQUIRED',
                        style: p.label.copyWith(
                          color: p.danger.withValues(alpha: 0.85),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppIconStack(packages: _packages, size: 24),
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            Text('TIME WINDOW', style: p.h2),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimeChip(
                    label: 'FROM',
                    minutes: _startMin,
                    open: _open == _Field.start,
                    onTap: () => _toggleField(_Field.start),
                  ),
                ),
                const SizedBox(width: 8),
                PixelIcon(Px.right, color: p.textGhost, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeChip(
                    label: 'TO',
                    minutes: _endMin,
                    open: _open == _Field.end,
                    onTap: () => _toggleField(_Field.end),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: switch (_open) {
                null => const SizedBox(width: double.infinity),
                final field => Padding(
                  key: ValueKey(field),
                  padding: const EdgeInsets.only(top: 14),
                  child: SizedBox(
                    height: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PixelWheel(
                          itemCount: 24,
                          controller: field == _Field.start
                              ? _startHour
                              : _endHour,
                          labelFor: (i) => i.toString().padLeft(2, '0'),
                          onChanged: (i) => setState(() {
                            final h = i % 24;
                            if (field == _Field.start) {
                              _startMin = h * 60 + _startMin % 60;
                            } else {
                              _endMin = h * 60 + _endMin % 60;
                            }
                          }),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontFamily: kFontTerminal,
                              fontSize: 40,
                              color: p.accentDim,
                              height: 1,
                            ),
                          ),
                        ),
                        PixelWheel(
                          itemCount: 60,
                          controller: field == _Field.start
                              ? _startMinute
                              : _endMinute,
                          labelFor: (i) => i.toString().padLeft(2, '0'),
                          onChanged: (i) => setState(() {
                            final m = i % 60;
                            if (field == _Field.start) {
                              _startMin = (_startMin ~/ 60) * 60 + m;
                            } else {
                              _endMin = (_endMin ~/ 60) * 60 + m;
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _overnight
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          PixelIcon(Px.moon, color: p.sleepDot, size: 12),
                          const SizedBox(width: 8),
                          Text(
                            'OVERNIGHT — ENDS NEXT DAY',
                            style: p.label.copyWith(color: p.sleepDot),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 20),

            Text('DAYS', style: p.h2),
            const SizedBox(height: 10),
            DayPicker(
              dayBits: _dayBits,
              onChanged: (bits) => setState(() => _dayBits = bits),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                if (_editing)
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
                  onTap: _packages.isEmpty ? null : _save,
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
    required this.open,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final bool open;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: open ? p.panelHi : Colors.transparent,
            border: Border.all(
              color: open ? p.accent : p.border,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: p.label.copyWith(color: open ? p.accent : p.textDim),
              ),
              const SizedBox(height: 6),
              Text(
                _RuleEditSheetState._fmt(minutes),
                style: TextStyle(
                  fontFamily: kFontTerminal,
                  fontSize: 34,
                  color: open ? p.accent : p.text,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppIconStack extends StatelessWidget {
  const AppIconStack({
    super.key,
    required this.packages,
    this.size = 24,
    this.max = 5,
  });

  final List<String> packages;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shown = packages.take(max).toList();
    final overflow = packages.length - shown.length;
    final step = size * 0.7;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown.isEmpty ? 0 : (shown.length - 1) * step + size + 2,
          height: size + 2,
          child: Stack(
            children: [
              for (final (i, pkg) in shown.indexed)
                Positioned(
                  left: i * step,
                  top: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.bg,
                      border: Border.all(color: p.border),
                    ),
                    child: AppIconImage(packageName: pkg, size: size),
                  ),
                ),
            ],
          ),
        ),
        if (overflow > 0) ...[
          const SizedBox(width: 8),
          Text(
            '+$overflow',
            style: TextStyle(
              fontFamily: kFontTerminal,
              fontSize: size * 0.75,
              color: p.textDim,
            ),
          ),
        ],
      ],
    );
  }
}
