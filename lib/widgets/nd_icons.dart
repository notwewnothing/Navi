import 'package:flutter/material.dart';

/// Every icon in the app resolves through here, so the whole set can be
/// re-pointed at a different family in one place.
class NdGlyph {
  const NdGlyph(this.data);

  final IconData data;
}

abstract final class Nd {
  static const home = NdGlyph(Icons.home_outlined);
  static const grid = NdGlyph(Icons.grid_view_outlined);
  static const book = NdGlyph(Icons.menu_book_outlined);
  static const calendar = NdGlyph(Icons.calendar_today_outlined);
  static const gear = NdGlyph(Icons.settings_outlined);

  static const check = NdGlyph(Icons.check_rounded);
  static const circle = NdGlyph(Icons.circle_outlined);
  static const circleFill = NdGlyph(Icons.circle);
  static const plus = NdGlyph(Icons.add_rounded);
  static const x = NdGlyph(Icons.close_rounded);

  static const camera = NdGlyph(Icons.photo_camera_outlined);
  static const mic = NdGlyph(Icons.mic_none_rounded);
  static const video = NdGlyph(Icons.videocam_outlined);
  static const textLines = NdGlyph(Icons.notes_rounded);
  static const photo = NdGlyph(Icons.image_outlined);

  static const play = NdGlyph(Icons.play_arrow_rounded);
  static const pause = NdGlyph(Icons.pause_rounded);
  static const stop = NdGlyph(Icons.stop_rounded);
  static const forward = NdGlyph(Icons.fast_forward_rounded);

  static const bell = NdGlyph(Icons.notifications_none_rounded);
  static const lock = NdGlyph(Icons.lock_outline_rounded);
  static const flame = NdGlyph(Icons.local_fire_department_outlined);

  static const left = NdGlyph(Icons.chevron_left_rounded);
  static const right = NdGlyph(Icons.chevron_right_rounded);
  static const up = NdGlyph(Icons.keyboard_arrow_up_rounded);
  static const down = NdGlyph(Icons.keyboard_arrow_down_rounded);

  static const trash = NdGlyph(Icons.delete_outline_rounded);
  static const pen = NdGlyph(Icons.edit_outlined);
  static const moon = NdGlyph(Icons.bedtime_outlined);
  static const sun = NdGlyph(Icons.wb_sunny_outlined);
  static const hourglass = NdGlyph(Icons.hourglass_empty_rounded);
  static const alarm = NdGlyph(Icons.alarm_rounded);
  static const block = NdGlyph(Icons.block_rounded);
  static const chart = NdGlyph(Icons.bar_chart_rounded);
  static const eye = NdGlyph(Icons.visibility_outlined);
  static const user = NdGlyph(Icons.person_outline_rounded);
  static const export = NdGlyph(Icons.ios_share_rounded);
  static const note = NdGlyph(Icons.sticky_note_2_outlined);
  static const star = NdGlyph(Icons.star_outline_rounded);
  static const heart = NdGlyph(Icons.favorite_outline_rounded);
  static const drop = NdGlyph(Icons.water_drop_outlined);
  static const leaf = NdGlyph(Icons.eco_outlined);
  static const coffee = NdGlyph(Icons.local_cafe_outlined);
  static const code = NdGlyph(Icons.code_rounded);
  static const bolt = NdGlyph(Icons.bolt_outlined);
  static const dumbbell = NdGlyph(Icons.fitness_center_rounded);
  static const pill = NdGlyph(Icons.medication_outlined);
  static const dot = NdGlyph(Icons.fiber_manual_record_rounded);

  static const habitIcons = <String, NdGlyph>{
    'flame': flame,
    'book': book,
    'dumbbell': dumbbell,
    'drop': drop,
    'moon': moon,
    'sun': sun,
    'heart': heart,
    'leaf': leaf,
    'coffee': coffee,
    'code': code,
    'bolt': bolt,
    'pen': pen,
    'note': note,
    'pill': pill,
    'star': star,
    'eye': eye,
  };

  static NdGlyph habitIcon(String name) => habitIcons[name] ?? flame;
}

class NdIcon extends StatelessWidget {
  const NdIcon(this.glyph, {super.key, required this.color, this.size = 20});

  final NdGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(glyph.data, color: color, size: size);
  }
}

/// The dot-matrix motif Nothing uses as a surface texture. Purely decorative.
class NdDotGrid extends StatelessWidget {
  const NdDotGrid({
    super.key,
    required this.color,
    this.columns = 5,
    this.rows = 5,
    this.dotSize = 2,
    this.spacing = 6,
  });

  final Color color;
  final int columns;
  final int rows;
  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) SizedBox(height: spacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: spacing),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
