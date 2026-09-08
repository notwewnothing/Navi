import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../models/journal_entry.dart';
import '../../services/journal_store.dart';
import '../../services/media_store.dart';
import '../../services/settings_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_video_player.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/routes.dart';
import 'journal_entry_view.dart' show MediaImage, journalDuration, journalStamp;

/// Capture types the journal sheet can be opened straight into, so callers
/// like the home screen can skip the type picker.
enum JournalCapture { text, photo, video, voice }

Future<void> showJournalEntrySheet(
  BuildContext context, {
  JournalCapture? start,
}) async {
  final navigator = Navigator.of(context);
  // text needs no sheet at all, go straight to the writing screen
  if (start == JournalCapture.text) {
    navigator.push(slideUpRoute(const _TextEntryScreen()));
    return;
  }
  final settings = SettingsScope.of(context);
  final result = await showNdSheet<(JournalType, ImageSource?)>(
    context: context,
    builder: (_) => _EntrySheet(start: start),
  );
  if (result == null || !context.mounted) return;
  switch (result) {
    case (JournalType.text, _):
      navigator.push(slideUpRoute(const _TextEntryScreen()));
    case (JournalType.photo, final ImageSource source):
      await _pickAndCaption(
        context,
        navigator,
        settings,
        JournalType.photo,
        source,
      );
    case (JournalType.video, final ImageSource source):
      await _pickAndCaption(
        context,
        navigator,
        settings,
        JournalType.video,
        source,
      );
    case _:
      break;
  }
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

Future<void> _pickAndCaption(
  BuildContext context,
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
  final String relativePath;
  String? thumbPath;
  // videos are big enough that the copy is worth showing
  if (type == JournalType.video && context.mounted) {
    final handle = showNdProgress(
      context,
      title: 'IMPORTING',
      detail: 'Copying video',
    );
    try {
      relativePath = await MediaStore.importFile(
        picked.path,
        onProgress: (done, total) => handle.update(
          total == 0 ? 1 : done / total,
          detailText: '${_mb(done)} / ${_mb(total)} MB',
        ),
      );
      handle.update(1, detailText: 'Making poster frame');
      thumbPath = await MediaStore.makeVideoThumbnail(relativePath);
    } finally {
      handle.close();
    }
  } else {
    relativePath = await MediaStore.importFile(picked.path);
  }
  navigator.push(
    slideUpRoute(
      _MediaCaptionScreen(
        type: type,
        mediaPath: relativePath,
        thumbPath: thumbPath,
      ),
    ),
  );
}

enum _SheetPane { pick, photoSource, videoSource, record, recordSave }

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({this.start});

  final JournalCapture? start;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late _SheetPane _pane = switch (widget.start) {
    null || JournalCapture.text => _SheetPane.pick,
    JournalCapture.photo => _SheetPane.photoSource,
    JournalCapture.video => _SheetPane.videoSource,
    JournalCapture.voice => _SheetPane.record,
  };

  /// Opened straight into one capture type, so there is no picker to go back to.
  bool get _direct => widget.start != null;

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
  void initState() {
    super.initState();
    if (widget.start == JournalCapture.voice) {
      // _startRecording can toast on permission denial, which needs a live
      // overlay, so wait until the sheet has actually been painted
      WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _clockTimer?.cancel();
    _captionController.dispose();
    _rec.dispose();
    final path = _recPath;
    // the recorder may still be flushing the file after dispose, wait before deleting
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
        showNdToast(context, 'Microphone access denied', glyph: Nd.x);
        setState(() => _pane = _SheetPane.pick);
        return;
      }
      final path = await MediaStore.newRecordingPath('m4a');
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recPath = path;
      _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((
        amp,
      ) {
        if (!mounted) return;
        setState(() {
          // amplitudes come in as dB, +45 shifts silence to 0 before the 0-1 clamp
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
      showNdToast(context, "Recorder isn't available", glyph: Nd.x);
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
    showNdToast(context, 'Entry saved', glyph: Nd.check);
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
        padding: const EdgeInsets.fromLTRB(
          NdSpace.page,
          NdSpace.md,
          NdSpace.page,
          NdSpace.xl,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
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
        const SizedBox(height: NdSpace.lg),
        Row(
          children: [
            for (final (i, (glyph, label, onTap))
                in <(NdGlyph, String, VoidCallback)>[
                  (
                    Nd.textLines,
                    'Text',
                    () => Navigator.pop(context, (JournalType.text, null)),
                  ),
                  (
                    Nd.camera,
                    'Photo',
                    () => setState(() => _pane = _SheetPane.photoSource),
                  ),
                  (
                    Nd.video,
                    'Video',
                    () => setState(() => _pane = _SheetPane.videoSource),
                  ),
                  (Nd.mic, 'Voice', _startRecording),
                ].indexed) ...[
              if (i > 0) const SizedBox(width: NdSpace.md),
              Expanded(
                child: _TypeTile(glyph: glyph, label: label, onTap: onTap),
              ),
            ],
          ],
        ),
        const SizedBox(height: NdSpace.xs),
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
            NdIconButton(
              glyph: Nd.left,
              size: 20,
              onTap: () => _direct
                  ? Navigator.pop(context)
                  : setState(() => _pane = _SheetPane.pick),
            ),
            const SizedBox(width: NdSpace.xs),
            Text(
              type == JournalType.photo ? 'PHOTO SOURCE' : 'VIDEO SOURCE',
              style: p.h2,
            ),
          ],
        ),
        const SizedBox(height: NdSpace.lg),
        Row(
          children: [
            Expanded(
              child: NdButton(
                label: 'Camera',
                glyph: Nd.camera,
                expand: true,
                onTap: () => Navigator.pop(context, (type, ImageSource.camera)),
              ),
            ),
            const SizedBox(width: NdSpace.md),
            Expanded(
              child: NdButton(
                label: 'Gallery',
                glyph: Nd.photo,
                expand: true,
                onTap: () =>
                    Navigator.pop(context, (type, ImageSource.gallery)),
              ),
            ),
          ],
        ),
        const SizedBox(height: NdSpace.xs),
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
            NdPulseDot(size: 10, color: p.danger),
            const SizedBox(width: NdSpace.md),
            Text('RECORDING', style: p.h2.copyWith(color: p.danger)),
          ],
        ),
        const SizedBox(height: NdSpace.lg),
        Center(
          child: Text(
            journalDuration(elapsed),
            style: p.dot(64, color: p.text, letterSpacing: 3),
          ),
        ),
        const SizedBox(height: NdSpace.lg),
        _Waveform(amps: _amps),
        const SizedBox(height: NdSpace.xl),
        NdButton(
          label: 'Stop recording',
          glyph: Nd.stop,
          danger: true,
          filled: true,
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
            NdIcon(Nd.mic, color: p.accent, size: 20),
            const SizedBox(width: NdSpace.md),
            Text(journalDuration(_durationMs), style: p.dot(28, color: p.text)),
            const SizedBox(width: NdSpace.md),
            Text('recorded', style: p.label),
          ],
        ),
        const SizedBox(height: NdSpace.lg),
        NdTextField(
          controller: _captionController,
          hint: 'Add a caption (optional)',
        ),
        const SizedBox(height: NdSpace.lg),
        Row(
          children: [
            DialogAction(label: 'Discard', danger: true, onTap: _discardAudio),
            const Spacer(),
            NdButton(
              label: 'Save',
              height: 46,
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
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.35 + 0.65 * a),
                  borderRadius: BorderRadius.circular(2),
                ),
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
      // degenerate setting guard, never autosave faster than 5 seconds
      final seconds = SettingsScope.of(context).autoSaveSeconds;
      _autoSave = Timer.periodic(Duration(seconds: seconds < 1 ? 5 : seconds), (
        _,
      ) {
        if (!mounted || _controller.text == _draft) return;
        setState(() {
          _draft = _controller.text;
          _draftAt = DateTime.now();
        });
      });
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
    showNdToast(context, 'Entry saved', glyph: Nd.check);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NdHeader(
              title: 'New entry',
              leading: NdIconButton(
                glyph: Nd.left,
                onTap: () => Navigator.pop(context),
              ),
              actions: [
                NdButton(label: 'Save', height: 42, filled: true, onTap: _save),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NdSpace.page),
              child: Row(
                children: [
                  Text(journalStamp(_stamp), style: p.label),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _draftAt == null ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      'Draft kept',
                      style: p.label.copyWith(color: p.textGhost),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NdSpace.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: NdSpace.page),
                child: NdTextField(
                  controller: _controller,
                  hint: 'Start writing...',
                  autofocus: true,
                  maxLines: null,
                  filled: false,
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
  const _MediaCaptionScreen({
    required this.type,
    required this.mediaPath,
    this.thumbPath,
  });

  final JournalType type;
  final String mediaPath;
  final String? thumbPath;

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
      thumbPath: widget.thumbPath,
      durationMs: _videoDurationMs,
    );
    _saved = true;
    if (!mounted) return;
    Sfx.complete();
    showNdToast(context, 'Entry saved', glyph: Nd.check);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_saved) {
          MediaStore.delete(widget.mediaPath);
          MediaStore.delete(widget.thumbPath);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              NdHeader(
                title: widget.type == JournalType.photo
                    ? 'New photo'
                    : 'New video',
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
                    NdSpace.xl,
                  ),
                  children: [
                    _preview(p),
                    const SizedBox(height: NdSpace.lg),
                    NdTextField(
                      controller: _captionController,
                      hint: 'Add a caption (optional)',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NdSpace.page,
                  NdSpace.xs,
                  NdSpace.page,
                  NdSpace.lg,
                ),
                child: Row(
                  children: [
                    DialogAction(
                      label: 'Discard',
                      danger: true,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    NdButton(
                      label: 'Save',
                      height: 46,
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(NdRadius.card),
        child: Container(
          height: 380,
          color: p.panel,
          child: MediaImage(widget.mediaPath, fit: BoxFit.contain),
        ),
      );
    }
    final video = _video;
    if (!_videoReady || video == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(NdRadius.card),
        child: Container(
          height: 260,
          color: p.panel,
          child: Center(child: Text('Loading preview...', style: p.label)),
        ),
      );
    }
    return NdVideoPlayer(
      controller: video,
      borderRadius: BorderRadius.circular(NdRadius.card),
    );
  }
}

/// Entry-type picker tile used by the new-entry sheet.
class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final NdGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NdCard(
      onTap: onTap,
      radius: NdRadius.inner,
      padding: const EdgeInsets.symmetric(vertical: NdSpace.lg),
      child: Column(
        children: [
          NdIcon(glyph, color: p.text, size: 24),
          const SizedBox(height: NdSpace.sm),
          Text(label, style: p.label.copyWith(color: p.text)),
        ],
      ),
    );
  }
}
