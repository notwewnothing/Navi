import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/block_rule.dart';
import '../../services/block_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/tactile.dart';

Future<void> showRuleEditSheet(BuildContext context, {BlockRule? rule}) {
  final store = BlockScope.of(context);
  return showNdSheet<void>(
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
  // defaults to an overnight rule, endMin < startMin means it crosses midnight
  late int _endMin = widget.rule?.endMin ?? 6 * 60;
  late int _dayBits = widget.rule?.dayBits ?? 0x7f;
  late bool _enabled = widget.rule?.enabled ?? true;
  _Field? _open;

  late final _startHour = FixedExtentScrollController(
    initialItem: _startMin ~/ 60,
  );
  late final _startMinute = FixedExtentScrollController(
    initialItem: _startMin % 60,
  );
  late final _endHour = FixedExtentScrollController(initialItem: _endMin ~/ 60);
  late final _endMinute = FixedExtentScrollController(
    initialItem: _endMin % 60,
  );

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
    final confirmed = await showNdDialog<bool>(
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
    if (confirmed != true || !mounted) return;
    await widget.store.removeRule(rule);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Sfx.tick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NdSheetHeader(
            title: _editing ? 'Edit rule' : 'New rule',
            actions: [
              if (_editing) ...[
                Text('Active', style: p.label),
                const SizedBox(width: NdSpace.md),
                NdSwitch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                const SizedBox(width: NdSpace.sm),
              ],
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
                  NdButton(
                    label: _packages.isEmpty
                        ? 'Choose apps to block'
                        : '${_packages.length} app'
                              '${_packages.length == 1 ? '' : 's'} selected',
                    glyph: Nd.grid,
                    expand: true,
                    height: 48,
                    onTap: _pickApps,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _packages.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: NdSpace.sm),
                            child: Text(
                              'Pick at least one app to save this rule',
                              style: p.label.copyWith(color: p.danger),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: NdSpace.md),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AppIconStack(
                                packages: _packages,
                                size: 24,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: NdSpace.xl),

                  Text('TIME WINDOW', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeChip(
                          label: 'From',
                          minutes: _startMin,
                          open: _open == _Field.start,
                          onTap: () => _toggleField(_Field.start),
                        ),
                      ),
                      const SizedBox(width: NdSpace.sm),
                      NdIcon(Nd.right, color: p.textGhost, size: 18),
                      const SizedBox(width: NdSpace.sm),
                      Expanded(
                        child: _TimeChip(
                          label: 'To',
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
                        padding: const EdgeInsets.only(top: NdSpace.lg),
                        child: SizedBox(
                          height: 156,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              NdWheel(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: NdSpace.xs,
                                ),
                                child: Text(
                                  ':',
                                  style: p.dot(40, color: p.textGhost),
                                ),
                              ),
                              NdWheel(
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
                            padding: const EdgeInsets.only(top: NdSpace.md),
                            child: Row(
                              children: [
                                NdIcon(Nd.moon, color: p.sleepDot, size: 16),
                                const SizedBox(width: NdSpace.sm),
                                Text(
                                  'Runs overnight, ending the next morning',
                                  style: p.label.copyWith(color: p.sleepDot),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: NdSpace.xl),

                  Text('DAYS', style: p.h2),
                  const SizedBox(height: NdSpace.md),
                  DayPicker(
                    dayBits: _dayBits,
                    onChanged: (bits) => setState(() => _dayBits = bits),
                  ),
                  const SizedBox(height: NdSpace.xxl),

                  Row(
                    children: [
                      if (_editing)
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
                      NdButton(
                        label: 'Save',
                        filled: true,
                        height: 46,
                        onTap: _packages.isEmpty ? null : _save,
                      ),
                    ],
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
          padding: const EdgeInsets.symmetric(
            horizontal: NdSpace.lg,
            vertical: NdSpace.md,
          ),
          decoration: BoxDecoration(
            color: p.panelHi,
            borderRadius: BorderRadius.circular(NdRadius.inner),
            border: Border.all(color: open ? p.accent : p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: p.micro.copyWith(color: open ? p.accent : p.textDim),
              ),
              const SizedBox(height: NdSpace.xs),
              Text(
                _RuleEditSheetState._fmt(minutes),
                style: p.dot(30, color: open ? p.accent : p.text),
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
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: p.bg,
                      border: Border.all(color: p.border),
                      borderRadius: BorderRadius.circular(size * 0.28),
                    ),
                    child: AppIconImage(packageName: pkg, size: size),
                  ),
                ),
            ],
          ),
        ),
        if (overflow > 0) ...[
          const SizedBox(width: NdSpace.sm),
          Text('+$overflow', style: p.dot(size * 0.7, color: p.textDim)),
        ],
      ],
    );
  }
}
