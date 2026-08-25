import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_blocker.dart';
import '../../services/block_store.dart';
import '../../services/device_admin_service.dart';
import '../../services/habit_store.dart';
import '../../services/journal_store.dart';
import '../../services/schedule_store.dart';
import '../../services/session_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/routes.dart';
import '../../widgets/tactile.dart';
import '../blocker/app_block_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onManageHabits});

  /// Invoked after this screen pops itself. Supplied by whoever pushed it,
  /// since that context still sits below the shell and can switch tabs.
  final VoidCallback? onManageHabits;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _accessibilityOn = false;
  bool _adminOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshServiceStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshServiceStatus();
  }

  Future<void> _refreshServiceStatus() async {
    final accessibility = await AppBlocker.isAccessibilityEnabled();
    final admin = await DeviceAdminService.isActiveAdmin();
    if (!mounted) return;
    setState(() {
      _accessibilityOn = accessibility;
      _adminOn = admin;
    });
  }

  Future<void> _pickAvatar() async {
    final settings = SettingsScope.of(context);
    final glyphs = Nd.habitIcons.values.toList();
    await showNdDialog<void>(
      context: context,
      title: 'Pick an avatar',
      builder: (context) {
        final p = context.palette;
        final selected = settings.avatarIndex;
        return Wrap(
          spacing: NdSpace.md,
          runSpacing: NdSpace.md,
          children: [
            for (final (i, glyph) in glyphs.indexed)
              Tactile(
                pressedScale: 0.88,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Sfx.tick();
                    settings.setAvatarIndex(i);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == selected ? p.accent : p.panelHi,
                      border: Border.all(
                        color: i == selected ? p.accent : p.border,
                      ),
                    ),
                    child: Center(
                      child: NdIcon(
                        glyph,
                        color: i == selected ? p.onAccent : p.textDim,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _editDisplayName() async {
    final settings = SettingsScope.of(context);
    final controller = TextEditingController(text: settings.displayName);
    await showNdDialog<void>(
      context: context,
      title: 'Your name',
      builder: (context) => NdTextField(
        controller: controller,
        hint: 'How should NAVI greet you?',
        autofocus: true,
        fontSize: 18,
        capitalization: TextCapitalization.words,
      ),
      actions: (context) => [
        DialogAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
        DialogAction(
          label: 'Save',
          emphasized: true,
          onTap: () {
            Sfx.tick();
            settings.setDisplayName(controller.text);
            Navigator.pop(context);
          },
        ),
      ],
    );
    controller.dispose();
  }

  Future<void> _editDefaultReminder() async {
    final settings = SettingsScope.of(context);
    var hour = settings.defaultReminderMinutes ~/ 60;
    var minute = settings.defaultReminderMinutes % 60;
    final hourCtrl = FixedExtentScrollController(initialItem: hour);
    final minuteCtrl = FixedExtentScrollController(initialItem: minute);
    await showNdDialog<void>(
      context: context,
      title: 'Default reminder time',
      builder: (context) {
        final p = context.palette;
        return SizedBox(
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NdWheel(
                itemCount: 24,
                controller: hourCtrl,
                labelFor: (i) => i.toString().padLeft(2, '0'),
                onChanged: (i) => hour = ((i % 24) + 24) % 24,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: NdSpace.xs),
                child: Text(':', style: p.dot(40, color: p.textGhost)),
              ),
              NdWheel(
                itemCount: 60,
                controller: minuteCtrl,
                labelFor: (i) => i.toString().padLeft(2, '0'),
                onChanged: (i) => minute = ((i % 60) + 60) % 60,
              ),
            ],
          ),
        );
      },
      actions: (context) => [
        DialogAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
        DialogAction(
          label: 'Set',
          emphasized: true,
          onTap: () {
            Sfx.tick();
            settings.setDefaultReminderMinutes(hour * 60 + minute);
            Navigator.pop(context);
          },
        ),
      ],
    );
    hourCtrl.dispose();
    minuteCtrl.dispose();
  }

  Future<void> _exportData() async {
    final settings = SettingsScope.of(context);
    final sections = <String, String>{
      'settings-note':
          'Settings live on-device only. Everything else is below.',
      'habits': HabitScope.of(context).exportJson(),
      'journal': JournalScope.of(context).exportJson(),
      'schedule': ScheduleScope.of(context).exportJson(),
      'blocker': BlockScope.of(context).exportJson(),
      'sessions': SessionScope.of(context).exportJson(),
    };
    try {
      final path = await settings.exportData(sections);
      if (!mounted) return;
      Sfx.complete();
      final short = path.split('/').last;
      showNdToast(context, 'Exported to $short', glyph: Nd.export);
    } catch (_) {
      if (!mounted) return;
      showNdToast(context, 'Export failed', glyph: Nd.x);
    }
  }

  Future<void> _toggleDeviceAdmin() async {
    final active = _adminOn;
    await showNdDialog<void>(
      context: context,
      title: active ? 'Remove device admin?' : 'Grant device admin?',
      builder: (context) => Text(
        active
            ? 'Strict blocking becomes escapable — anyone could uninstall '
                  'NAVI to get around it.'
            : 'This stops NAVI from being uninstalled to bypass strict '
                  'blocking. You can revoke it here at any time.',
        style: context.palette.bodyDim,
      ),
      actions: (context) => [
        DialogAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
        if (active)
          DialogAction(
            label: 'Remove',
            danger: true,
            onTap: () async {
              Navigator.pop(context);
              await DeviceAdminService.removeAdmin();
              _refreshServiceStatus();
            },
          )
        else
          DialogAction(
            label: 'Grant',
            emphasized: true,
            onTap: () async {
              Navigator.pop(context);
              await DeviceAdminService.requestAdmin();
              _refreshServiceStatus();
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = SettingsScope.of(context);
    final habits = HabitScope.of(context);

    final avatarGlyphs = Nd.habitIcons.values.toList();
    final avatarGlyph =
        avatarGlyphs[settings.avatarIndex.clamp(0, avatarGlyphs.length - 1)];
    final reminder = settings.defaultReminderMinutes;
    final reminderLabel =
        '${(reminder ~/ 60).toString().padLeft(2, '0')}:'
        '${(reminder % 60).toString().padLeft(2, '0')}';

    final sections = <Widget>[
      _ProfileCard(
        glyph: avatarGlyph,
        name: settings.displayName,
        onAvatarTap: _pickAvatar,
        onNameTap: _editDisplayName,
      ),
      _Section(
        title: 'HABITS',
        children: [
          _SettingsRow(
            glyph: Nd.grid,
            label: 'Manage habits',
            chevron: true,
            onTap: () {
              Navigator.pop(context);
              widget.onManageHabits?.call();
            },
          ),
          _SettingsRow(
            glyph: Nd.bell,
            label: 'Default reminder',
            subtitle: 'Prefilled when you create a habit',
            value: reminderLabel,
            onTap: _editDefaultReminder,
          ),
          _ChipRow(
            glyph: Nd.camera,
            label: 'Photo quality',
            options: [
              (
                'Low',
                settings.photoQuality == 0,
                () {
                  settings.setPhotoQuality(0);
                },
              ),
              (
                'Med',
                settings.photoQuality == 1,
                () {
                  settings.setPhotoQuality(1);
                },
              ),
              (
                'High',
                settings.photoQuality == 2,
                () {
                  settings.setPhotoQuality(2);
                },
              ),
            ],
          ),
        ],
      ),
      _Section(
        title: 'JOURNAL',
        children: [
          _ChipRow(
            glyph: Nd.pen,
            label: 'Auto-save',
            options: [
              for (final s in const [3, 5, 10])
                (
                  '${s}s',
                  settings.autoSaveSeconds == s,
                  () {
                    settings.setAutoSaveSeconds(s);
                  },
                ),
            ],
          ),
          _SettingsRow(
            glyph: Nd.export,
            label: 'Export data',
            subtitle: 'Writes a JSON file to app storage',
            chevron: true,
            onTap: _exportData,
          ),
        ],
      ),
      _Section(
        title: 'NOTIFICATIONS & SOUND',
        children: [
          _SettingsRow(
            glyph: Nd.bell,
            label: 'Habit reminders',
            trailing: NdSwitch(
              value: habits.remindersEnabled,
              onChanged: habits.setRemindersEnabled,
            ),
            onTap: () => habits.setRemindersEnabled(!habits.remindersEnabled),
          ),
          _ChipRow(
            glyph: Nd.hourglass,
            label: 'Snooze length',
            options: [
              for (final m in const [5, 10, 15])
                (
                  '${m}m',
                  settings.defaultSnoozeMinutes == m,
                  () {
                    settings.setDefaultSnoozeMinutes(m);
                  },
                ),
            ],
          ),
          _SettingsRow(
            glyph: Nd.note,
            label: 'Interface sounds',
            trailing: NdSwitch(
              value: settings.sfxEnabled,
              onChanged: settings.setSfxEnabled,
            ),
            onTap: () => settings.setSfxEnabled(!settings.sfxEnabled),
          ),
        ],
      ),
      _Section(
        title: 'APP BLOCKING',
        children: [
          _SettingsRow(
            glyph: Nd.eye,
            label: 'Accessibility service',
            subtitle: 'Required to detect and block apps',
            value: _accessibilityOn ? 'On' : 'Off',
            valueColor: _accessibilityOn ? p.accent : p.danger,
            onTap: AppBlocker.openAccessibilitySettings,
          ),
          _SettingsRow(
            glyph: Nd.lock,
            label: 'Device admin',
            subtitle: 'Stops NAVI being uninstalled mid-block',
            value: _adminOn ? 'Active' : 'Inactive',
            valueColor: _adminOn ? p.accent : p.textDim,
            onTap: _toggleDeviceAdmin,
          ),
          _SettingsRow(
            glyph: Nd.block,
            label: 'Block rules',
            chevron: true,
            onTap: () => Navigator.of(
              context,
            ).push(slideUpRoute(const AppBlockScreen())),
          ),
        ],
      ),
      _Section(
        title: 'APPEARANCE',
        children: [
          _AccentRow(
            selected: settings.accentIndex,
            onSelect: settings.setAccentIndex,
          ),
          _SettingsRow(
            glyph: Nd.moon,
            label: 'Pure black',
            subtitle: 'Flattens every surface for OLED screens',
            trailing: NdSwitch(
              value: settings.amoled,
              onChanged: settings.setAmoled,
            ),
            onTap: () => settings.setAmoled(!settings.amoled),
          ),
          _ChipRow(
            glyph: Nd.textLines,
            label: 'Text size',
            options: [
              for (final (label, scale) in const [
                ('Small', 0.9),
                ('Default', 1.0),
                ('Large', 1.15),
              ])
                (
                  label,
                  (settings.fontScale - scale).abs() < 0.01,
                  () {
                    settings.setFontScale(scale);
                  },
                ),
            ],
          ),
        ],
      ),
      _Section(
        title: 'ABOUT',
        children: [
          _SettingsRow(
            glyph: Nd.dot,
            label: 'NAVI',
            subtitle: 'Everything stays on this device',
            value: 'v1.0',
          ),
        ],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NdHeader(
              title: 'Settings',
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
                  NdSpace.xxl,
                ),
                children: [
                  for (final (i, section) in sections.indexed)
                    _Reveal(index: i, child: section),
                ],
              ),
            ),
          ],
        ),
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
    final delayMs = 70 * index;
    final totalMs = 300 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.glyph,
    required this.name,
    required this.onAvatarTap,
    required this.onNameTap,
  });

  final NdGlyph glyph;
  final String name;
  final VoidCallback onAvatarTap;
  final VoidCallback onNameTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: NdSpace.xl),
      child: NdCard(
        onTap: onNameTap,
        padding: const EdgeInsets.all(NdSpace.lg),
        child: Row(
          children: [
            Tactile(
              pressedScale: 0.9,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Sfx.tick();
                  onAvatarTap();
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.panelHi,
                    border: Border.all(color: p.borderHi),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: NdIcon(
                        glyph,
                        key: ValueKey(glyph),
                        color: p.accent,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: NdSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: p.title.copyWith(fontSize: 19)),
                  const SizedBox(height: 2),
                  Text('Tap to change name or avatar', style: p.label),
                ],
              ),
            ),
            NdIcon(Nd.right, color: p.textGhost, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: NdSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: NdSpace.xs),
            child: Text(title, style: p.h2),
          ),
          const SizedBox(height: NdSpace.md),
          NdCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in children.indexed) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 58),
                      child: Container(height: 1, color: p.border),
                    ),
                  row,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.glyph,
    required this.label,
    this.subtitle,
    this.value,
    this.valueColor,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });

  final NdGlyph glyph;
  final String label;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NdSpace.lg,
        vertical: NdSpace.md,
      ),
      child: Row(
        children: [
          SizedBox(width: 26, child: NdIcon(glyph, color: p.textDim, size: 20)),
          const SizedBox(width: NdSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: p.row, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: p.label.copyWith(fontSize: 11)),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: NdSpace.md),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: p.label.copyWith(
                color: valueColor ?? p.textDim,
                fontSize: 14,
              ),
              child: Text(value!),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: NdSpace.md),
            trailing!,
          ],
          if (chevron) ...[
            const SizedBox(width: NdSpace.sm),
            NdIcon(Nd.right, color: p.textGhost, size: 20),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Tactile(
      pressedScale: 0.99,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          Sfx.tick();
          onTap!();
        },
        child: row,
      ),
    );
  }
}

/// Label with its options underneath, so long chip sets never crowd the label.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.glyph,
    required this.label,
    required this.options,
  });

  final NdGlyph glyph;
  final String label;
  final List<(String, bool, VoidCallback)> options;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NdSpace.lg,
        vertical: NdSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                child: NdIcon(glyph, color: p.textDim, size: 20),
              ),
              const SizedBox(width: NdSpace.lg),
              Expanded(
                child: Text(
                  label,
                  style: p.row,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: NdSpace.md),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Row(
              children: [
                for (final (i, (chipLabel, selected, onTap))
                    in options.indexed) ...[
                  if (i > 0) const SizedBox(width: NdSpace.sm),
                  NdChip(
                    label: chipLabel,
                    compact: true,
                    selected: selected,
                    onTap: onTap,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NdSpace.lg,
        vertical: NdSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                child: NdIcon(Nd.star, color: p.textDim, size: 20),
              ),
              const SizedBox(width: NdSpace.lg),
              Expanded(child: Text('Accent', style: p.row)),
              const SizedBox(width: NdSpace.sm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  accents[selected.clamp(0, accents.length - 1)].name,
                  key: ValueKey(selected),
                  style: p.micro.copyWith(color: p.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: NdSpace.lg),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Row(
              children: [
                for (final (i, accent) in accents.indexed) ...[
                  if (i > 0) const SizedBox(width: NdSpace.md),
                  Tactile(
                    pressedScale: 0.86,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Sfx.tick();
                        onSelect(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 32,
                        height: 32,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == selected ? p.text : p.border,
                            width: i == selected ? 2 : 1,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent.l4,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
