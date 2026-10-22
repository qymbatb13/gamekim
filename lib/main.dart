import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int N = 10;
const bg = Color(0xFF090B0F), navy = Color(0xFF101B2D), burg = Color(0xFF591C32);
const forest = Color(0xFF173B30), charcoal = Color(0xFF171A21);
const gold = Color(0xFFB89A62), beige = Color(0xFFD7C7AA), grayC = Color(0xFFB8BDC7);
const blockColors = [Color(0xFF1D3252), Color(0xFF6A2540), Color(0xFF1F4F3F), Color(0xFF4B3629)];

final List<List<(int, int)>> shapes = <List<String>>[
  ['#'], ['##'], ['#', '#'], ['###'], ['#', '#', '#'], ['####'], ['#', '#', '#', '#'],
  ['#####'], ['#', '#', '#', '#', '#'], ['##', '##'], ['###', '###', '###'], ['###', '###'],
  ['##', '##', '##'], ['#.', '#.', '##'], ['.#', '.#', '##'], ['###', '#..'], ['###', '..#'],
  ['#..', '###'], ['..#', '###'], ['#.', '##'], ['##', '#.'], ['##', '.#'], ['.#', '##'],
  ['###', '.#.'], ['.#.', '###'], ['#.', '##', '#.'], ['.#', '##', '.#'], ['##.', '.##'],
  ['.##', '##.'], ['.#', '##', '#.'], ['#.', '##', '.#'],
].map((s) {
  final out = <(int, int)>[];
  for (var r = 0; r < s.length; r++) {
    for (var c = 0; c < s[r].length; c++) {
      if (s[r][c] == '#') out.add((r, c));
    }
  }
  return out;
}).toList();

class Piece {
  final List<(int, int)> cells;
  final int color;
  final List<int> ph;
  Piece(this.cells, this.color, this.ph);
  int get h => cells.map((e) => e.$1).reduce(max) + 1;
  int get w => cells.map((e) => e.$2).reduce(max) + 1;
}

final rng = Random();
List<ImageProvider> photos = [];
List<int> bag = [];
late SharedPreferences prefs;
int best = 0;
bool vibrate = true, anim = true;

int nextPh() {
  if (bag.isEmpty) {
    bag = List.generate(max(photos.length, 1), (i) => i)..shuffle(rng);
  }
  return bag.removeLast();
}

Piece genPiece() {
  final cells = shapes[rng.nextInt(shapes.length)];
  return Piece(cells, 1 + rng.nextInt(4), cells.map((_) => nextPh()).toList());
}

Future<void> loadPhotos() async {
  try {
    final m = await AssetManifest.loadFromAssetBundle(rootBundle);
    final list = m
        .listAssets()
        .where((a) => a.startsWith('assets/photos/') && RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(a))
        .toList()
      ..sort();
    photos = list.map((a) => ResizeImage(AssetImage(a), width: 160) as ImageProvider).toList();
  } catch (_) {
    photos = [];
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  prefs = await SharedPreferences.getInstance();
  best = prefs.getInt('best') ?? 0;
  vibrate = prefs.getBool('vib') ?? true;
  anim = prefs.getBool('anim') ?? true;
  await loadPhotos();
  runApp(const NoirApp());
}

TextStyle ts(double s, Color c, {double ls = 0, FontStyle? st}) =>
    TextStyle(fontSize: s, color: c, letterSpacing: ls, fontStyle: st, fontFamily: 'serif', decoration: TextDecoration.none);

void buzz([int lvl = 0]) {
  if (!vibrate) return;
  if (lvl == 0) {
    HapticFeedback.selectionClick();
  } else if (lvl == 1) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.mediumImpact();
  }
}

Widget btn(String t, VoidCallback f, {bool primary = false, Color? c}) => ElevatedButton(
      onPressed: f,
      style: ElevatedButton.styleFrom(
        backgroundColor: c ?? (primary ? burg : charcoal),
        foregroundColor: beige,
        side: BorderSide(color: gold.withOpacity(.45)),
        padding: EdgeInsets.symmetric(horizontal: primary ? 56 : 18, vertical: primary ? 18 : 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(t.toUpperCase(), style: ts(primary ? 17 : 12, beige, ls: 2)),
    );

Widget blockCell(int color, int ph, double size) {
  final c = blockColors[color - 1];
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(size * .2),
      border: Border.all(color: beige.withOpacity(.28)),
      image: photos.isEmpty
          ? null
          : DecorationImage(
              image: photos[ph % photos.length],
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(c.withOpacity(.4), BlendMode.srcOver)),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
    ),
  );
}

Widget pieceWidget(Piece p, double s) => SizedBox(
      width: p.w * (s + 3) - 3,
      height: p.h * (s + 3) - 3,
      child: Stack(children: [
        for (var j = 0; j < p.cells.length; j++)
          Positioned(left: p.cells[j].$2 * (s + 3), top: p.cells[j].$1 * (s + 3), child: blockCell(p.color, p.ph[j], s)),
      ]),
    );

void showSettingsDialog(BuildContext ctx, {VoidCallback? onRestart, VoidCallback? onMenu}) {
  showDialog(
    context: ctx,
    builder: (dc) => StatefulBuilder(builder: (dc, setS) {
      Widget tog(String t, bool v, void Function(bool) f) => SwitchListTile(
            title: Text(t, style: ts(16, beige)),
            value: v,
            activeColor: gold,
            onChanged: (x) => setS(() => f(x)),
          );
      return Dialog(
        backgroundColor: charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: gold.withOpacity(.45))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 10, children: [
            Text('SETTINGS', style: ts(20, gold, ls: 4)),
            tog('Vibration', vibrate, (x) { vibrate = x; prefs.setBool('vib', x); }),
            tog('Animations', anim, (x) { anim = x; prefs.setBool('anim', x); }),
            if (onRestart != null) btn('Restart game', () { Navigator.pop(dc); onRestart(); }),
            if (onMenu != null) btn('Main menu', () { Navigator.pop(dc); onMenu(); }),
            btn('Close', () => Navigator.pop(dc), c: forest),
          ]),
        ),
      );
    }),
  );
}

class NoirApp extends StatelessWidget {
  const NoirApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Noir Blocks',
        theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg, fontFamily: 'serif'),
        home: const Root(),
      );
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool playing = false;
  int gameKey = 0;
  @override
  Widget build(BuildContext context) => playing
      ? GamePage(key: ValueKey(gameKey), onMenu: () => setState(() => playing = false))
      : MenuPage(onPlay: () => setState(() { playing = true; gameKey++; }));
}

class MenuPage extends StatelessWidget {
  final VoidCallback onPlay;
  const MenuPage({super.key, required this.onPlay});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1), radius: 1.3, colors: [navy, bg])),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, spacing: 20, children: [
                  Transform.rotate(
                    angle: -.1,
                    child: SizedBox(width: 97, height: 97, child: Wrap(spacing: 5, runSpacing: 5, children: [for (var j = 0; j < 4; j++) blockCell(j + 1, j, 46)])),
                  ),
                  FittedBox(
                    child: Text.rich(TextSpan(text: 'NOIR ', style: ts(32, beige, ls: 5), children: [TextSpan(text: 'BLOCKS', style: ts(32, gold, ls: 5))])),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 10),
                    decoration: BoxDecoration(color: charcoal.withOpacity(.7), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withOpacity(.4))),
                    child: Column(children: [Text('BEST SCORE', style: ts(11, grayC, ls: 3)), Text('$best', style: ts(30, gold))]),
                  ),
                  btn('Play', onPlay, primary: true),
                  btn('Settings', () => showSettingsDialog(context)),
                  Text(
                    'dear mom & dad ♡\nI made this little game with love,\nYou are my favorite couple, forever.\nwith love, your daughter — Kymbat ♡',
                    textAlign: TextAlign.center,
                    style: ts(15, beige, st: FontStyle.italic).copyWith(height: 1.6),
                  ),
                  Text('2026 · a memory made with love', style: ts(12, gold, ls: 2)),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _Pop {
  final int id;
  final String text;
  _Pop(this.id, this.text);
}

class GamePage extends StatefulWidget {
  final VoidCallback onMenu;
  const GamePage({super.key, required this.onMenu});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late List<List<int>> board, pb;
  late List<Piece?> pieces;
  int score = 0, prevBest = 0, popId = 0;
  bool over = false, newBest = false;
  int? dragI;
  Offset dragPos = Offset.zero;
  Set<int> okCells = {}, badCells = {};
  (int, int)? target;
  final boardKey = GlobalKey(), stackKey = GlobalKey();
  double cs = 30;
  final Map<int, (int, int)> ghost = {};
  final List<_Pop> pops = [];

  @override
  void initState() {
    super.initState();
    newGame();
  }

  void newGame() {
    board = List.generate(N, (_) => List.filled(N, 0));
    pb = List.generate(N, (_) => List.filled(N, 0));
    pieces = <Piece?>[genPiece(), genPiece(), genPiece()];
    score = 0;
    over = false;
    newBest = false;
    prevBest = best;
    dragI = null;
    okCells = {};
    badCells = {};
    ghost.clear();
  }

  bool canPlace(Piece p, int r0, int c0) {
    for (final (r, c) in p.cells) {
      final R = r0 + r, C = c0 + c;
      if (R < 0 || C < 0 || R >= N || C >= N || board[R][C] != 0) return false;
    }
    return true;
  }

  bool canAny() {
    for (final p in pieces) {
      if (p == null) continue;
      for (var r = 0; r < N; r++) {
        for (var c = 0; c < N; c++) {
          if (canPlace(p, r, c)) return true;
        }
      }
    }
    return false;
  }

  void startDrag(int i, Offset g) {
    dragI = i;
    buzz();
    updateDrag(g);
  }

  void updateDrag(Offset g) {
    if (dragI == null || pieces[dragI!] == null) return;
    final p = pieces[dragI!]!;
    final step = cs + 3;
    final w = p.w * step - 3, h = p.h * step - 3;
    final left = g.dx - w / 2, top = g.dy - h - 34;
    final bb = boardKey.currentContext?.findRenderObject() as RenderBox?;
    final ok = <int>{}, bad = <int>{};
    (int, int)? t;
    if (bb != null) {
      final o = bb.localToGlobal(Offset.zero);
      final col = ((left - (o.dx + 9)) / step).round(), row = ((top - (o.dy + 9)) / step).round();
      final can = canPlace(p, row, col);
      for (final (r, c) in p.cells) {
        final R = row + r, C = col + c;
        if (R >= 0 && C >= 0 && R < N && C < N) (can ? ok : bad).add(R * N + C);
      }
      if (can) t = (row, col);
    }
    setState(() {
      dragPos = Offset(left, top);
      okCells = ok;
      badCells = bad;
      target = t;
    });
  }

  void endDrag() {
    if (dragI == null) return;
    final i = dragI!;
    final t = target;
    setState(() {
      dragI = null;
      okCells = {};
      badCells = {};
      target = null;
    });
    if (t != null) place(i, t.$1, t.$2);
  }

  void place(int i, int r0, int c0) {
    final p = pieces[i]!;
    for (var j = 0; j < p.cells.length; j++) {
      final (r, c) = p.cells[j];
      board[r0 + r][c0 + c] = p.color;
      pb[r0 + r][c0 + c] = p.ph[j];
    }
    pieces[i] = null;
    var gained = p.cells.length;
    final rows = [for (var r = 0; r < N; r++) if (board[r].every((v) => v != 0)) r];
    final cols = [for (var c = 0; c < N; c++) if (List.generate(N, (r) => board[r][c]).every((v) => v != 0)) c];
    final cells = <int>{};
    for (final r in rows) { for (var c = 0; c < N; c++) cells.add(r * N + c); }
    for (final c in cols) { for (var r = 0; r < N; r++) cells.add(r * N + c); }
    String msg;
    if (cells.isNotEmpty) {
      final lines = rows.length + cols.length;
      final combo = lines > 1 ? (lines - 1) * 20 : 0;
      gained += lines * 10 + combo;
      msg = combo > 0 ? 'COMBO +$gained' : '+$gained';
      final keys = cells.toList();
      if (anim) {
        for (final k in keys) { ghost[k] = (board[k ~/ N][k % N], pb[k ~/ N][k % N]); }
        Future.delayed(const Duration(milliseconds: 480), () {
          if (mounted) setState(() { for (final k in keys) { ghost.remove(k); } });
        });
      }
      for (final k in keys) { board[k ~/ N][k % N] = 0; }
      buzz(2);
    } else {
      msg = '+$gained';
      buzz(1);
    }
    score += gained;
    if (score > best) {
      best = score;
      prefs.setInt('best', best);
    }
    final id = ++popId;
    pops.add(_Pop(id, msg));
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => pops.removeWhere((e) => e.id == id));
    });
    if (pieces.every((e) => e == null)) pieces = <Piece?>[genPiece(), genPiece(), genPiece()];
    setState(() {
      if (!canAny()) {
        over = true;
        newBest = score > prevBest;
        buzz(2);
      }
    });
  }

  Widget cellAt(int k) {
    final r = k ~/ N, c = k % N, v = board[r][c];
    final rad = BorderRadius.circular(cs * .2);
    if (v != 0) {
      final b = blockCell(v, pb[r][c], cs);
      if (!badCells.contains(k)) return b;
      return Stack(children: [b, Container(decoration: BoxDecoration(color: const Color(0x73822340), borderRadius: rad))]);
    }
    if (ghost.containsKey(k)) {
      final g = ghost[k]!;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (ctx, t, _) => Opacity(
          opacity: 1 - t,
          child: Transform.scale(
            scale: 1 - .4 * t,
            child: Container(
              decoration: BoxDecoration(borderRadius: rad, boxShadow: [BoxShadow(color: gold.withOpacity(.8 * (1 - t)), blurRadius: 16)]),
              child: blockCell(g.$1, g.$2, cs),
            ),
          ),
        ),
      );
    }
    final ok = okCells.contains(k), bad = badCells.contains(k);
    return Container(
      decoration: BoxDecoration(
        color: ok ? const Color(0x66287855) : bad ? const Color(0x73822340) : const Color(0xFF0F1218),
        borderRadius: rad,
        border: Border.all(color: ok ? const Color(0x9950AA7D) : const Color(0xFF252A36)),
      ),
    );
  }

  Widget boardWidget(double side) {
    final inner = 10 * cs + 27;
    return Stack(children: [
      Container(
        key: boardKey,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: charcoal,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withOpacity(.3)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: SizedBox(
          width: inner,
          height: inner,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var k = 0; k < N * N; k++)
              Positioned(left: (k % N) * (cs + 3), top: (k ~/ N) * (cs + 3), width: cs, height: cs, child: cellAt(k)),
          ]),
        ),
      ),
      for (final pop in pops)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(pop.id),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                builder: (ctx, t, _) => Opacity(
                  opacity: 1 - t,
                  child: Transform.translate(
                    offset: Offset(0, -70 * t),
                    child: Text(pop.text, style: ts(26, gold).copyWith(fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 8, color: Colors.black)])),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget slot(int i, double tc) {
    final p = pieces[i];
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (p == null || over) ? null : (d) => startDrag(i, d.globalPosition),
          onPanUpdate: (d) => updateDrag(d.globalPosition),
          onPanEnd: (_) => endDrag(),
          onPanCancel: endDrag,
          child: Container(
            height: tc * 5 + 12 + 24,
            decoration: BoxDecoration(color: charcoal.withOpacity(.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withOpacity(.2))),
            child: Center(child: p == null ? null : Opacity(opacity: dragI == i ? .3 : 1, child: pieceWidget(p, tc))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bw = min(MediaQuery.of(context).size.width - 28, 520.0);
    final tc = min((bw - 45) / 10 * .62, 26.0);
    final sb = stackKey.currentContext?.findRenderObject() as RenderBox?;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1), radius: 1.3, colors: [navy, bg])),
        child: SafeArea(
          child: Stack(key: stackKey, children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('NOIR BLOCKS', style: ts(14, gold, ls: 4)),
                      IconButton(
                        icon: const Icon(Icons.settings, color: beige),
                        onPressed: () => showSettingsDialog(context, onRestart: () => setState(newGame), onMenu: widget.onMenu),
                      ),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SCORE', style: ts(11, grayC, ls: 3)), Text('$score', style: ts(34, beige))]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('BEST', style: ts(11, grayC, ls: 3)), Text('$best', style: ts(22, gold))]),
                    ]),
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(builder: (ctx, cons) {
                          final side = min(cons.maxWidth, cons.maxHeight);
                          cs = (side - 18 - 27) / 10;
                          return SizedBox(width: side, height: side, child: Center(child: boardWidget(side)));
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [for (var i = 0; i < 3; i++) slot(i, tc)]),
                    const SizedBox(height: 8),
                    Text('Drag blocks onto the board', style: ts(12, grayC, ls: 1.5)),
                  ]),
                ),
              ),
            ),
            if (dragI != null && pieces[dragI!] != null)
              Positioned(
                left: (sb?.globalToLocal(dragPos) ?? dragPos).dx,
                top: (sb?.globalToLocal(dragPos) ?? dragPos).dy,
                child: IgnorePointer(child: Transform.scale(scale: 1.06, child: pieceWidget(pieces[dragI!]!, cs))),
              ),
            if (over)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 350),
                  builder: (ctx, t, child) => Opacity(opacity: t, child: child),
                  child: Container(
                    color: const Color(0xC7050609),
                    child: Center(
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: charcoal, borderRadius: BorderRadius.circular(20), border: Border.all(color: gold.withOpacity(.45))),
                        child: Column(mainAxisSize: MainAxisSize.min, spacing: 10, children: [
                          Text('GAME OVER', style: ts(22, gold, ls: 4)),
                          Text('FINAL SCORE', style: ts(11, grayC, ls: 3)),
                          Text('$score', style: ts(34, beige)),
                          if (newBest) Text('★ NEW BEST SCORE ★', style: ts(14, gold, ls: 2)),
                          Text('BEST $best', style: ts(14, grayC, ls: 2)),
                          btn('Play again', () => setState(newGame), primary: true),
                          btn('Main menu', widget.onMenu),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
