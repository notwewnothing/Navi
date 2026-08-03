import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import 'pixel_icons.dart';
import 'tactile.dart';


class PixelButton extends StatelessWidget {
  const PixelButton({
    super.key,
    required this.label,
    this.onTap,
    this.glyph,
    this.filled = false,
    this.danger = false,
    this.expand = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onTap;
  final PixelGlyph? glyph;
  final bool filled;
  final bool danger;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onTap != null;
    final tone = danger ? p.danger : p.accent;
    final fg = !enabled
        ? p.textGhost
        : filled
        ? Colors.black
        : tone;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: height,
      
      padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 20),
      decoration: BoxDecoration(
        color: filled && enabled ? tone : Colors.transparent,
        border: Border.all(color: enabled ? tone : p.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (glyph != null) ...[
            PixelIcon(glyph!, color: fg, size: 14),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: kFontPixel,
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Tactile(
      pressedScale: 0.96,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: child,
      ),
    );
  }
}


class PixelCard extends StatelessWidget {
  const PixelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted ? p.panelHi : p.panel,
        border: Border.all(color: highlighted ? p.accentDim : p.border),
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return Tactile(
      pressedScale: 0.98,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              },
        child: card,
      ),
    );
  }
}


class PixelSwitch extends StatelessWidget {
  const PixelSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.9,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Sfx.tick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 46,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? p.accentGhost : p.panel,
            border: Border.all(color: value ? p.accent : p.border, width: 1.5),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              color: value ? p.accent : p.textGhost,
            ),
          ),
        ),
      ),
    );
  }
}


class PixelChip extends StatelessWidget {
  const PixelChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.92,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                Sfx.tick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 6 : 9,
          ),
          decoration: BoxDecoration(
            color: selected ? p.accent : Colors.transparent,
            border: Border.all(color: selected ? p.accent : p.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontPixel,
              fontSize: compact ? 7 : 8,
              letterSpacing: 1,
              color: selected ? Colors.black : p.textDim,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}


class PixelProgressBar extends StatelessWidget {
  const PixelProgressBar({
    super.key,
    required this.value,
    this.segments = 24,
    this.height = 10,
    this.color,
  });

  final double value;
  final int segments;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => LayoutBuilder(
        builder: (context, box) {
          final lit = (t * segments).round();
          return Row(
            children: [
              for (var i = 0; i < segments; i++) ...[
                Expanded(
                  child: Container(
                    height: height,
                    color: i < lit
                        ? (color ?? p.accent)
                        : p.border.withValues(alpha: 0.6),
                  ),
                ),
                if (i < segments - 1) const SizedBox(width: 3),
              ],
            ],
          );
        },
      ),
    );
  }
}


class PixelHeader extends StatelessWidget {
  const PixelHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(child: Text(title, style: p.h1)),
          ...actions,
        ],
      ),
    );
  }
}


class PixelIconButton extends StatelessWidget {
  const PixelIconButton({
    super.key,
    required this.glyph,
    required this.onTap,
    this.color,
    this.size = 18,
  });

  final PixelGlyph glyph;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.85,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: PixelIcon(glyph, color: color ?? p.textDim, size: size),
        ),
      ),
    );
  }
}

class PixelFab extends StatelessWidget {
  const PixelFab({super.key, required this.onTap, this.glyph = Px.plus});

  final VoidCallback onTap;
  final PixelGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.9,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: p.accent,
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: PixelIcon(glyph, color: Colors.black, size: 22),
          ),
        ),
      ),
    );
  }
}

class PixelTextField extends StatelessWidget {
  const PixelTextField({
    super.key,
    this.controller,
    this.hint,
    this.autofocus = false,
    this.maxLines = 1,
    this.fontSize = 22,
    this.onChanged,
    this.onSubmitted,
    this.capitalization = TextCapitalization.sentences,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool autofocus;
  final int? maxLines;
  final double fontSize;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: capitalization,
      cursorColor: p.accent,
      cursorWidth: 7,
      style: TextStyle(
        fontFamily: kFontTerminal,
        fontSize: fontSize,
        color: p.text,
        height: 1.15,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: kFontTerminal,
          fontSize: fontSize,
          color: p.textGhost,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: p.accent),
        ),
      ),
    );
  }
}


Future<T?> showPixelDialog<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  List<Widget> Function(BuildContext)? actions,
}) {
  final p = context.palette;
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: p.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.borderHi),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: p.panelHi,
            child: Row(
              children: [
                Container(width: 6, height: 6, color: p.accent),
                const SizedBox(width: 4),
                Container(width: 6, height: 6, color: p.accentDim),
                const SizedBox(width: 4),
                Container(width: 6, height: 6, color: p.border),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: p.label.copyWith(color: p.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Builder(builder: builder),
            ),
          ),
          if (actions != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Builder(
                builder: (context) => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (i, a) in actions(context).indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      a,
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}


Future<T?> showPixelSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollControlled = true,
}) {
  final p = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    backgroundColor: p.panel,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: p.borderHi),
      borderRadius: BorderRadius.zero,
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Builder(builder: builder),
    ),
  );
}


class DialogAction extends StatelessWidget {
  const DialogAction({
    super.key,
    required this.label,
    required this.onTap,
    this.emphasized = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = danger
        ? p.danger
        : emphasized
        ? p.accent
        : p.textDim;
    return Tactile(
      pressedScale: 0.92,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontPixel,
              fontSize: 9,
              letterSpacing: 1.5,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}


class EmptyState extends StatefulWidget {
  const EmptyState({super.key, required this.message, this.glyph});

  final String message;
  final PixelGlyph? glyph;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 0.85).animate(
          CurvedAnimation(parent: _flicker, curve: Curves.easeInOut),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.glyph != null) ...[
              PixelIcon(widget.glyph!, color: p.textGhost, size: 28),
              const SizedBox(height: 16),
            ],
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: p.quote.copyWith(color: p.textDim),
            ),
          ],
        ),
      ),
    );
  }
}


void showPixelToast(BuildContext context, String message, {PixelGlyph? glyph}) {
  final p = context.palette;
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: 110,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - t)),
              child: child,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: p.panelHi,
                border: Border.all(color: p.accentDim),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (glyph != null) ...[
                    PixelIcon(glyph, color: p.accent, size: 14),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(message, style: p.body.copyWith(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2600), () {
    if (entry.mounted) entry.remove();
  });
}

class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.dayBits, required this.onChanged});

  final int dayBits;
  final ValueChanged<int> onChanged;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: PixelChip(
              label: _labels[i],
              compact: true,
              selected: (dayBits >> i) & 1 == 1,
              onTap: () => onChanged(dayBits ^ (1 << i)),
            ),
          ),
        ],
      ],
    );
  }
}


class PixelWheel extends StatelessWidget {
  const PixelWheel({
    super.key,
    required this.itemCount,
    required this.controller,
    required this.labelFor,
    this.width = 72,
    this.fontSize = 44,
    this.onChanged,
  });

  final int itemCount;
  final FixedExtentScrollController controller;
  final String Function(int) labelFor;
  final double width;
  final double fontSize;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: fontSize + 12,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.004,
        overAndUnderCenterOpacity: 0.25,
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          Sfx.tick();
          onChanged?.call(i);
        },
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < itemCount; i++)
              Center(
                child: Text(
                  labelFor(i),
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: fontSize,
                    color: p.text,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
