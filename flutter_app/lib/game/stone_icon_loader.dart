import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// stone icon PNG — 체커보드 배경 제거 후 돌 영역만 잘라서 로드합니다.
class StoneIconLoader {
  StoneIconLoader._();

  static const assetPath = 'assets/icons/stone_icon.png';

  static ui.Image? _cached;

  static Future<ui.Image> load() async {
    if (_cached != null) return _cached!;

    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cached = await _process(frame.image);
    return _cached!;
  }

  static Future<ui.Image> _process(ui.Image source) async {
    final w = source.width;
    final h = source.height;
    final bytes = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return source;

    final px = Uint8List.fromList(bytes.buffer.asUint8List());
    _removeCheckerboard(px, w, h);

    final bounds = _opaqueBounds(px, w, h);
    if (bounds == null) return source;

    final cropped = _crop(px, w, h, bounds);
    final cw = bounds.$3 - bounds.$1 + 1;
    final ch = bounds.$4 - bounds.$2 + 1;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      cropped,
      cw,
      ch,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// 가장자리에서 연결된 체커보드(밝은 무채색) 픽셀만 투명 처리
  static void _removeCheckerboard(Uint8List px, int w, int h) {
    bool isCheckerBg(int r, int g, int b) {
      final diff = math.max(
        (r - g).abs(),
        math.max((g - b).abs(), (r - b).abs()),
      );
      if (diff > 18) return false;
      final avg = (r + g + b) / 3;
      return avg >= 160;
    }

    final seen = <int>{};
    final queue = Queue<(int, int)>();
    for (final x in [0, w - 1]) {
      for (var y = 0; y < h; y++) {
        queue.add((x, y));
      }
    }
    for (final y in [0, h - 1]) {
      for (var x = 0; x < w; x++) {
        queue.add((x, y));
      }
    }

    while (queue.isNotEmpty) {
      final (x, y) = queue.removeFirst();
      final key = x + y * w;
      if (seen.contains(key) || x < 0 || y < 0 || x >= w || y >= h) continue;
      seen.add(key);

      final i = key * 4;
      if (!isCheckerBg(px[i], px[i + 1], px[i + 2])) continue;

      px[i + 3] = 0;
      queue.add((x + 1, y));
      queue.add((x - 1, y));
      queue.add((x, y + 1));
      queue.add((x, y - 1));
    }
  }

  static (int, int, int, int)? _opaqueBounds(Uint8List px, int w, int h) {
    var minX = w;
    var minY = h;
    var maxX = 0;
    var maxY = 0;
    var found = false;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (px[(x + y * w) * 4 + 3] > 20) {
          found = true;
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x);
          maxY = math.max(maxY, y);
        }
      }
    }

    if (!found) return null;
    return (minX, minY, maxX, maxY);
  }

  static Uint8List _crop(
    Uint8List px,
    int w,
    int h,
    (int, int, int, int) bounds,
  ) {
    final minX = bounds.$1;
    final minY = bounds.$2;
    final maxX = bounds.$3;
    final maxY = bounds.$4;
    final cw = maxX - minX + 1;
    final ch = maxY - minY + 1;
    final out = Uint8List(cw * ch * 4);

    for (var y = 0; y < ch; y++) {
      for (var x = 0; x < cw; x++) {
        final src = ((minY + y) * w + (minX + x)) * 4;
        final dst = (y * cw + x) * 4;
        out[dst] = px[src];
        out[dst + 1] = px[src + 1];
        out[dst + 2] = px[src + 2];
        out[dst + 3] = px[src + 3];
      }
    }
    return out;
  }
}
