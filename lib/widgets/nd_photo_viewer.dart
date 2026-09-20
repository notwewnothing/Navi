import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/journal/journal_entry_view.dart' show MediaImage;
import '../theme/palette.dart';
import 'nd_icons.dart';
import 'nd_widgets.dart';

String photoHeroTag(String relativePath) => 'photo:$relativePath';

Future<void> openPhotoViewer(BuildContext context, {required String photo}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => NdPhotoViewer(photo: photo),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class NdPhotoViewer extends StatefulWidget {
  const NdPhotoViewer({super.key, required this.photo});

  final String photo;

  @override
  State<NdPhotoViewer> createState() => _NdPhotoViewerState();
}

class _NdPhotoViewerState extends State<NdPhotoViewer>
    with SingleTickerProviderStateMixin {
  final _view = TransformationController();
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomTween;
  double _dragY = 0;

  bool get _zoomed => _view.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _zoomAnim.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _view.value = tween.value;
    });
    _view.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _view.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _view.value, end: target).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic),
    );
    _zoomAnim.forward(from: 0);
  }

  void _doubleTapZoom(TapDownDetails details) {
    HapticFeedback.selectionClick();
    if (_zoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    // zoom toward the tapped point rather than the centre
    final origin = details.localPosition;
    _animateTo(
      Matrix4.identity()
        ..translateByDouble(-origin.dx * 1.5, -origin.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fade = (1 - (_dragY.abs() / 320)).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, _dragY),
              child: Opacity(
                opacity: fade,
                child: GestureDetector(
                  onDoubleTapDown: _doubleTapZoom,
                  onDoubleTap: () {},
                  // dismissing by drag only makes sense while zoomed out,
                  // otherwise it fights panning around the zoomed photo
                  onVerticalDragUpdate: _zoomed
                      ? null
                      : (d) => setState(() => _dragY += d.delta.dy),
                  onVerticalDragEnd: _zoomed
                      ? null
                      : (_) {
                          if (_dragY.abs() > 120) {
                            Navigator.of(context).pop();
                          } else {
                            setState(() => _dragY = 0);
                          }
                        },
                  child: Center(
                    child: Hero(
                      tag: photoHeroTag(widget.photo),
                      child: InteractiveViewer(
                        transformationController: _view,
                        panEnabled: _zoomed,
                        maxScale: 6,
                        child: MediaImage(widget.photo, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: NdSpace.sm,
            left: NdSpace.sm,
            child: SafeArea(
              child: Opacity(
                opacity: fade,
                child: NdIconButton(
                  glyph: Nd.x,
                  color: Colors.white,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
