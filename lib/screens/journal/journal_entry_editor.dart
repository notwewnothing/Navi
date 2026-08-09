import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../models/journal_entry.dart';
import '../../services/easter_eggs.dart';
import '../../services/journal_store.dart';
import '../../services/media_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/glitch.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
import 'journal_entry_view.dart' show MediaImage, journalDuration, journalStamp;

Future<void> showJournalEntrySheet(BuildContext context) async {
  final navigator = Navigator.of(context);
  final settings = SettingsScope.of(context);
  final result = await showPixelSheet<(JournalType, ImageSource?)>(
    context: context,
    builder: (_) => const _EntrySheet(),
  );
  if (result == null) return;
  switch (result) {
    case (JournalType.text, _):
      navigator.push(slideUpRoute(const _TextEntryScreen()));
    case (JournalType.photo, final ImageSource source):
      await _pickAndCaption(navigator, settings, JournalType.photo, source);
    case (JournalType.video, final ImageSource source):
      await _pickAndCaption(navigator, settings, JournalType.video, source);
    case _:
      break;
  }
}

Future<void> _pickAndCaption(
  NavigatorState navigator,
  SettingsStore settings,
  JournalType type,
  ImageSource source,
) async {
  final picker = ImagePicker();
  XFile? picked;
  try {
    picked = type == JournalType.photo
        ? await picker.pickImage(
            source: source,
            imageQuality: settings.imageQualityValue,
            maxWidth: 2400,
          )
        : await picker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 5),
          );
  } catch (_) {
    picked = null;
  }
  if (picked == null) return;
  final relativePath = await MediaStore.importFile(picked.path);
  navigator.push(
    slideUpRoute(_MediaCaptionScreen(type: type, mediaPath: relativePath)),
  );
}


enum _SheetPane { pick, photoSource, videoSource, record, recordSave }

class _EntrySheet extends StatefulWidget {
  const _EntrySheet();

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  _SheetPane _pane = _SheetPane.pick;

  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _clockTimer;
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _amps = [];
  String? _recPath;
  int _durationMs = 0;
  bool _saving = false;
  bool _saved = false;
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _ampSub?.cancel();
    _clockTimer?.cancel();
    _captionController.dispose();
    _rec.dispose();
    final path = _recPath;
    if (!_saved && path != null) {
      Future<void>.delayed(const Duration(milliseconds: 400), () async {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      });
    }
    super.dispose();
  }


  Future<void> _startRecording() async {
    setState(() {
      _pane = _SheetPane.record;
      _amps.clear();
    });
    try {
      if (!await _rec.hasPermission()) {
        if (!mounted) return;
        showPixelToast(context, 'MICROPHONE ACCESS DENIED', glyph: Px.x);
        setState(() => _pane = _SheetPane.pick);
        return;
      }
      final path = await MediaStore.newRecordingPath('m4a');
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recPath = path;
      _ampSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amp) {
        if (!mounted) return;
        setState(() {
          _amps.add(((amp.current + 45) / 45).clamp(0.0, 1.0));
          if (_amps.length > 40) _amps.removeAt(0);
        });
      });
      _stopwatch
        ..reset()
        ..start();
      _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (!mounted) return;
      showPixelToast(context, 'RECORDER OFFLINE', glyph: Px.x);
      setState(() => _pane = _SheetPane.pick);
    }
  }

  Future<void> _stopRecording() async {
    HapticFeedback.mediumImpact();
    _clockTimer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    _stopwatch.stop();
    _durationMs = _stopwatch.elapsedMilliseconds;
    try {
      await _rec.stop();
    } catch (_) {}
    if (mounted) setState(() => _pane = _SheetPane.recordSave);
  }

  Future<void> _saveAudio() async {
    final path = _recPath;
    if (path == null || _saving) return;
    _saving = true;
    final journal = JournalScope.of(context);
    final relativePath = await MediaStore.toRelative(path);
    await journal.add(
      type: JournalType.audio,
      body: _captionController.text.trim(),
      mediaPath: relativePath,
      durationMs: _durationMs,
    );
    _saved = true;
    if (!mounted) return;
    Sfx.complete();
    showPixelToast(context, 'COMMITTED TO THE WIRED', glyph: Px.check);
    Navigator.pop(context);
  }

  void _discardAudio() {
    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(_pane),
              child: switch (_pane) {
                _SheetPane.pick => _pickPane(),
                _SheetPane.photoSource => _sourcePane(JournalType.photo),
                _SheetPane.videoSource => _sourcePane(JournalType.video),
                _SheetPane.record => _recordPane(),
                _SheetPane.recordSave => _recordSavePane(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickPane() {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEW ENTRY', style: p.h2),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PixelChip(
              label: 'TEXT',
              selected: false,
              onTap: () => Navigator.pop(context, (JournalType.text, null)),
            ),
            PixelChip(
              label: 'PHOTO',
              selected: false,
              onTap: () => setState(() => _pane = _SheetPane.photoSource),
            ),
            PixelChip(
              label: 'VIDEO',
              selected: false,
              onTap: () => setState(() => _pane = _SheetPane.videoSource),
            ),
            PixelChip(
              label: 'AUDIO',
              selected: false,
              onTap: _startRecording,
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _sourcePane(JournalType type) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PixelIconButton(
              glyph: Px.left,
              size: 14,
              onTap: () => setState(() => _pane = _SheetPane.pick),
            ),
            const SizedBox(width: 4),
            Text(
              type == JournalType.photo ? 'PHOTO SOURCE' : 'VIDEO SOURCE',
              style: p.h2,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: PixelButton(
                label: 'CAMERA',
                glyph: Px.camera,
                expand: true,
                onTap: () =>
                    Navigator.pop(context, (type, ImageSource.camera)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PixelButton(
                label: 'GALLERY',
                glyph: Px.photo,
                expand: true,
                onTap: () =>
                    Navigator.pop(context, (type, ImageSource.gallery)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _recordPane() {
    final p = context.palette;
    final elapsed = _stopwatch.elapsedMilliseconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BlinkingCursor(width: 10, height: 10, color: p.danger),
            const SizedBox(width: 10),
            Text('RECORDING', style: p.label.copyWith(color: p.danger)),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            journalDuration(elapsed),
            style: TextStyle(
              fontFamily: kFontTerminal,
              fontSize: 64,
              color: p.accent,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Waveform(amps: _amps),
        const SizedBox(height: 18),
        PixelButton(
          label: 'STOP',
          glyph: Px.stop,
          danger: true,
          expand: true,
          onTap: _stopRecording,
        ),
      ],
    );
  }

  Widget _recordSavePane() {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PixelIcon(Px.mic, color: p.accent, size: 16),
            const SizedBox(width: 10),
            Text(
              journalDuration(_durationMs),
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 30,
                color: p.text,
                height: 1,
              ),
            ),
            const SizedBox(width: 10),
            Text('CAPTURED', style: p.label),
          ],
        ),
        const SizedBox(height: 14),
        PixelTextField(
          controller: _captionController,
          hint: 'Caption...',
          fontSize: 20,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            DialogAction(
              label: 'DISCARD',
              danger: true,
              onTap: _discardAudio,
            ),
            const Spacer(),
            PixelButton(
              label: 'SAVE',
              height: 42,
              filled: true,
              onTap: _saveAudio,
            ),
          ],
        ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.amps});

  final List<double> amps;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final a in amps)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: 3,
                height: 4 + 48 * a,
                color: p.accent.withValues(alpha: 0.35 + 0.65 * a),
              ),
            ),
        ],
      ),
    );
  }
}


class _TextEntryScreen extends StatefulWidget {
  const _TextEntryScreen();

  @override
  State<_TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends State<_TextEntryScreen> {
  final _controller = TextEditingController();
  final DateTime _stamp = DateTime.now();
  Timer? _autoSave;
  String _draft = '';
  DateTime? _draftAt;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoSave == null) {
      final seconds = SettingsScope.of(context).autoSaveSeconds;
      _autoSave = Timer.periodic(
        Duration(seconds: seconds < 1 ? 5 : seconds),
        (_) {
          if (!mounted || _controller.text == _draft) return;
          setState(() {
            _draft = _controller.text;
            _draftAt = DateTime.now();
          });
        },
      );
    }
  }

  @override
  void dispose() {
    _autoSave?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    _saving = true;
    final journal = JournalScope.of(context);
    final navigator = Navigator.of(context);
    await journal.add(type: JournalType.text, body: text);
    if (!mounted) return;
    Sfx.complete();
    showPixelToast(context, 'COMMITTED TO THE WIRED', glyph: Px.check);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PixelHeader(
              title: 'TEXT ENTRY',
              leading: PixelIconButton(
                glyph: Px.left,
                onTap: () => Navigator.pop(context),
              ),
              actions: [
                PixelButton(
                  label: 'SAVE',
                  height: 38,
                  filled: true,
                  onTap: _save,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    journalStamp(_stamp),
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 18,
                      color: p.textDim,
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _draftAt == null ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      'DRAFT BUFFERED',
                      style: p.label.copyWith(color: p.textGhost),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PixelTextField(
                  controller: _controller,
                  hint: 'Speak to the Wired...',
                  autofocus: true,
                  maxLines: null,
                  fontSize: 22,
                  onChanged: (text) => EasterEggs.watchText(context, text),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}


class _MediaCaptionScreen extends StatefulWidget {
  const _MediaCaptionScreen({required this.type, required this.mediaPath});

  final JournalType type;
  final String mediaPath;

  @override
  State<_MediaCaptionScreen> createState() => _MediaCaptionScreenState();
}

class _MediaCaptionScreenState extends State<_MediaCaptionScreen> {
  final _captionController = TextEditingController();
  VideoPlayerController? _video;
  bool _videoReady = false;
  int? _videoDurationMs;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == JournalType.video) _initVideoPreview();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPreview() async {
    final file = await MediaStore.fileFor(widget.mediaPath);
    if (file == null || !mounted) return;
    final controller = VideoPlayerController.file(file);
    _video = controller;
    try {
      await controller.initialize();
    } catch (_) {
      return;
    }
    _videoDurationMs = controller.value.duration.inMilliseconds;
    if (mounted) setState(() => _videoReady = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    final journal = JournalScope.of(context);
    final navigator = Navigator.of(context);
    await journal.add(
      type: widget.type,
      body: _captionController.text.trim(),
      mediaPath: widget.mediaPath,
      durationMs: _videoDurationMs,
    );
    _saved = true;
    if (!mounted) return;
    Sfx.complete();
    showPixelToast(context, 'COMMITTED TO THE WIRED', glyph: Px.check);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_saved) MediaStore.delete(widget.mediaPath);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              PixelHeader(
                title: widget.type == JournalType.photo
                    ? 'NEW PHOTO'
                    : 'NEW VIDEO',
                leading: PixelIconButton(
                  glyph: Px.left,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _preview(p),
                    const SizedBox(height: 16),
                    PixelTextField(
                      controller: _captionController,
                      hint: 'Caption...',
                      fontSize: 20,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    DialogAction(
                      label: 'DISCARD',
                      danger: true,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    PixelButton(
                      label: 'SAVE',
                      height: 44,
                      filled: true,
                      onTap: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(NaviPalette p) {
    if (widget.type == JournalType.photo) {
      return Container(
        height: 380,
        color: Colors.black,
        child: MediaImage(widget.mediaPath, fit: BoxFit.contain),
      );
    }
    final video = _video;
    if (!_videoReady || video == null) {
      return Container(
        height: 260,
        color: Colors.black,
        child: Center(child: Text('DECODING...', style: p.label)),
      );
    }
    final ratio =
        video.value.aspectRatio <= 0 ? 16 / 9 : video.value.aspectRatio;
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(video),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black.withValues(alpha: 0.45),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelIcon(Px.video, color: p.accent, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      journalDuration(_videoDurationMs),
                      style: TextStyle(
                        fontFamily: kFontTerminal,
                        fontSize: 20,
                        color: p.text,
                        height: 1,
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
