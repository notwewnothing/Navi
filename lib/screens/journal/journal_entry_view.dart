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
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/tactile.dart';

const _monthsAbbr = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

String _two(int v) => v.toString().padLeft(2, '0');

String journalStamp(DateTime at) =>
    '${_monthsAbbr[at.month - 1]} ${at.day} — ${_two(at.hour)}:${_two(at.minute)}';

String journalHm(DateTime at) => '${_two(at.hour)}:${_two(at.minute)}';

String journalDuration(int? ms) {
  final s = ((ms ?? 0) / 1000).round();
  return '${s ~/ 60}:${_two(s % 60)}';
}

PixelGlyph journalTypeGlyph(JournalType type) => switch (type) {
  JournalType.text => Px.textLines,
  JournalType.photo => Px.photo,
  JournalType.video => Px.video,
  JournalType.audio => Px.mic,
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
                  ? Center(
                      child: PixelIcon(Px.x, color: p.textGhost, size: 14),
                    )
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
                    child: PixelIcon(Px.x, color: p.textGhost, size: 14),
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
  late final TextEditingController _textController =
      TextEditingController(text: widget.entry.body);

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
    _video?.removeListener(_onVideoTick);
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
    controller.addListener(_onVideoTick);
    if (mounted) setState(() => _videoReady = true);
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  void _toggleVideo() {
    final video = _video;
    if (video == null || !_videoReady) return;
    HapticFeedback.selectionClick();
    Sfx.tick();
    if (video.value.isPlaying) {
      video.pause();
    } else {
      if (video.value.position >= video.value.duration) {
        video.seekTo(Duration.zero);
      }
      video.play();
    }
    setState(() {});
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
    showPixelToast(context, 'ENTRY REWRITTEN', glyph: Px.check);
  }


  void _confirmDelete() {
    final p = context.palette;
    final journal = JournalScope.of(context);
    final navigator = Navigator.of(context);
    showPixelDialog<void>(
      context: context,
      title: 'ERASE FROM THE WIRED?',
      builder: (_) => Text(
        'This entry and its media will be deleted. '
        'If it is not remembered, it never happened.',
        style: p.body,
      ),
      actions: (dialogContext) => [
        DialogAction(
          label: 'CANCEL',
          onTap: () => Navigator.pop(dialogContext),
        ),
        DialogAction(
          label: 'ERASE',
          danger: true,
          onTap: () async {
            Navigator.pop(dialogContext);
            HapticFeedback.heavyImpact();
            await journal.remove(widget.entry);
            Sfx.glitch();
            navigator.pop();
          },
        ),
      ],
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
            PixelHeader(
              title: entry.type.label,
              leading: PixelIconButton(
                glyph: Px.left,
                onTap: () => Navigator.pop(context),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(journalStamp(entry.at), style: p.label),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  ..._body(p, entry),
                  if (entry.type != JournalType.text &&
                      entry.body.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(entry.body, style: p.body),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (entry.type == JournalType.text && !_editing)
                    DialogAction(
                      label: 'EDIT',
                      onTap: () => setState(() => _editing = true),
                    ),
                  const SizedBox(width: 8),
                  DialogAction(
                    label: 'DELETE',
                    danger: true,
                    onTap: _confirmDelete,
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
      return Text(
        entry.body,
        style: TextStyle(
          fontFamily: kFontTerminal,
          fontSize: 22,
          color: p.text,
          height: 1.2,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelTextField(
          controller: _textController,
          maxLines: null,
          autofocus: true,
          fontSize: 22,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DialogAction(
              label: 'CANCEL',
              onTap: () {
                _textController.text = entry.body;
                setState(() => _editing = false);
              },
            ),
            const SizedBox(width: 8),
            PixelButton(
              label: 'SAVE',
              height: 38,
              filled: true,
              onTap: _saveTextEdit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _photoBody() {
    return Container(
      height: 430,
      color: Colors.black,
      child: InteractiveViewer(
        maxScale: 6,
        child: Center(child: MediaImage(widget.entry.mediaPath, fit: BoxFit.contain)),
      ),
    );
  }

  Widget _missingTile(NaviPalette p) => Container(
    height: 200,
    color: p.panelHi,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelIcon(Px.x, color: p.textGhost, size: 20),
          const SizedBox(height: 10),
          Text('SIGNAL LOST — FILE MISSING', style: p.label),
        ],
      ),
    ),
  );

  Widget _videoBody(NaviPalette p) {
    if (_mediaMissing) return _missingTile(p);
    final video = _video;
    if (!_videoReady || video == null) {
      return Container(
        height: 260,
        color: Colors.black,
        child: Center(child: Text('DECODING...', style: p.label)),
      );
    }
    final value = video.value;
    final durMs = value.duration.inMilliseconds;
    final posMs = value.position.inMilliseconds;
    final ratio = value.aspectRatio <= 0 ? 16 / 9 : value.aspectRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tactile(
          pressedScale: 0.99,
          child: GestureDetector(
            onTap: _toggleVideo,
            child: Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: ratio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(video),
                    AnimatedOpacity(
                      opacity: value.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Center(
                          child: PixelIcon(Px.play, color: p.accent, size: 34),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PixelProgressBar(
          value: durMs == 0 ? 0 : posMs / durMs,
          segments: 28,
          height: 8,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              journalDuration(posMs),
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 20,
                color: p.textDim,
              ),
            ),
            const Spacer(),
            Text(
              journalDuration(durMs),
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 20,
                color: p.textDim,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _audioBody(NaviPalette p, JournalEntry entry) {
    if (_mediaMissing) return _missingTile(p);
    final totalMs = _audioDur.inMilliseconds > 0
        ? _audioDur.inMilliseconds
        : (entry.durationMs ?? 0);
    final posMs = _audioPos.inMilliseconds;
    return PixelCard(
      padding: const EdgeInsets.all(18),
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
                      color: _audioPlaying ? p.accentGhost : Colors.transparent,
                      border: Border.all(color: p.accent, width: 1.5),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: PixelIcon(
                          _audioPlaying ? Px.pause : Px.play,
                          key: ValueKey(_audioPlaying),
                          color: p.accent,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journalDuration(posMs),
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 44,
                      color: p.text,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '/ ${journalDuration(totalMs)}',
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 20,
                      color: p.textDim,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          PixelProgressBar(
            value: totalMs == 0 ? 0 : posMs / totalMs,
            segments: 28,
            height: 8,
          ),
        ],
      ),
    );
  }
}
