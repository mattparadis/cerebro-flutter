import 'package:flutter_test/flutter_test.dart';
import 'package:ui_map/src/diff.dart';

Map<String, Object?> _screen(
  String id, {
  String png = 'a',
  String sem = 'a',
  String status = 'ok',
  int exceptions = 0,
  int small = 0,
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
      'tappables_below_min': List.filled(small, {'label': 'x'}),
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
    expect(regress.describe(), contains('layout exceptions 0 → 1'));
    expect(regress.describe(), contains('small tap targets 0 → 2'));
    expect(diff.changed[1].describe(), 'semantics only (labels/actions)');
    expect(diff.changed[2].describe(), 'visual only (pixels)');

    final md = diff.renderMarkdown();
    expect(md, contains('## Changed'));
    expect(md, contains('## Added'));
    expect(md, contains('## Removed'));
    expect(md, contains('`/regress` · light'));
    expect(diff.toJson()['summary'], {'added': 1, 'removed': 1, 'changed': 3, 'unchanged': 1});
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
