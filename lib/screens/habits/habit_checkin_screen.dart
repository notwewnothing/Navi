import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/media_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';

class HabitCheckinScreen extends StatefulWidget {
  const HabitCheckinScreen({super.key, required this.habit});

  final Habit habit;

  @override
  State<HabitCheckinScreen> createState() => _HabitCheckinScreenState();
}

class _HabitCheckinScreenState extends State<HabitCheckinScreen> {
  final _noteController = TextEditingController();

  String? _photoRel;
  File? _photoFile;
  bool _committed = false;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final store = HabitScope.of(context);
    final log = store.logFor(widget.habit, DateTime.now());
    if (log != null) {
      _noteController.text = log.note ?? '';
      if (log.photoPath != null) {
        MediaStore.fileFor(log.photoPath).then((file) {
          // don't let the async photo restore clobber one the user picked since
          if (mounted && file != null && _photoRel == null) {
            setState(() => _photoFile = file);
          }
        });
      }
    } else if (widget.habit.requirePhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pick(ImageSource.camera);
      });
    }
  }

  @override
  void dispose() {
    // abandoned check-ins delete the copied photo with the sheet
    if (!_committed && _photoRel != null) {
      MediaStore.delete(_photoRel);
    }
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final quality = SettingsScope.of(context).imageQualityValue;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: quality,
        maxWidth: 2400,
      );
      if (picked == null) return;
      final previousUncommitted = _photoRel;
      final rel = await MediaStore.importFile(picked.path);
      final file = await MediaStore.fileFor(rel);
      await MediaStore.delete(previousUncommitted);
      if (!mounted) {
        await MediaStore.delete(rel);
        return;
      }
      setState(() {
        _photoRel = rel;
        _photoFile = file;
      });
      HapticFeedback.selectionClick();
      Sfx.tick();
    } catch (_) {}
  }

  Future<void> _confirm() async {
    final store = HabitScope.of(context);
    final note = _noteController.text.trim();
    HapticFeedback.mediumImpact();
    _committed = true;
    final allDone = await store.checkIn(
      widget.habit,
      photoPath: _photoRel,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    Sfx.complete();
    if (allDone) {
      showNdToast(context, 'Every habit done today', glyph: Nd.check);
    }
    Navigator.pop(context);
  }

  Future<void> _undo() async {
    final store = HabitScope.of(context);
    await store.uncheck(widget.habit);
    if (!mounted) return;
    Sfx.tick();
    Navigator.pop(context);
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = HabitScope.of(context);
    final habit = widget.habit;
    final log = store.logFor(habit, DateTime.now());
    final streak = store.streak(habit);
    final dotColor = habitDotColors[habit.colorIndex % habitDotColors.length];
    final canConfirm =
        !habit.requirePhoto || _photoRel != null || log?.photoPath != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NdHeader(
              title: habit.name,
              leading: NdIconButton(
                glyph: Nd.left,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  NdSpace.page,
                  NdSpace.sm,
                  NdSpace.page,
                  NdSpace.md,
                ),
                children: [
                  _Reveal(
                    index: 0,
                    child: Column(
                      children: [
                        const SizedBox(height: NdSpace.sm),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) =>
                              Transform.scale(scale: t, child: child),
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.panel,
                              border: Border.all(color: p.border),
                            ),
                            child: Center(
                              child: NdIcon(
                                Nd.habitIcon(habit.icon),
                                color: dotColor,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: NdSpace.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            NdIcon(
                              Nd.flame,
                              color: streak > 0 ? p.accent : p.textGhost,
                              size: 16,
                            ),
                            const SizedBox(width: NdSpace.sm),
                            Text(
                              streak == 1
                                  ? '1 day streak'
                                  : '$streak day streak',
                              style: p.label.copyWith(
                                color: streak > 0 ? p.accent : p.textDim,
                              ),
                            ),
                          ],
                        ),
                        if (log != null) ...[
                          const SizedBox(height: NdSpace.sm),
                          Text(
                            'Checked in at ${_hhmm(log.at)}',
                            textAlign: TextAlign.center,
                            style: p.label,
                          ),
                        ],
                        const SizedBox(height: NdSpace.xl),
                      ],
                    ),
                  ),

                  _Reveal(
                    index: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          habit.requirePhoto ? 'PHOTO PROOF' : 'PHOTO',
                          style: p.h2,
                        ),
                        const SizedBox(height: NdSpace.md),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          child: _photoFile != null
                              ? ClipRRect(
                                  key: ValueKey(_photoFile!.path),
                                  borderRadius: BorderRadius.circular(
                                    NdRadius.card,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: Image.file(
                                      _photoFile!,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                )
                              : habit.requirePhoto
                              ? Container(
                                  key: const ValueKey('placeholder'),
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: p.panel,
                                    border: Border.all(color: p.border),
                                    borderRadius: BorderRadius.circular(
                                      NdRadius.card,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      NdIcon(
                                        Nd.camera,
                                        color: p.textGhost,
                                        size: 26,
                                      ),
                                      const SizedBox(height: NdSpace.sm),
                                      Text(
                                        'A photo is required for this habit',
                                        style: p.label,
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('none')),
                        ),
                        if (_photoFile != null || habit.requirePhoto)
                          const SizedBox(height: NdSpace.md),
                        Row(
                          children: [
                            Expanded(
                              child: NdButton(
                                label: 'Camera',
                                glyph: Nd.camera,
                                expand: true,
                                height: 48,
                                onTap: () => _pick(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: NdSpace.md),
                            Expanded(
                              child: NdButton(
                                label: 'Gallery',
                                glyph: Nd.photo,
                                expand: true,
                                height: 48,
                                onTap: () => _pick(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: NdSpace.xl),
                      ],
                    ),
                  ),

                  _Reveal(
                    index: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('NOTE', style: p.h2),
                        const SizedBox(height: NdSpace.md),
                        NdTextField(
                          controller: _noteController,
                          hint: 'How did it go? (optional)',
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                NdSpace.page,
                NdSpace.sm,
                NdSpace.page,
                NdSpace.lg,
              ),
              child: _Reveal(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NdButton(
                      label: log == null ? 'Check in' : 'Update check-in',
                      glyph: Nd.check,
                      filled: true,
                      expand: true,
                      height: 56,
                      onTap: canConfirm ? _confirm : null,
                    ),
                    if (!canConfirm)
                      Padding(
                        padding: const EdgeInsets.only(top: NdSpace.sm),
                        child: Text(
                          'Add a photo to check in',
                          textAlign: TextAlign.center,
                          style: p.label,
                        ),
                      ),
                    if (log != null)
                      Padding(
                        padding: const EdgeInsets.only(top: NdSpace.xs),
                        child: Center(
                          child: DialogAction(
                            label: 'Undo check-in',
                            danger: true,
                            onTap: _undo,
                          ),
                        ),
                      ),
                  ],
                ),
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
    final totalMs = 320 + delayMs;
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
