import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import 'nd_icons.dart';
import 'tactile.dart';

/// Pill button. Filled reads as the primary action, outlined as secondary.
class NdButton extends StatelessWidget {
  const NdButton({
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
  final NdGlyph? glyph;
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
        ? (danger ? Colors.white : p.onAccent)
        : p.text;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: height,
      padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 24),
      decoration: BoxDecoration(
        color: filled && enabled ? tone : Colors.transparent,
        border: Border.all(
          color: enabled ? (filled ? tone : p.borderHi) : p.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(NdRadius.pill),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (glyph != null) ...[
            NdIcon(glyph!, color: fg, size: 18),
            const SizedBox(width: NdSpace.sm),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: kFontUI,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
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
      pressedScale: 0.97,
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

class NdCard extends StatelessWidget {
  const NdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NdSpace.lg),
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
    this.radius = NdRadius.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlighted;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted ? p.panelHi : p.panel,
        border: Border.all(color: highlighted ? p.borderHi : p.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return Tactile(
      pressedScale: 0.985,
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

class NdSwitch extends StatelessWidget {
  const NdSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.92,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Sfx.tick();
          onChanged(!value);
        },
        // 48dp tap target around a 52x30 track
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? p.accent : p.panelHi,
              border: Border.all(color: value ? p.accent : p.border),
              borderRadius: BorderRadius.circular(NdRadius.pill),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? p.onAccent : p.textGhost,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NdChip extends StatelessWidget {
  const NdChip({
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
      pressedScale: 0.94,
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
            horizontal: compact ? 10 : 16,
            vertical: compact ? 8 : 11,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.accent : Colors.transparent,
            border: Border.all(color: selected ? p.accent : p.border),
            borderRadius: BorderRadius.circular(NdRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontUI,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: selected ? p.onAccent : p.textDim,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented bar. The dashes echo the dot-matrix grid rather than a solid fill.
class NdProgressBar extends StatelessWidget {
  const NdProgressBar({
    super.key,
    required this.value,
    this.segments = 24,
    this.height = 8,
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
      builder: (context, t, _) {
        final lit = (t * segments).round();
        return Row(
          children: [
            for (var i = 0; i < segments; i++) ...[
              Expanded(
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: i < lit ? (color ?? p.accent) : p.panelHi,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              if (i < segments - 1) const SizedBox(width: 3),
            ],
          ],
        );
      },
    );
  }
}

class NdHeader extends StatelessWidget {
  const NdHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NdSpace.page,
        NdSpace.lg,
        NdSpace.page,
        NdSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: NdSpace.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: p.h1),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: p.label),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Circular icon button with a 44dp minimum tap target.
class NdIconButton extends StatelessWidget {
  const NdIconButton({
    super.key,
    required this.glyph,
    required this.onTap,
    this.color,
    this.size = 22,
    this.tooltip,
    this.outlined = false,
    this.radius,
  });

  final NdGlyph glyph;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  final String? tooltip;
  final bool outlined;

  /// Null keeps the default circle; a value squares it off to that corner
  /// radius and always draws the outlined surface.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget button = Tactile(
      pressedScale: 0.88,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: radius == null
                ? null
                : BorderRadius.circular(radius!),
            color: outlined || radius != null ? p.panel : Colors.transparent,
            border: outlined || radius != null
                ? Border.all(color: p.border)
                : null,
          ),
          child: NdIcon(glyph, color: color ?? p.textDim, size: size),
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class NdFab extends StatelessWidget {
  const NdFab({
    super.key,
    required this.onTap,
    this.glyph = Nd.plus,
    this.label,
  });

  final VoidCallback onTap;
  final NdGlyph glyph;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tactile(
      pressedScale: 0.93,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 22),
          width: label == null ? 60 : null,
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(NdRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NdIcon(glyph, color: p.onAccent, size: 26),
              if (label != null) ...[
                const SizedBox(width: NdSpace.sm),
                Text(
                  label!,
                  style: TextStyle(
                    fontFamily: kFontUI,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: p.onAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NdTextField extends StatelessWidget {
  const NdTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.autofocus = false,
    this.maxLines = 1,
    this.fontSize = 16,
    this.onChanged,
    this.onSubmitted,
    this.capitalization = TextCapitalization.sentences,
    this.filled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final bool autofocus;
  final int? maxLines;
  final double fontSize;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization capitalization;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: capitalization,
      cursorColor: p.accent,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(1),
      style: TextStyle(
        fontFamily: kFontUI,
        fontSize: fontSize,
        color: p.text,
        height: 1.4,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: filled,
        fillColor: filled ? p.panelHi : Colors.transparent,
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: kFontUI,
          fontSize: fontSize,
          color: p.textGhost,
          height: 1.4,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: filled ? NdSpace.lg : 0,
          vertical: filled ? 14 : 8,
        ),
        border: filled
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(NdRadius.inner),
                borderSide: BorderSide.none,
              )
            : null,
        enabledBorder: filled
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(NdRadius.inner),
                borderSide: BorderSide(color: p.border),
              )
            : UnderlineInputBorder(borderSide: BorderSide(color: p.border)),
        focusedBorder: filled
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(NdRadius.inner),
                borderSide: BorderSide(color: p.accent, width: 1.5),
              )
            : UnderlineInputBorder(
                borderSide: BorderSide(color: p.accent, width: 1.5),
              ),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!.toUpperCase(), style: p.h2),
        const SizedBox(height: NdSpace.sm),
        field,
      ],
    );
  }
}

Future<T?> showNdDialog<T>({
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
      insetPadding: const EdgeInsets.symmetric(
        horizontal: NdSpace.xl,
        vertical: NdSpace.xl,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.border),
        borderRadius: BorderRadius.circular(NdRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NdSpace.xl,
              NdSpace.xl,
              NdSpace.xl,
              NdSpace.md,
            ),
            child: Text(title, style: p.title),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: NdSpace.xl),
              child: Builder(builder: builder),
            ),
          ),
          if (actions != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NdSpace.md,
                NdSpace.md,
                NdSpace.md,
                NdSpace.md,
              ),
              child: Builder(
                builder: (context) => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (i, a) in actions(context).indexed) ...[
                      if (i > 0) const SizedBox(width: NdSpace.xs),
                      a,
                    ],
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: NdSpace.xl),
        ],
      ),
    ),
  );
}

Future<T?> showNdSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollControlled = true,
}) {
  final p = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    backgroundColor: p.panel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: p.border),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(NdRadius.sheet),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Builder(builder: builder),
    ),
  );
}

/// Grab handle plus title. Every sheet starts with one so they read alike.
class NdSheetHeader extends StatelessWidget {
  const NdSheetHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: NdSpace.md, bottom: NdSpace.sm),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: p.borderHi,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NdSpace.xl,
            NdSpace.sm,
            NdSpace.md,
            NdSpace.md,
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: p.title)),
              ...actions,
            ],
          ),
        ),
      ],
    );
  }
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
      pressedScale: 0.94,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: NdSpace.lg),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontUI,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty states carry the way out, not just an apology.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.glyph,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final NdGlyph? glyph;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NdSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.panel,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.border),
                ),
                child: Center(
                  child: NdIcon(glyph!, color: p.textGhost, size: 28),
                ),
              ),
              const SizedBox(height: NdSpace.lg),
            ],
            Text(message, textAlign: TextAlign.center, style: p.bodyDim),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: NdSpace.lg),
              NdButton(
                label: actionLabel!,
                glyph: Nd.plus,
                height: 44,
                onTap: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Toast with an optional inline action, so destructive taps stay undoable.
void showNdToast(
  BuildContext context,
  String message, {
  NdGlyph? glyph,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final p = context.palette;
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  var dismissed = false;
  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: NdSpace.lg,
      right: NdSpace.lg,
      bottom: 100,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              NdSpace.lg,
              NdSpace.md,
              onAction == null ? NdSpace.lg : NdSpace.xs,
              NdSpace.md,
            ),
            decoration: BoxDecoration(
              color: p.panelHi,
              border: Border.all(color: p.borderHi),
              borderRadius: BorderRadius.circular(NdRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (glyph != null) ...[
                  NdIcon(glyph, color: p.accent, size: 18),
                  const SizedBox(width: NdSpace.md),
                ],
                Flexible(child: Text(message, style: p.body)),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: NdSpace.sm),
                  DialogAction(
                    label: actionLabel,
                    emphasized: true,
                    onTap: () {
                      dismiss();
                      onAction();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(
    Duration(milliseconds: onAction == null ? 2400 : 4200),
    dismiss,
  );
}

/// Slow-breathing dot. Stands in for "live" states — recording, scanning,
/// waiting on a service — the way Nothing's glyph lights pulse.
class NdPulseDot extends StatefulWidget {
  const NdPulseDot({super.key, this.size = 10, this.color});

  final double size;
  final Color? color;

  @override
  State<NdPulseDot> createState() => _NdPulseDotState();
}

class _NdPulseDotState extends State<NdPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.palette.accent;
    return FadeTransition(
      opacity: Tween(
        begin: 0.25,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.dayBits, required this.onChanged});

  final int dayBits;
  final ValueChanged<int> onChanged;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: NdSpace.sm),
          Expanded(
            child: Tactile(
              pressedScale: 0.9,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Sfx.tick();
                  onChanged(dayBits ^ (1 << i));
                },
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (dayBits >> i) & 1 == 1
                          ? p.accent
                          : Colors.transparent,
                      border: Border.all(
                        color: (dayBits >> i) & 1 == 1 ? p.accent : p.border,
                      ),
                    ),
                    child: Text(
                      _labels[i],
                      style: TextStyle(
                        fontFamily: kFontUI,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: (dayBits >> i) & 1 == 1 ? p.onAccent : p.textDim,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Numeric picker wheel, set in Ndot since it is all digits.
class NdWheel extends StatelessWidget {
  const NdWheel({
    super.key,
    required this.itemCount,
    required this.controller,
    required this.labelFor,
    this.width = 80,
    this.fontSize = 46,
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
        itemExtent: fontSize + 14,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.003,
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
                  style: p.dot(fontSize, letterSpacing: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
