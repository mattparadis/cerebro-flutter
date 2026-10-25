import 'dart:math' as math;
import 'dart:typed_data';

/// WCAG 2.x contrast helpers over raw RGBA pixel buffers. Pure functions so
/// they can be unit-tested without a Flutter binding.

double _channel(int c) {
  final s = c / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

/// Relative luminance of an 0xRRGGBB colour.
double relativeLuminance(int rgb) {
  final r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
  return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b);
}

/// WCAG contrast ratio between two 0xRRGGBB colours (1..21).
double contrastRatio(int a, int b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

class ContrastSample {
  const ContrastSample({
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.pixels,
  });

  final int foreground;
  final int background;
  final double ratio;
  final int pixels;

  String get fgHex => _hex(foreground);
  String get bgHex => _hex(background);

  static String _hex(int c) => '#${c.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Estimates text/background contrast inside a rectangle of an RGBA image.
///
/// Background = the most frequent colour in the rect. Foreground = the most
/// frequent colour among those at least [minDistance] (in RGB space, 0-441)
/// away from the background, ignoring anti-aliasing blends by quantising
/// channels to 8 levels. Returns null when the rect has a single colour or
/// is too small.
ContrastSample? estimateContrast(
  Uint8List rgba,
  int imageWidth,
  int imageHeight, {
  required int left,
  required int top,
  required int width,
  required int height,
  double minDistance = 60,
}) {
  final x0 = left.clamp(0, imageWidth), y0 = top.clamp(0, imageHeight);
  final x1 = (left + width).clamp(0, imageWidth), y1 = (top + height).clamp(0, imageHeight);
  if (x1 - x0 < 2 || y1 - y0 < 2) return null;
  final counts = <int, int>{};
  final sums = <int, List<int>>{};
  var total = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * imageWidth + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final key = ((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5);
      counts[key] = (counts[key] ?? 0) + 1;
      final s = sums.putIfAbsent(key, () => [0, 0, 0]);
      s[0] += r;
      s[1] += g;
      s[2] += b;
      total++;
    }
  }
  if (counts.length < 2) return null;
  final sorted = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  int avg(int key) {
    final s = sums[key]!, n = counts[key]!;
    return ((s[0] ~/ n) << 16) | ((s[1] ~/ n) << 8) | (s[2] ~/ n);
  }

  final bg = avg(sorted.first);
  int? fg;
  var fgPixels = 0;
  for (final key in sorted.skip(1)) {
    final c = avg(key);
    if (_distance(c, bg) >= minDistance) {
      fg = c;
      fgPixels = counts[key]!;
      break;
    }
  }
  if (fg == null || fgPixels < total * 0.01) return null;
  return ContrastSample(foreground: fg, background: bg, ratio: contrastRatio(fg, bg), pixels: fgPixels);
}

double _distance(int a, int b) {
  final dr = ((a >> 16) & 0xFF) - ((b >> 16) & 0xFF);
  final dg = ((a >> 8) & 0xFF) - ((b >> 8) & 0xFF);
  final db = (a & 0xFF) - (b & 0xFF);
  return math.sqrt((dr * dr + dg * dg + db * db).toDouble());
}

/// Most frequent colour inside the rect that is at least [minDistance]
/// away from [foreground] (the known text colour). Returns null when the
/// rect is too small or every pixel is close to the foreground.
int? sampleBackground(
  Uint8List rgba,
  int imageWidth,
  int imageHeight, {
  required int left,
  required int top,
  required int width,
  required int height,
  required int foreground,
  double minDistance = 60,
}) {
  final x0 = left.clamp(0, imageWidth), y0 = top.clamp(0, imageHeight);
  final x1 = (left + width).clamp(0, imageWidth), y1 = (top + height).clamp(0, imageHeight);
  if (x1 - x0 < 1 || y1 - y0 < 1) return null;
  final counts = <int, int>{};
  final sums = <int, List<int>>{};
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * imageWidth + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final c = (r << 16) | (g << 8) | b;
      if (_distance(c, foreground) < minDistance) continue;
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      counts[key] = (counts[key] ?? 0) + 1;
      final s = sums.putIfAbsent(key, () => [0, 0, 0]);
      s[0] += r;
      s[1] += g;
      s[2] += b;
    }
  }
  if (counts.isEmpty) return null;
  final best = counts.keys.reduce((a, b) => counts[a]! >= counts[b]! ? a : b);
  final s = sums[best]!, n = counts[best]!;
  return ((s[0] ~/ n) << 16) | ((s[1] ~/ n) << 8) | (s[2] ~/ n);
}

/// Composites an ARGB colour with alpha over an opaque 0xRRGGBB background.
int compositeOver(int argb, int background) {
  final a = ((argb >> 24) & 0xFF) / 255.0;
  if (a >= 1) return argb & 0xFFFFFF;
  int mix(int shift) {
    final f = (argb >> shift) & 0xFF, b = (background >> shift) & 0xFF;
    return (f * a + b * (1 - a)).round().clamp(0, 255);
  }

  return (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// WCAG AA minimum: 3.0 for large text (>= 18 pt, or >= 14 pt bold),
/// 4.5 otherwise.
double requiredContrast({required double fontSize, required bool bold}) =>
    fontSize >= 18 || (bold && fontSize >= 14) ? 3.0 : 4.5;
