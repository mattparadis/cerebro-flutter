import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cerebro/cerebro.dart';

LowContrast _lc(String text, Rect r, {double ratio = 2.5}) => LowContrast(
      text: text,
      ratio: ratio,
      required: 4.5,
      foreground: 0x6E6457,
      background: 0xB2502B,
      fontSize: 12,
      rect: r,
    );

void main() {
  test('text crossed by a FAB is occluded, text inside its own row is kept', () {
    const fab = Tappable(label: 'Sell something', left: 230, top: 600, width: 150, height: 56);
    const row = Tappable(label: 'Row', left: 0, top: 580, width: 393, height: 120);
    final low = [
      _lc('3.1 km away · Pietro', const Rect.fromLTWH(100, 620, 250, 16)),
      _lc('Santo Stefano', const Rect.fromLTWH(100, 500, 120, 16)),
      _lc('ghost', const Rect.fromLTWH(10, 100, 80, 16), ratio: 1.04),
    ];
    final (kept, occluded) = splitOccluded(low, [fab, row], screenArea: 393 * 852);
    expect(kept.map((e) => e.text), ['Santo Stefano']);
    expect(occluded.map((e) => e['text']), ['3.1 km away · Pietro', 'ghost']);
    expect(occluded.first['reason'], contains('Sell something'));
    expect(occluded.last['reason'], contains('implausible'));
  });
}
