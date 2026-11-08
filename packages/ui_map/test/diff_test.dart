import 'package:flutter_test/flutter_test.dart';
import 'package:ui_map/src/diff.dart';

Map<String, Object?> _screen(
  String id, {
  String png = 'a',
  String sem = 'a',
  String status = 'ok',
  int exceptions = 0,
  int small = 0,
  List<Map<String, Object?>>? smallTargets,
  List<Map<String, Object?>> lowContrast = const [],
  int? measured,
}) =>
    {
      'id': id,
      'location': '/${id.split('__').first}',
      'theme': 'light',
      'text_scale': 1.0,
      'status': status,
      'png': 'screens/$id.png',
      'sha256_png': png,
      'sha256_semantics': sem,
      'exceptions': List.filled(exceptions, 'overflow'),
      'tappables_below_min': smallTargets ?? List.filled(small, {'label': 'x', 'width': 32, 'height': 32}),
      'low_contrast': lowContrast,
      if (measured != null) 'contrast_coverage': {'measured': measured},
    };

void main() {
  test('detects added, removed, visual, semantics and regressions', () {
    final baseline = {
      'generated_at': 't0',
      'screens': [
        _screen('same__phone__light__android'),
        _screen('visual__phone__light__android'),
        _screen('sem__phone__light__android'),
        _screen('gone__phone__light__android'),
        _screen('regress__phone__light__android'),
      ],
    };
    final current = {
      'generated_at': 't1',
      'screens': [
        _screen('same__phone__light__android'),
        _screen('visual__phone__light__android', png: 'b'),
        _screen('sem__phone__light__android', sem: 'b'),
        _screen('new__phone__light__android'),
        _screen('regress__phone__light__android', png: 'b', sem: 'b', exceptions: 1, small: 2),
      ],
    };
    final diff = CaptureDiff.compare(baseline, current);
    expect(diff.hasChanges, isTrue);
    expect(diff.unchanged, 1);
    expect(diff.added.map((s) => s['id']), ['new__phone__light__android']);
    expect(diff.removed.map((s) => s['id']), ['gone__phone__light__android']);
    expect(diff.changed.map((c) => c.id), [
      'regress__phone__light__android', // regressions first
      'sem__phone__light__android',
      'visual__phone__light__android',
    ]);
    final regress = diff.changed.first;
    expect(regress.isRegression, isTrue);
    expect(regress.newFindings, containsAll(['exception "overflow"', 'small target "x" 32×32']));
    expect(diff.changed[1].describe(), 'semantics only (labels/actions)');
    expect(diff.changed[2].describe(), 'visual only (pixels)');

    final md = diff.renderMarkdown();
    expect(md, contains('## Changed'));
    expect(md, contains('## Added'));
    expect(md, contains('## Removed'));
    expect(md, contains('`/regress` · light'));
    expect(diff.toJson()['summary'], {'added': 1, 'removed': 1, 'changed': 3, 'unchanged': 1});
  });

  test('identity, not count: a fixed defect plus a new one is a regression (review item 10)', () {
    final baseline = {
      'generated_at': 't0',
      'screens': [
        _screen('s__phone__light__android', png: 'a', smallTargets: [
          {'label': 'Edit', 'width': 32, 'height': 32},
        ], lowContrast: [
          {'text': 'Caption', 'ratio': 1.7},
        ], measured: 20),
      ],
    };
    final current = {
      'generated_at': 't1',
      'screens': [
        _screen('s__phone__light__android', png: 'b', smallTargets: [
          {'label': 'Share', 'width': 40, 'height': 40}, // Edit fixed, Share new: same count
        ], lowContrast: [
          {'text': 'Caption', 'ratio': 1.2}, // same text, worse ratio
        ], measured: 12), // fewer texts measured
      ],
    };
    final c = CaptureDiff.compare(baseline, current).changed.single;
    expect(c.isRegression, isTrue);
    expect(c.newFindings, containsAll(['small target "Share" 40×40', 'contrast "Caption" 1.20:1']));
    expect(c.fixedFindings, containsAll(['small target "Edit" 32×32', 'contrast "Caption" 1.70:1']));
    expect(c.coverageLoss, ['contrast measured 20 → 12 texts']);
    expect(c.hasCoverageLoss, isTrue);
    final md = CaptureDiff.compare(baseline, current).renderMarkdown();
    expect(md, contains('**regression**'));
    expect(md, contains('1 regressions, 1 with coverage loss'));
  });

  test('a pure improvement is not a regression', () {
    final baseline = {
      'screens': [
        _screen('s__phone__light__android', smallTargets: [
          {'label': 'Edit', 'width': 32, 'height': 32},
        ]),
      ],
    };
    final current = {
      'screens': [_screen('s__phone__light__android', png: 'b', smallTargets: [])],
    };
    final c = CaptureDiff.compare(baseline, current).changed.single;
    expect(c.isRegression, isFalse);
    expect(c.fixedFindings, ['small target "Edit" 32×32']);
  });

  test('no changes renders a one-liner', () {
    final m = {
      'generated_at': 't',
      'screens': [_screen('a__phone__light__android')],
    };
    final diff = CaptureDiff.compare(m, m);
    expect(diff.hasChanges, isFalse);
    expect(diff.renderMarkdown(), contains('No screen changed.'));
  });
}
