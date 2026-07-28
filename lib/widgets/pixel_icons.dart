import 'package:flutter/widgets.dart';

/// This file is auto generated plz don't touch me
class PixelGlyph {
  const PixelGlyph(this.rows);

  final List<String> rows;

  bool lit(int r, int c) => rows[r][c] == 'X';
}

abstract final class Px {
  static const home = PixelGlyph([
    '....X....',
    '...XXX...',
    '..XXXXX..',
    '.XX...XX.',
    'XX.....XX',
    '.X.....X.',
    '.X..XX.X.',
    '.X..XX.X.',
    '.XXXXXXX.',
  ]);

  static const grid = PixelGlyph([
    '.........',
    '.XX.XX.XX',
    '.XX.XX.XX',
    '.........',
    '.XX.XX.XX',
    '.XX.XX.XX',
    '.........',
    '.XX.XX.XX',
    '.XX.XX.XX',
  ]);

  static const book = PixelGlyph([
    '.........',
    '.XXX.XXX.',
    'X...X...X',
    'X...X...X',
    'X...X...X',
    'X...X...X',
    'X...X...X',
    '.XXXXXXX.',
    '.........',
  ]);

  static const calendar = PixelGlyph([
    '..X...X..',
    '.XXXXXXX.',
    '.X.....X.',
    '.XXXXXXX.',
    '.X.X.X.X.',
    '.X.....X.',
    '.X.X.X.X.',
    '.X.....X.',
    '.XXXXXXX.',
  ]);

  static const gear = PixelGlyph([
    '....X....',
    '.X.XXX.X.',
    '..XXXXX..',
    '.XX...XX.',
    'XXX.X.XXX',
    '.XX...XX.',
    '..XXXXX..',
    '.X.XXX.X.',
    '....X....',
  ]);

  static const check = PixelGlyph([
    '.........',
    '........X',
    '.......XX',
    '......XX.',
    '.X...XX..',
    '.XX.XX...',
    '..XXX....',
    '...X.....',
    '.........',
  ]);

  static const circle = PixelGlyph([
    '..XXXXX..',
    '.X.....X.',
    'X.......X',
    'X.......X',
    'X.......X',
    'X.......X',
    'X.......X',
    '.X.....X.',
    '..XXXXX..',
  ]);

  static const circleFill = PixelGlyph([
    '..XXXXX..',
    '.XXXXXXX.',
    'XXXXXXXXX',
    'XXXXXXXXX',
    'XXXXXXXXX',
    'XXXXXXXXX',
    'XXXXXXXXX',
    '.XXXXXXX.',
    '..XXXXX..',
  ]);

  static const plus = PixelGlyph([
    '.........',
    '....X....',
    '....X....',
    '....X....',
    '.XXXXXXX.',
    '....X....',
    '....X....',
    '....X....',
    '.........',
  ]);

  static const x = PixelGlyph([
    '.........',
    '.X.....X.',
    '..X...X..',
    '...X.X...',
    '....X....',
    '...X.X...',
    '..X...X..',
    '.X.....X.',
    '.........',
  ]);

  static const camera = PixelGlyph([
    '.........',
    '..XX.....',
    '.XXXXXXX.',
    '.X.....X.',
    '.X..XX.X.',
    '.X..XX.X.',
    '.X.....X.',
    '.XXXXXXX.',
    '.........',
  ]);

  static const mic = PixelGlyph([
    '...XXX...',
    '...X.X...',
    '...X.X...',
    '...XXX...',
    '.X.XXX.X.',
    '.X.....X.',
    '..XXXXX..',
    '....X....',
    '...XXX...',
  ]);

  static const video = PixelGlyph([
    '.........',
    '.........',
    'XXXXX....',
    'X...X..X.',
    'X...X.XX.',
    'X...X..X.',
    'XXXXX....',
    '.........',
    '.........',
  ]);

  static const textLines = PixelGlyph([
    '.........',
    '.XXXXXXX.',
    '.........',
    '.XXXXX...',
    '.........',
    '.XXXXXXX.',
    '.........',
    '.XXXX....',
    '.........',
  ]);

  static const photo = PixelGlyph([
    '.XXXXXXX.',
    '.X.....X.',
    '.X.X...X.',
    '.X.....X.',
    '.X..X..X.',
    '.X.XXX.X.',
    '.XXXXXXX.',
    '.........',
    '.........',
  ]);

  static const play = PixelGlyph([
    '.........',
    '..X......',
    '..XX.....',
    '..XXXX...',
    '..XXXXXX.',
    '..XXXX...',
    '..XX.....',
    '..X......',
    '.........',
  ]);

  static const pause = PixelGlyph([
    '.........',
    '..XX.XX..',
    '..XX.XX..',
    '..XX.XX..',
    '..XX.XX..',
    '..XX.XX..',
    '..XX.XX..',
    '..XX.XX..',
    '.........',
  ]);

  static const stop = PixelGlyph([
    '.........',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.........',
  ]);

  static const forward = PixelGlyph([
    '.........',
    '.X...X...',
    '.XX..XX..',
    '.XXX.XXX.',
    '.XXX.XXXX',
    '.XXX.XXX.',
    '.XX..XX..',
    '.X...X...',
    '.........',
  ]);

  static const bell = PixelGlyph([
    '....X....',
    '...XXX...',
    '..XXXXX..',
    '..XXXXX..',
    '..XXXXX..',
    '.XXXXXXX.',
    '.........',
    '....X....',
    '.........',
  ]);

  static const lock = PixelGlyph([
    '..XXXXX..',
    '..X...X..',
    '..X...X..',
    '.XXXXXXX.',
    '.X.....X.',
    '.X..X..X.',
    '.X..X..X.',
    '.X.....X.',
    '.XXXXXXX.',
  ]);

  static const flame = PixelGlyph([
    '....X....',
    '...XX....',
    '...XXX...',
    '..XXXX...',
    '..XXXXX..',
    '.XXX.XX..',
    '.XX..XXX.',
    '..XXXXX..',
    '...XXX...',
  ]);

  static const left = PixelGlyph([
    '.........',
    '.....X...',
    '....XX...',
    '...XX....',
    '..XX.....',
    '...XX....',
    '....XX...',
    '.....X...',
    '.........',
  ]);

  static const right = PixelGlyph([
    '.........',
    '...X.....',
    '...XX....',
    '....XX...',
    '.....XX..',
    '....XX...',
    '...XX....',
    '...X.....',
    '.........',
  ]);

  static const up = PixelGlyph([
    '.........',
    '.........',
    '....X....',
    '...XXX...',
    '..XX.XX..',
    '.XX...XX.',
    '.X.....X.',
    '.........',
    '.........',
  ]);

  static const down = PixelGlyph([
    '.........',
    '.........',
    '.X.....X.',
    '.XX...XX.',
    '..XX.XX..',
    '...XXX...',
    '....X....',
    '.........',
    '.........',
  ]);

  static const trash = PixelGlyph([
    '...XXX...',
    '.XXXXXXX.',
    '.........',
    '..XXXXX..',
    '..X.X.X..',
    '..X.X.X..',
    '..X.X.X..',
    '..X.X.X..',
    '..XXXXX..',
  ]);

  static const pen = PixelGlyph([
    '.........',
    '......XX.',
    '.....X.XX',
    '....X.XX.',
    '...X.XX..',
    '..X.XX...',
    '.XX.X....',
    '.XXXX....',
    '.........',
  ]);

  static const moon = PixelGlyph([
    '...XXXX..',
    '..XX.....',
    '.XX......',
    '.XX......',
    '.XX......',
    '.XX......',
    '..XX.....',
    '...XXXX..',
    '.........',
  ]);

  static const sun = PixelGlyph([
    '....X....',
    '.X..X..X.',
    '..XXXXX..',
    '..X...X..',
    'XXX.X.XXX',
    '..X...X..',
    '..XXXXX..',
    '.X..X..X.',
    '....X....',
  ]);

  static const hourglass = PixelGlyph([
    '.XXXXXXX.',
    '..X...X..',
    '..XX.XX..',
    '...XXX...',
    '....X....',
    '...X.X...',
    '..X...X..',
    '..X.X.X..',
    '.XXXXXXX.',
  ]);

  static const alarm = PixelGlyph([
    'XX.....XX',
    'X.XXXXX.X',
    '.X.....X.',
    'X...X...X',
    'X...X...X',
    'X...XX..X',
    '.X.....X.',
    '..XXXXX..',
    '.X.....X.',
  ]);

  static const block = PixelGlyph([
    '..XXXXX..',
    '.X....XX.',
    'X....XX.X',
    'X...XX..X',
    'X..XX...X',
    'X.XX....X',
    'XXX.....X',
    '.XX....X.',
    '..XXXXX..',
  ]);

  static const chart = PixelGlyph([
    '.........',
    '......XX.',
    '......XX.',
    '...XX.XX.',
    '...XX.XX.',
    'XX.XX.XX.',
    'XX.XX.XX.',
    'XX.XX.XX.',
    '.........',
  ]);

  static const eye = PixelGlyph([
    '.........',
    '.........',
    '...XXX...',
    '.XX...XX.',
    'X...X...X',
    '.XX...XX.',
    '...XXX...',
    '.........',
    '.........',
  ]);

  static const user = PixelGlyph([
    '...XXX...',
    '...XXX...',
    '...XXX...',
    '.........',
    '..XXXXX..',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '.........',
  ]);

  static const export = PixelGlyph([
    '....X....',
    '...XXX...',
    '..XX.XX..',
    '....X....',
    '....X....',
    '....X....',
    'XX.....XX',
    'XXXXXXXXX',
    '.........',
  ]);

  static const note = PixelGlyph([
    '.........',
    '.....XX..',
    '.....X.X.',
    '.....X..X',
    '.....X...',
    '.....X...',
    '...XXX...',
    '..XXXX...',
    '...XX....',
  ]);

  static const star = PixelGlyph([
    '....X....',
    '...XXX...',
    'XXXXXXXXX',
    '.XXXXXXX.',
    '..XXXXX..',
    '.XXX.XXX.',
    '.XX...XX.',
    '.........',
    '.........',
  ]);

  static const heart = PixelGlyph([
    '.........',
    '.XX...XX.',
    'XXXX.XXXX',
    'XXXXXXXXX',
    'XXXXXXXXX',
    '.XXXXXXX.',
    '..XXXXX..',
    '...XXX...',
    '....X....',
  ]);

  static const drop = PixelGlyph([
    '....X....',
    '....X....',
    '...XXX...',
    '..XXXXX..',
    '..XXXXX..',
    '.XXXXXXX.',
    '.XXXXXXX.',
    '..XXXXX..',
    '...XXX...',
  ]);

  static const leaf = PixelGlyph([
    '......XX.',
    '....XXXX.',
    '...XXXXX.',
    '..XXXXX..',
    '.XXXXX...',
    '.XXXX....',
    '.XX......',
    'X........',
    '.........',
  ]);

  static const coffee = PixelGlyph([
    '..X.X....',
    '.........',
    '.XXXXX...',
    '.X...XXX.',
    '.X...X.X.',
    '.X...XXX.',
    '.X...X...',
    '.XXXXX...',
    '.........',
  ]);

  static const code = PixelGlyph([
    '.........',
    '.........',
    '..X...X..',
    '.X.....X.',
    'X.......X',
    '.X.....X.',
    '..X...X..',
    '.........',
    '.........',
  ]);

  static const bolt = PixelGlyph([
    '....XXX..',
    '...XXX...',
    '..XXX....',
    '.XXXXXX..',
    '...XXX...',
    '..XXX....',
    '..XX.....',
    '.XX......',
    '.X.......',
  ]);

  static const dumbbell = PixelGlyph([
    '.........',
    '.........',
    '.X.....X.',
    'XX.....XX',
    'XXXXXXXXX',
    'XX.....XX',
    '.X.....X.',
    '.........',
    '.........',
  ]);

  static const pill = PixelGlyph([
    '.........',
    '.........',
    '..XXXXX..',
    '.XXX.XXX.',
    '.XXX.XXX.',
    '.XXX.XXX.',
    '..XXXXX..',
    '.........',
    '.........',
  ]);

  static const dot = PixelGlyph([
    '.........',
    '.........',
    '.........',
    '...XXX...',
    '...XXX...',
    '...XXX...',
    '.........',
    '.........',
    '.........',
  ]);


  static const habitIcons = <String, PixelGlyph>{
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

  static PixelGlyph habitIcon(String name) => habitIcons[name] ?? flame;
}


class PixelIcon extends StatelessWidget {
  const PixelIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.size = 18,
    this.gap = 0.12,
  });

  final PixelGlyph glyph;
  final Color color;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PixelIconPainter(glyph, color, gap),
    );
  }
}

class _PixelIconPainter extends CustomPainter {
  const _PixelIconPainter(this.glyph, this.color, this.gap);

  final PixelGlyph glyph;
  final Color color;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final inset = cell * gap;
    final paint = Paint()..color = color;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (!glyph.lit(r, c)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            c * cell + inset / 2,
            r * cell + inset / 2,
            cell - inset,
            cell - inset,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelIconPainter old) =>
      old.glyph != glyph || old.color != color || old.gap != gap;
}
