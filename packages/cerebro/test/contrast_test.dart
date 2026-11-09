import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cerebro/src/contrast.dart';

Uint8List _image(int w, int h, int bg, {int? fg, int fgEvery = 4}) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = (fg != null && x % fgEvery == 0 && y % 2 == 0) ? fg : bg;
      final i = (y * w + x) * 4;
      px[i] = (c >> 16) & 0xFF;
      px[i + 1] = (c >> 8) & 0xFF;
      px[i + 2] = c & 0xFF;
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  test('WCAG ratios match known values', () {
    expect(contrastRatio(0x000000, 0xFFFFFF), closeTo(21, 0.01));
    expect(contrastRatio(0xFFFFFF, 0xFFFFFF), closeTo(1, 0.001));
    expect(contrastRatio(0xBDBDBD, 0xFFFFFF), closeTo(1.88, 0.02));
    expect(contrastRatio(0x767676, 0xFFFFFF), closeTo(4.54, 0.05));
  });

  test('estimates fg/bg inside a rect', () {
    final img = _image(40, 20, 0xFFFFFF, fg: 0xBDBDBD);
    final s = estimateContrast(img, 40, 20, left: 0, top: 0, width: 40, height: 20)!;
    expect(s.bgHex, '#FFFFFF');
    expect(s.fgHex, '#BDBDBD');
    expect(s.ratio, closeTo(1.88, 0.02));
  });

  test('returns null for flat or tiny rects', () {
    final flat = _image(10, 10, 0x112233);
    expect(estimateContrast(flat, 10, 10, left: 0, top: 0, width: 10, height: 10), isNull);
    expect(estimateContrast(flat, 10, 10, left: 0, top: 0, width: 1, height: 1), isNull);
  });

  test('samples the background given a known foreground', () {
    final img = _image(40, 20, 0xFFFFFF, fg: 0x222222);
    final bg = sampleBackground(img, 40, 20, left: 0, top: 0, width: 40, height: 20, foreground: 0x222222);
    expect(bg, 0xFFFFFF);
    expect(sampleBackground(img, 40, 20, left: 0, top: 0, width: 40, height: 20, foreground: 0xFFFFFF), 0x222222);
  });

  test('near-white text on white is measured, not skipped (review item 4)', () {
    final img = _image(40, 20, 0xFFFFFF, fg: 0xF0F0F0);
    final bg = sampleBackground(img, 40, 20, left: 0, top: 0, width: 40, height: 20, foreground: 0xF0F0F0);
    expect(bg, 0xFFFFFF);
    expect(contrastRatio(0xF0F0F0, bg!), lessThan(1.3));
    // Only text pixels: nothing left to call background.
    final flat = _image(10, 10, 0xF0F0F0);
    expect(sampleBackground(flat, 10, 10, left: 0, top: 0, width: 10, height: 10, foreground: 0xF0F0F0), isNull);
  });

  test('composites alpha and picks the AA threshold', () {
    expect(compositeOver(0x80000000, 0xFFFFFF), closeTo(0x808080, 0x010101));
    expect(compositeOver(0xFF123456, 0xFFFFFF), 0x123456);
    expect(requiredContrast(fontSize: 14, bold: false), 4.5);
    expect(requiredContrast(fontSize: 18, bold: false), 3.0);
    expect(requiredContrast(fontSize: 14, bold: true), 3.0);
  });

  test('ignores near-background anti-aliasing colours', () {
    // fg is only slightly different from bg: below minDistance → null
    final img = _image(40, 20, 0xFFFFFF, fg: 0xF0F0F0);
    expect(estimateContrast(img, 40, 20, left: 0, top: 0, width: 40, height: 20), isNull);
  });

  test('paintedFraction is ~0 for a flat rect and >0 once glyph pixels are present', () {
    const w = 40, h = 20;
    final rgba = Uint8List(w * h * 4);
    void fill(int x0, int y0, int x1, int y1, int rgb) {
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          rgba[i] = (rgb >> 16) & 0xFF;
          rgba[i + 1] = (rgb >> 8) & 0xFF;
          rgba[i + 2] = rgb & 0xFF;
          rgba[i + 3] = 255;
        }
      }
    }
    fill(0, 0, w, h, 0xFFFFFF); // the bar covering the text
    final covered = paintedFraction(rgba, w, h, left: 0, top: 0, width: w, height: h, foreground: 0x212121, background: 0xFFFFFF);
    expect(covered, 0);
    fill(4, 6, 24, 8, 0x212121); // a stroke of dark text
    final visible = paintedFraction(rgba, w, h, left: 0, top: 0, width: w, height: h, foreground: 0x212121, background: 0xFFFFFF);
    expect(visible, greaterThan(0.03));
    fill(0, 0, w, h, 0xFFFFFF);
    fill(4, 6, 24, 8, 0xA9A9A9); // the same text at 38% opacity still counts as painted
    final faded = paintedFraction(rgba, w, h, left: 0, top: 0, width: w, height: h, foreground: 0x212121, background: 0xFFFFFF);
    expect(faded, greaterThan(0.03));
  });
}
