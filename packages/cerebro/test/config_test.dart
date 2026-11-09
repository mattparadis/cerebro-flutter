import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cerebro/cerebro.dart';

void main() {
  test('defaults when file is missing', () {
    final c = CerebroConfig.load('/nonexistent/cerebro.yaml');
    expect(c.devices.single.name, 'phone');
    expect(c.themes, ['light', 'dark']);
    expect(c.platforms, ['android']);
    expect(c.settleMs, 600);
    expect(c.exportScale, 2);
    expect(c.minTapSize, 48);
    expect(c.minTapSizeFor('ios'), 44);
    expect(c.minTapSizeFor('windows'), 48);
    expect(c.outDir, '.cerebro');
    expect(c.lintExclude, isNull);
  });

  test('parses yaml', () {
    final dir = Directory.systemTemp.createTempSync('cerebro_cfg');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/cerebro.yaml')..writeAsStringSync('''
devices:
  - { name: small, width: 320, height: 568, dpr: 2, safe_area: { top: 47, bottom: 34 } }
  - { name: tablet, width: 834, height: 1194, dpr: 2 }
themes: [dark]
platforms: [android, ios]
text_scales: [1.0, 1.3]
settle_ms: 1000
export_scale: 1
min_tap_size: { android: 48, ios: 44 }
keyboard_inset: 260
locales: [en, it]
routes:
  "/items/:id": { params: { id: 42 } }
  "/items": { variants: ["?state=empty"] }
  "/debug": { skip: true }
exclude: ["/secret"]
fonts:
  Inter: [assets/fonts/Inter.ttf]
out_dir: build/ui
lint:
  exclude: ["lib/gen/**"]
  rules: { no-safe-area: false }
''');
    final c = CerebroConfig.load(f.path);
    expect(c.devices.map((d) => d.name), ['small', 'tablet']);
    expect(c.devices.first.dpr, 2);
    expect(c.devices.first.safeTop, 47);
    expect(c.devices.first.safeBottom, 34);
    expect(c.devices.last.safeTop, 24);
    expect(c.themes, ['dark']);
    expect(c.platforms, ['android', 'ios']);
    expect(c.textScales, [1.0, 1.3]);
    expect(c.settleMs, 1000);
    expect(c.exportScale, 1);
    expect(c.minTapSize, 48);
    expect(c.minTapSizeFor('ios'), 44);
    expect(c.minTapSizeFor('android'), 48);
    expect(c.keyboardInset, 260);
    expect(c.locales, ['en', 'it']);
    expect(c.routes['/items/:id']!.params, {'id': ['42']});
    expect(c.routes['/items']!.variants, ['?state=empty']);
    expect(c.routes['/debug']!.skip, isTrue);
    expect(c.exclude, ['/secret']);
    expect(c.fonts, {'Inter': ['assets/fonts/Inter.ttf']});
    expect(c.outDir, 'build/ui');
    expect(c.lintExclude, ['lib/gen/**']);
    expect(c.lintRules, {'no-safe-area': false});
    expect(c.toJson()['routes'], isA<Map>());
  });
}
