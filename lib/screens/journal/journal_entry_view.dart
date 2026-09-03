import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../models/journal_entry.dart';
import '../../services/journal_store.dart';
import '../../services/media_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_video_player.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/tactile.dart';

const _monthsAbbr = [
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

String _two(int v) => v.toString().padLeft(2, '0');

String journalStamp(DateTime at) =>
    '${at.day} ${_monthsAbbr[at.month - 1]} · ${_two(at.hour)}:${_two(at.minute)}';

String journalHm(DateTime at) => '${_two(at.hour)}:${_two(at.minute)}';

String journalDuration(int? ms) {
  final s = ((ms ?? 0) / 1000).round();
  return '${s ~/ 60}:${_two(s % 60)}';
}

NdGlyph journalTypeGlyph(JournalType type) => switch (type) {
  JournalType.text => Nd.textLines,
  JournalType.photo => Nd.photo,
  JournalType.video => Nd.video,
  JournalType.audio => Nd.mic,
};

class MediaImage extends StatefulWidget {
  const MediaImage(this.relativePath, {super.key, this.fit = BoxFit.cover});

  final String? relativePath;
  final BoxFit fit;

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  File? _file;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(MediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath) {
      _file = null;
      _resolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final file = await MediaStore.fileFor(widget.relativePath);
    if (!mounted) return;
    setState(() {
      _file = file;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _file == null
          ? Container(
              key: const ValueKey('media_placeholder'),
              color: p.panelHi,
              child: _resolved
                  ? Center(child: NdIcon(Nd.x, color: p.textGhost, size: 20))
                  : null,
            )
          : SizedBox.expand(
              key: ValueKey(_file!.path),
              child: Image.file(
                _file!,
                fit: widget.fit,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Container(
                  color: p.panelHi,
                  child: Center(
                    child: NdIcon(Nd.x, color: p.textGhost, size: 20),
                  ),
                ),
              ),
            ),
    );
  }
}

class JournalEntryView extends StatefulWidget {
  const JournalEntryView({super.key, required this.entry});

  final JournalEntry entry;

  @override
  State<JournalEntryView> createState() => _JournalEntryViewState();
}

class _JournalEntryViewState extends State<JournalEntryView> {
  bool _editing = false;
  late final TextEditingController _textController = TextEditingController(
    text: widget.entry.body,
  );

  VideoPlayerController? _video;
  bool _videoReady = false;

  AudioPlayer? _audio;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _doneSub;
  Duration _audioPos = Duration.zero;
  Duration _audioDur = Duration.zero;
  bool _audioPlaying = false;
  bool _audioStarted = false;
  String? _audioPath;

  bool _mediaMissing = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry.type == JournalType.video) _initVideo();
    if (widget.entry.type == JournalType.audio) _initAudio();
  }

  @override
  void dispose() {
    _textController.dispose();
    _video?.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _doneSub?.cancel();
    _audio?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    final file = await MediaStore.fileFor(widget.entry.mediaPath);
    if (!mounted) return;
    if (file == null) {
      setState(() => _mediaMissing = true);
      return;
    }
    final controller = VideoPlayerController.file(file);
    _video = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (mounted) setState(() => _mediaMissing = true);
      return;
    }
    if (mounted) setState(() => _videoReady = true);
  }

  Future<void> _initAudio() async {
    final file = await MediaStore.fileFor(widget.entry.mediaPath);
    if (!mounted) return;
    if (file == null) {
      setState(() => _mediaMissing = true);
      return;
    }
    _audioPath = file.path;
    final player = AudioPlayer();
    _audio = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
    _durSub = player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDur = d);
    });
    _posSub = player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _audioPos = d);
    });
    _doneSub = player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _audioPlaying = false;
          _audioStarted = false;
          _audioPos = Duration.zero;
        });
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _toggleAudio() async {
    final player = _audio;
    final path = _audioPath;
    if (player == null || path == null) return;
    HapticFeedback.selectionClick();
    Sfx.tick();
    if (_audioPlaying) {
      await player.pause();
      if (mounted) setState(() => _audioPlaying = false);
      return;
    }
    try {
      // resume() before the first play() throws, so track whether playback ever started
      if (_audioStarted) {
        await player.resume();
      } else {
        await player.play(DeviceFileSource(path));
        _audioStarted = true;
      }
      if (mounted) setState(() => _audioPlaying = true);
    } catch (_) {}
  }

  Future<void> _saveTextEdit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final journal = JournalScope.of(context);
    widget.entry.body = text;
    await journal.update(widget.entry);
    if (!mounted) return;
    Sfx.complete();
    setState(() => _editing = false);
    showNdToast(context, 'Entry updated', glyph: Nd.check);
  }

  Future<void> _deleteWithUndo() async {
    final journal = JournalScope.of(context);
    final navigator = Navigator.of(context);
    final host = navigator.context;
    final entry = widget.entry;
    HapticFeedback.heavyImpact();
    Sfx.tick();
    await journal.remove(entry, keepMedia: true);
    if (!host.mounted) return;
    navigator.pop();
    showNdToast(
      host,
      'Entry deleted',
      glyph: Nd.trash,
      actionLabel: 'Undo',
      onAction: () => journal.restore(entry),
      onExpire: () => journal.purgeMedia(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final entry = widget.entry;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NdHeader(
              title: entry.type.label,
              subtitle: journalStamp(entry.at),
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
                  ..._body(p, entry),
                  if (entry.type != JournalType.text &&
                      entry.body.isNotEmpty) ...[
                    const SizedBox(height: NdSpace.lg),
                    Text(entry.body, style: p.body),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NdSpace.page,
                NdSpace.xs,
                NdSpace.page,
                NdSpace.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (entry.type == JournalType.text && !_editing)
                    DialogAction(
                      label: 'Edit',
                      onTap: () => setState(() => _editing = true),
                    ),
                  const SizedBox(width: NdSpace.xs),
                  DialogAction(
                    label: 'Delete',
                    danger: true,
                    onTap: _deleteWithUndo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(NaviPalette p, JournalEntry entry) => switch (entry.type) {
    JournalType.text => [_textBody(p, entry)],
    JournalType.photo => [_photoBody()],
    JournalType.video => [_videoBody(p)],
    JournalType.audio => [_audioBody(p, entry)],
  };

  Widget _textBody(NaviPalette p, JournalEntry entry) {
    if (!_editing) {
      return Text(entry.body, style: p.body.copyWith(fontSize: 17));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NdTextField(
          controller: _textController,
          maxLines: null,
          autofocus: true,
          fontSize: 17,
        ),
        const SizedBox(height: NdSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DialogAction(
              label: 'Cancel',
              onTap: () {
                _textController.text = entry.body;
                setState(() => _editing = false);
              },
            ),
            const SizedBox(width: NdSpace.xs),
            NdButton(
              label: 'Save',
              height: 42,
              filled: true,
              onTap: _saveTextEdit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _photoBody() {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NdRadius.card),
      child: Container(
        height: 430,
        color: p.panel,
        child: InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: MediaImage(widget.entry.mediaPath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _missingTile(NaviPalette p) => ClipRRect(
    borderRadius: BorderRadius.circular(NdRadius.card),
    child: Container(
      height: 200,
      color: p.panel,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NdIcon(Nd.x, color: p.textGhost, size: 24),
            const SizedBox(height: NdSpace.md),
            Text('This file is no longer on the device', style: p.label),
          ],
        ),
      ),
    ),
  );

  Widget _videoBody(NaviPalette p) {
    if (_mediaMissing) return _missingTile(p);
    final video = _video;
    if (!_videoReady || video == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(NdRadius.card),
        child: Container(
          height: 260,
          color: p.panel,
          child: Center(child: Text('Loading video...', style: p.label)),
        ),
      );
    }
    return NdVideoPlayer(
      controller: video,
      borderRadius: BorderRadius.circular(NdRadius.card),
    );
  }

  Widget _audioBody(NaviPalette p, JournalEntry entry) {
    if (_mediaMissing) return _missingTile(p);
    final totalMs = _audioDur.inMilliseconds > 0
        ? _audioDur.inMilliseconds
        : (entry.durationMs ?? 0);
    final posMs = _audioPos.inMilliseconds;
    return NdCard(
      padding: const EdgeInsets.all(NdSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tactile(
                pressedScale: 0.9,
                child: GestureDetector(
                  onTap: _toggleAudio,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: NdIcon(
                          _audioPlaying ? Nd.pause : Nd.play,
                          key: ValueKey(_audioPlaying),
                          color: p.onAccent,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: NdSpace.xl),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(journalDuration(posMs), style: p.dot(40, color: p.text)),
                  const SizedBox(height: NdSpace.xs),
                  Text('of ${journalDuration(totalMs)}', style: p.label),
                ],
              ),
            ],
          ),
          const SizedBox(height: NdSpace.xl),
          NdProgressBar(
            value: totalMs == 0 ? 0 : posMs / totalMs,
            segments: 28,
            height: 6,
          ),
        ],
      ),
    );
  }
}
