import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import 'nd_icons.dart';
import 'tactile.dart';

/// Full player around an already-initialised [VideoPlayerController]:
/// scrub, skip, speed, mute, fullscreen. The controller stays owned by the
/// caller so the same one can be handed to the fullscreen route.
class NdVideoPlayer extends StatefulWidget {
  const NdVideoPlayer({
    super.key,
    required this.controller,
    this.borderRadius,
    this.allowFullscreen = true,
    this.isFullscreen = false,
  });

  final VideoPlayerController controller;
  final BorderRadius? borderRadius;
  final bool allowFullscreen;
  final bool isFullscreen;

  @override
  State<NdVideoPlayer> createState() => _NdVideoPlayerState();
}

class _NdVideoPlayerState extends State<NdVideoPlayer> {
  static const _skip = Duration(seconds: 10);
  static const _speeds = [1.0, 1.5, 2.0, 0.5];

  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _scrubbing = false;
  double _scrubValue = 0;
  int _speedIndex = 0;
  bool _muted = false;

  VideoPlayerController get _video => widget.controller;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onTick);
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _video.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    // controls only get in the way once playback is actually running
    if (!_video.value.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _restartHideTimer();
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    Sfx.tick();
    final value = _video.value;
    if (value.isPlaying) {
      _video.pause();
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
    } else {
      // the stream sits at the end after finishing, rewind before replaying
      if (value.position >= value.duration) _video.seekTo(Duration.zero);
      _video.play();
      _restartHideTimer();
    }
    setState(() {});
  }

  Future<void> _seekBy(Duration delta) async {
    final value = _video.value;
    var target = value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > value.duration) target = value.duration;
    HapticFeedback.selectionClick();
    await _video.seekTo(target);
    _showControls();
  }

  void _cycleSpeed() {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
    _video.setPlaybackSpeed(_speeds[_speedIndex]);
    Sfx.tick();
    _showControls();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _video.setVolume(_muted ? 0 : 1);
    _showControls();
  }

  Future<void> _toggleFullscreen() async {
    Sfx.tick();
    if (widget.isFullscreen) {
      Navigator.of(context).pop();
      return;
    }
    _hideTimer?.cancel();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: _FullscreenVideo(controller: _video),
        ),
      ),
    );
    if (mounted) _showControls();
  }

  String _clock(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value = _video.value;
    final duration = value.duration.inMilliseconds;
    final position = value.position.inMilliseconds;
    final progress = _scrubbing
        ? _scrubValue
        : duration == 0
        ? 0.0
        : (position / duration).clamp(0.0, 1.0);
    final ratio = value.aspectRatio <= 0 ? 16 / 9 : value.aspectRatio;
    final ended = duration > 0 && position >= duration;

    final surface = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Center(
          child: AspectRatio(aspectRatio: ratio, child: VideoPlayer(_video)),
        ),
        // double-tap either half to jump, single tap toggles the controls
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showControls,
                onDoubleTap: () => _seekBy(-_skip),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showControls,
                onDoubleTap: () => _seekBy(_skip),
              ),
            ),
          ],
        ),
        IgnorePointer(
          ignoring: !_controlsVisible,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: NdSpace.sm,
                  right: NdSpace.sm,
                  child: Row(
                    children: [
                      _GlassButton(
                        glyph: _muted ? Nd.volumeOff : Nd.volumeOn,
                        onTap: _toggleMute,
                        tooltip: _muted ? 'Unmute' : 'Mute',
                      ),
                      const SizedBox(width: NdSpace.sm),
                      _GlassButton(
                        label: '${_speeds[_speedIndex]}x',
                        onTap: _cycleSpeed,
                        tooltip: 'Playback speed',
                      ),
                      if (widget.allowFullscreen) ...[
                        const SizedBox(width: NdSpace.sm),
                        _GlassButton(
                          glyph: widget.isFullscreen ? Nd.collapse : Nd.expand,
                          onTap: _toggleFullscreen,
                          tooltip: widget.isFullscreen
                              ? 'Exit fullscreen'
                              : 'Fullscreen',
                        ),
                      ],
                    ],
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GlassButton(
                        glyph: Nd.skipBack,
                        size: 46,
                        onTap: () => _seekBy(-_skip),
                        tooltip: 'Back 10s',
                      ),
                      const SizedBox(width: NdSpace.xl),
                      Tactile(
                        pressedScale: 0.9,
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: p.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: NdIcon(
                                ended
                                    ? Nd.replay
                                    : value.isPlaying
                                    ? Nd.pause
                                    : Nd.play,
                                color: p.onAccent,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: NdSpace.xl),
                      _GlassButton(
                        glyph: Nd.skipForward,
                        size: 46,
                        onTap: () => _seekBy(_skip),
                        tooltip: 'Forward 10s',
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: NdSpace.md,
                  right: NdSpace.md,
                  bottom: NdSpace.sm,
                  child: Row(
                    children: [
                      Text(
                        _clock(
                          _scrubbing
                              ? Duration(
                                  milliseconds: (progress * duration).round(),
                                )
                              : value.position,
                        ),
                        style: p.dot(15, color: Colors.white),
                      ),
                      const SizedBox(width: NdSpace.md),
                      Expanded(
                        child: _Scrubber(
                          value: progress,
                          onChangeStart: () {
                            _hideTimer?.cancel();
                            setState(() {
                              _scrubbing = true;
                              _scrubValue = progress;
                            });
                          },
                          onChanged: (v) => setState(() => _scrubValue = v),
                          onChangeEnd: (v) async {
                            await _video.seekTo(
                              Duration(milliseconds: (v * duration).round()),
                            );
                            if (!mounted) return;
                            setState(() => _scrubbing = false);
                            _restartHideTimer();
                          },
                        ),
                      ),
                      const SizedBox(width: NdSpace.md),
                      Text(
                        _clock(value.duration),
                        style: p.dot(15, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final sized = widget.isFullscreen
        ? surface
        : AspectRatio(aspectRatio: ratio, child: surface);
    final radius = widget.borderRadius;
    return radius == null
        ? sized
        : ClipRRect(borderRadius: radius, child: sized);
  }
}

/// Drag anywhere on the track to seek; the thumb grows while held.
class _Scrubber extends StatefulWidget {
  const _Scrubber({
    required this.value,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  bool _held = false;

  void _emit(double dx, double width, {bool end = false}) {
    final v = (dx / width).clamp(0.0, 1.0);
    if (end) {
      widget.onChangeEnd(v);
    } else {
      widget.onChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            setState(() => _held = true);
            HapticFeedback.selectionClick();
            widget.onChangeStart();
            _emit(d.localPosition.dx, width);
          },
          onHorizontalDragUpdate: (d) => _emit(d.localPosition.dx, width),
          onHorizontalDragEnd: (_) {
            setState(() => _held = false);
            _emit(widget.value * width, width, end: true);
          },
          onTapDown: (d) {
            widget.onChangeStart();
            _emit(d.localPosition.dx, width, end: true);
          },
          child: SizedBox(
            height: 28,
            child: Center(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 4,
                    width: width * widget.value,
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Positioned(
                    left: (width * widget.value - (_held ? 8 : 6)).clamp(
                      0.0,
                      width - (_held ? 16 : 12),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _held ? 16 : 12,
                      height: _held ? 16 : 12,
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    this.glyph,
    this.label,
    required this.onTap,
    this.tooltip,
    this.size = 38,
  });

  final NdGlyph? glyph;
  final String? label;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final button = Tactile(
      pressedScale: 0.9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: size,
          constraints: BoxConstraints(minWidth: size),
          padding: label == null
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: NdSpace.sm),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: label == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: label == null
                ? null
                : BorderRadius.circular(NdRadius.pill),
            border: Border.all(color: Colors.white24),
          ),
          child: Center(
            child: label != null
                ? Text(label!, style: p.dot(14, color: Colors.white))
                : NdIcon(glyph!, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // empty list hands orientation back to the system, which is how the
    // rest of the app runs
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: NdVideoPlayer(controller: widget.controller, isFullscreen: true),
  );
}
