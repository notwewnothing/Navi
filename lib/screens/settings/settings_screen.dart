import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_blocker.dart';
import '../../services/block_store.dart';
import '../../services/device_admin_service.dart';
import '../../services/easter_eggs.dart';
import '../../services/habit_store.dart';
import '../../services/journal_store.dart';
import '../../services/schedule_store.dart';
import '../../services/session_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
import '../../widgets/tactile.dart';
import '../blocker/app_block_screen.dart';
import '../shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _accessibilityOn = false;
  bool _adminOn = false;

  int _versionTaps = 0;
  DateTime _versionFirstTap = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _versionLastTap = DateTime.fromMillisecondsSinceEpoch(0);

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
    final glyphs = Px.habitIcons.values.toList();
    await showPixelDialog<void>(
      context: context,
      title: 'SELECT AVATAR',
      builder: (context) {
        final p = context.palette;
        final selected = settings.avatarIndex;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: i == selected ? p.accentGhost : p.panelHi,
                      border: Border.all(
                        color: i == selected ? p.accent : p.border,
                        width: i == selected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: PixelIcon(
                        glyph,
                        color: i == selected ? p.accent : p.textDim,
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
    await showPixelDialog<void>(
      context: context,
      title: 'IDENTITY',
      builder: (context) => PixelTextField(
        controller: controller,
        hint: 'LAIN',
        autofocus: true,
        fontSize: 24,
        capitalization: TextCapitalization.characters,
      ),
      actions: (context) => [
        DialogAction(label: 'CANCEL', onTap: () => Navigator.pop(context)),
        DialogAction(
          label: 'SAVE',
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
    await showPixelDialog<void>(
      context: context,
      title: 'DEFAULT REMINDER',
      builder: (context) {
        final p = context.palette;
        return SizedBox(
          height: 170,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PixelWheel(
                itemCount: 24,
                controller: hourCtrl,
                labelFor: (i) => i.toString().padLeft(2, '0'),
                onChanged: (i) => hour = ((i % 24) + 24) % 24,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 44,
                    color: p.textDim,
                    height: 1,
                  ),
                ),
              ),
              PixelWheel(
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
        DialogAction(label: 'CANCEL', onTap: () => Navigator.pop(context)),
        DialogAction(
          label: 'SET',
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
      showPixelToast(context, 'EXPORTED TO $short', glyph: Px.export);
    } catch (_) {
      if (!mounted) return;
      showPixelToast(context, 'EXPORT FAILED', glyph: Px.x);
    }
  }


  Future<void> _toggleDeviceAdmin() async {
    final active = _adminOn;
    await showPixelDialog<void>(
      context: context,
      title: 'DEVICE ADMIN',
      builder: (context) => Text(
        active
            ? 'Remove uninstall protection? Strict blocking becomes '
                  'escapable by deleting NAVI.'
            : 'Grant device admin so NAVI cannot be uninstalled to bypass '
                  'strict blocking.',
        style: context.palette.bodyDim,
      ),
      actions: (context) => [
        DialogAction(label: 'CANCEL', onTap: () => Navigator.pop(context)),
        if (active)
          DialogAction(
            label: 'REMOVE',
            danger: true,
            onTap: () async {
              Navigator.pop(context);
              await DeviceAdminService.removeAdmin();
              _refreshServiceStatus();
            },
          )
        else
          DialogAction(
            label: 'GRANT',
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


  void _onVersionTap() {
    final now = DateTime.now();
    if (now.difference(_versionLastTap) > const Duration(milliseconds: 1200)) {
      _versionTaps = 0;
    }
    if (_versionTaps == 0) _versionFirstTap = now;
    _versionLastTap = now;
    _versionTaps++;
    if (_versionTaps < 7) return;
    _versionTaps = 0;
    if (now.difference(_versionFirstTap) > const Duration(seconds: 4)) return;
    HapticFeedback.heavyImpact();
    SettingsScope.of(context).unlockScanlines();
    EasterEggs.wiredBoot(context);
    showPixelToast(context, 'CRT MODE UNLOCKED', glyph: Px.star);
  }


  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = SettingsScope.of(context);
    final habits = HabitScope.of(context);
    final shell = context.findAncestorStateOfType<NaviShellState>();

    final avatarGlyphs = Px.habitIcons.values.toList();
    final avatarGlyph =
        avatarGlyphs[settings.avatarIndex.clamp(0, avatarGlyphs.length - 1)];
    final reminder = settings.defaultReminderMinutes;
    final reminderLabel =
        '${(reminder ~/ 60).toString().padLeft(2, '0')}:'
        '${(reminder % 60).toString().padLeft(2, '0')}';

    final sections = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(
          'Logged into the Wired as ${settings.displayName}',
          style: p.quote,
        ),
      ),
      _Section(
        title: 'PROFILE',
        children: [
          _AvatarRow(glyph: avatarGlyph, onTap: _pickAvatar),
          _SettingsRow(
            glyph: Px.user,
            label: 'DISPLAY NAME',
            value: settings.displayName,
            onTap: _editDisplayName,
          ),
        ],
      ),
      _Section(
        title: 'HABITS',
        children: [
          _SettingsRow(
            glyph: Px.grid,
            label: 'MANAGE HABITS',
            chevron: true,
            onTap: () => shell?.goTo(1),
          ),
          _SettingsRow(
            glyph: Px.bell,
            label: 'DEFAULT REMINDER',
            value: reminderLabel,
            onTap: _editDefaultReminder,
          ),
          _ChipRow(
            glyph: Px.camera,
            label: 'PHOTO QUALITY',
            options: [
              ('LOW', settings.photoQuality == 0, () {
                settings.setPhotoQuality(0);
              }),
              ('MED', settings.photoQuality == 1, () {
                settings.setPhotoQuality(1);
              }),
              ('HIGH', settings.photoQuality == 2, () {
                settings.setPhotoQuality(2);
              }),
            ],
          ),
        ],
      ),
      _Section(
        title: 'JOURNAL',
        children: [
          _ChipRow(
            glyph: Px.pen,
            label: 'AUTO-SAVE',
            options: [
              for (final s in const [3, 5, 10])
                ('${s}S', settings.autoSaveSeconds == s, () {
                  settings.setAutoSaveSeconds(s);
                }),
            ],
          ),
          _SettingsRow(
            glyph: Px.export,
            label: 'EXPORT DATA (JSON)',
            chevron: true,
            onTap: _exportData,
          ),
        ],
      ),
      _Section(
        title: 'NOTIFICATIONS',
        children: [
          _SettingsRow(
            glyph: Px.bell,
            label: 'HABIT REMINDERS',
            trailing: PixelSwitch(
              value: habits.remindersEnabled,
              onChanged: habits.setRemindersEnabled,
            ),
            onTap: () =>
                habits.setRemindersEnabled(!habits.remindersEnabled),
          ),
          _SettingsRow(
            glyph: Px.alarm,
            label: 'ALARM SOUND',
            value: 'BLAST',
            onTap: () =>
                showPixelToast(context, 'ONLY ONE SOUND IN THE WIRED'),
          ),
          _ChipRow(
            glyph: Px.hourglass,
            label: 'SNOOZE DURATION',
            options: [
              for (final m in const [5, 10, 15])
                ('${m}M', settings.defaultSnoozeMinutes == m, () {
                  settings.setDefaultSnoozeMinutes(m);
                }),
            ],
          ),
          _SettingsRow(
            glyph: Px.note,
            label: 'SOUND FX',
            trailing: PixelSwitch(
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
            glyph: Px.eye,
            label: 'ACCESSIBILITY SERVICE',
            value: _accessibilityOn ? 'ONLINE' : 'OFFLINE',
            valueColor: _accessibilityOn ? p.accent : p.danger,
            onTap: AppBlocker.openAccessibilitySettings,
          ),
          _SettingsRow(
            glyph: Px.lock,
            label: 'DEVICE ADMIN',
            value: _adminOn ? 'ACTIVE' : 'INACTIVE',
            valueColor: _adminOn ? p.accent : p.textDim,
            onTap: _toggleDeviceAdmin,
          ),
          _SettingsRow(
            glyph: Px.block,
            label: 'BLOCK RULES',
            chevron: true,
            onTap: () => Navigator.of(context).push(
              slideUpRoute(const AppBlockScreen()),
            ),
          ),
        ],
      ),
      _Section(
        title: 'THEME',
        children: [
          _AccentRow(
            selected: settings.accentIndex,
            onSelect: settings.setAccentIndex,
          ),
          _SettingsRow(
            glyph: Px.moon,
            label: 'AMOLED BLACK',
            trailing: PixelSwitch(
              value: settings.amoled,
              onChanged: settings.setAmoled,
            ),
            onTap: () => settings.setAmoled(!settings.amoled),
          ),
          _ChipRow(
            glyph: Px.textLines,
            label: 'FONT SIZE',
            options: [
              for (final (label, scale) in const [
                ('SMALL', 0.9),
                ('STD', 1.0),
                ('LARGE', 1.15),
              ])
                (label, (settings.fontScale - scale).abs() < 0.01, () {
                  settings.setFontScale(scale);
                }),
            ],
          ),
          if (settings.scanlinesUnlocked)
            _SettingsRow(
              glyph: Px.video,
              label: 'CRT SCANLINES',
              trailing: PixelSwitch(
                value: settings.scanlinesEnabled,
                onChanged: settings.setScanlinesEnabled,
              ),
              onTap: () =>
                  settings.setScanlinesEnabled(!settings.scanlinesEnabled),
            ),
        ],
      ),
      _Section(
        title: 'ABOUT',
        footer: Padding(
          padding: const EdgeInsets.only(top: 12, left: 2),
          child: Text(
            'Present day. Present time. And you are still here.',
            style: p.quote.copyWith(fontSize: 17),
          ),
        ),
        children: [
          _SettingsRow(
            glyph: Px.dot,
            label: 'NAVI v1.0',
            value: "Let's all love Lain.",
            onTap: _onVersionTap,
          ),
        ],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PixelHeader(title: 'SYSTEM'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
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
    final delayMs = 80 * index;
    final totalMs = 300 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: p.h2),
          const SizedBox(height: 10),
          PixelCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in children.indexed) ...[
                  if (i > 0) Container(height: 1, color: p.border),
                  row,
                ],
              ],
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}

TextStyle _rowLabelStyle(NaviPalette p) => TextStyle(
  fontFamily: kFontPixel,
  fontSize: 8,
  letterSpacing: 1,
  color: p.text,
  height: 1.5,
);

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.glyph,
    required this.label,
    this.value,
    this.valueColor,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });

  final PixelGlyph glyph;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          PixelIcon(glyph, color: p.textDim, size: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: _rowLabelStyle(p),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 18,
                color: valueColor ?? p.textDim,
                height: 1.1,
              ),
              child: Text(value!),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (chevron) ...[
            const SizedBox(width: 10),
            PixelIcon(Px.right, color: p.textGhost, size: 12),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Tactile(
      pressedScale: 0.98,
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.glyph,
    required this.label,
    required this.options,
  });

  final PixelGlyph glyph;
  final String label;
  final List<(String, bool, VoidCallback)> options;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          PixelIcon(glyph, color: p.textDim, size: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: _rowLabelStyle(p),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          for (final (i, (chipLabel, selected, onTap)) in options.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            PixelChip(
              label: chipLabel,
              compact: true,
              selected: selected,
              onTap: onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.glyph, required this.onTap});

  final PixelGlyph glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.98,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          Sfx.tick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: p.panelHi,
                  border: Border.all(color: p.accentDim, width: 1.5),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: PixelIcon(
                      glyph,
                      key: ValueKey(glyph),
                      color: p.accent,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AVATAR', style: _rowLabelStyle(p)),
                    const SizedBox(height: 5),
                    Text(
                      'your face in the Wired',
                      style: p.bodyDim.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
              PixelIcon(Px.right, color: p.textGhost, size: 12),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelIcon(Px.star, color: p.textDim, size: 16),
              const SizedBox(width: 14),
              Expanded(child: Text('ACCENT', style: _rowLabelStyle(p))),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  accents[selected.clamp(0, accents.length - 1)].name,
                  key: ValueKey(selected),
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 17,
                    color: p.accent,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, accent) in accents.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
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
                      width: 26,
                      height: 26,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: i == selected
                              ? Colors.white
                              : p.border,
                          width: i == selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: ColoredBox(color: accent.l4)),
                          Expanded(child: ColoredBox(color: accent.l2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
