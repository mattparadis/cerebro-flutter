import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cerebro/cerebro.dart';

void main() {
  final screens = <Map<String, Object?>>[
    {'status': 'ok', 'png': 'screens/notes.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/notes', 'route': '/notes', 'device': 'phone'},
    {'status': 'ok', 'png': 'screens/notes_1.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/notes/1', 'route': '/notes/:id', 'device': 'phone'},
    {'status': 'ok', 'png': 'screens/notes_empty.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/notes?state=empty', 'route': '/notes', 'device': 'phone'},
    {'status': 'ok', 'png': 'screens/notes_dark.png', 'theme': 'dark', 'text_scale': 1.0, 'location': '/notes', 'route': '/notes', 'device': 'phone'},
    {'status': 'ok', 'png': 'screens/proto.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/__proto/x', 'route': '/__proto/x', 'device': 'phone'},
  ];
  test('one node per route, light, no variants or prototypes', () {
    final nodes = NavMap.pickNodes(screens);
    expect(nodes.map((n) => n.route), ['/notes', '/notes/:id']);
  });
  test('locations resolve to routes by exact match or pattern', () {
    final nodes = NavMap.pickNodes(screens);
    expect(NavMap.routeFor('/notes?state=error', nodes), '/notes');
    expect(NavMap.routeFor('/notes/42', nodes), '/notes/:id');
    expect(NavMap.routeFor('/nowhere', nodes), isNull);
  });
  test('edges aggregate by route pair and kind, with labels and instant count', () {
    final nodes = NavMap.pickNodes(screens);
    final groups = NavMap.aggregate(nodes, [
      {'from': '/notes', 'to': '/notes/2', 'kind': 'go', 'label': 'Seed order', 'transition': 'instant'},
      {'from': '/notes?state=empty', 'to': '/notes/3', 'kind': 'go', 'label': 'Fence line', 'transition': 'animated'},
      {'from': '/notes/1', 'to': '/notes', 'kind': 'pop', 'label': 'Back'},
      {'from': '/notes', 'to': '/notes', 'kind': 'overlay', 'label': 'Filter', 'overlay': 'sheet'},
      {'from': '/notes', 'to': '/notes', 'kind': 'state_change', 'label': 'ignored'},
    ]);
    expect(groups.length, 3);
    final go = groups.firstWhere((g) => g.kind == 'go');
    expect(go.count, 2);
    expect(go.instant, 1);
    expect(go.labels, ['Seed order', 'Fence line']);
    final dot = NavMap.renderDot(nodes, groups);
    expect(dot, contains('bgcolor="transparent"'));
    expect(dot, contains('"/notes" -> "/notes/:id"'));
    expect(dot, contains('(instant)'));
  });
  test('isolated routes are reported, not drawn; unnamed targets are counted', () {
    final out = Directory.systemTemp.createTempSync('navmap');
    final r = NavMap.write(out.path, screens, [
      {'from': '/notes', 'to': '(unnamed MaterialPageRoute<dynamic>)', 'kind': 'push', 'label': 'Edit'},
      {'from': '/notes', 'to': '/notes', 'kind': 'overlay', 'label': 'Filter', 'overlay': 'sheet'},
    ])!;
    expect(r['unreached'], ['/notes/:id']);
    expect(r['unresolved_targets'], ['(unnamed MaterialPageRoute<dynamic>)']);
    expect(File('${out.path}/map.dot').readAsStringSync(), isNot(contains('/notes/:id')));
  });

  test('unnamed targets resolve by labels fingerprint when exactly one screen matches', () {
    final withFp = <Map<String, Object?>>[
      {'status': 'ok', 'png': 'a.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/home', 'route': '/home', 'device': 'phone', 'fingerprint': 'fp-home'},
      {'status': 'ok', 'png': 'b.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/detail', 'route': '/detail', 'device': 'phone', 'fingerprint': 'fp-detail'},
      {'status': 'ok', 'png': 'c.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/twin', 'route': '/twin', 'device': 'phone', 'fingerprint': 'fp-dup'},
      {'status': 'ok', 'png': 'd.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/twin2', 'route': '/twin2', 'device': 'phone', 'fingerprint': 'fp-dup'},
      {'status': 'ok', 'png': 'e.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/login', 'route': '/login', 'device': 'phone', 'fingerprint': 'fp-login'},
      {'status': 'ok', 'png': 'f.png', 'theme': 'light', 'text_scale': 1.0, 'location': '/account', 'route': '/account', 'device': 'phone', 'fingerprint': 'fp-login', 'redirected_to': '/login'},
    ];
    final nodes = NavMap.pickNodes(withFp);
    final resolved = {'from': '/home', 'to': '(unnamed MaterialPageRoute<dynamic>)', 'kind': 'push', 'label': 'Open', 'to_fingerprint': 'fp-detail'};
    final ambiguous = {'from': '/home', 'to': '(unnamed MaterialPageRoute<dynamic>)', 'kind': 'push', 'label': 'Twin', 'to_fingerprint': 'fp-dup'};
    final unknown = {'from': '/home', 'to': '(unnamed MaterialPageRoute<dynamic>)', 'kind': 'push', 'label': 'New', 'to_fingerprint': 'fp-none'};
    expect(NavMap.targetFor(resolved, nodes), '/detail');
    expect(NavMap.resolvedByFingerprint(resolved, nodes), isTrue);
    expect(NavMap.targetFor(ambiguous, nodes), isNull);
    expect(NavMap.targetFor(unknown, nodes), isNull);
    // A redirected route shows another route's screen: the owner wins the tie.
    final guarded = {'from': '/home', 'to': '(unnamed MaterialPageRoute<dynamic>)', 'kind': 'push', 'label': 'Log in', 'to_fingerprint': 'fp-login'};
    expect(NavMap.targetFor(guarded, nodes), '/login');
    final groups = NavMap.aggregate(nodes, [resolved, ambiguous, unknown]);
    expect(groups.map((g) => '${g.from}>${g.to}'), ['/home>/detail']);
    final dir = Directory.systemTemp.createTempSync('cerebro_navmap_fp');
    try {
      final r = NavMap.write(dir.path, withFp, [resolved, ambiguous, unknown])!;
      expect(r['resolved_by_fingerprint'], 1);
      expect(r['unresolved_targets'], ['(unnamed MaterialPageRoute<dynamic>)']);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
  test('self-loop-only routes go in a dashed cluster chained in a row', () {
    final nodes = NavMap.pickNodes(screens);
    final groups = NavMap.aggregate(nodes, [
      {'from': '/notes', 'to': '/notes', 'kind': 'overlay', 'label': 'Filter', 'overlay': 'sheet'},
      {'from': '/notes/1', 'to': '/notes/1', 'kind': 'error', 'label': 'Retry', 'error': 'boom'},
    ]);
    final dot = NavMap.renderDot(nodes, groups);
    expect(dot, contains('subgraph cluster_self'));
    expect(dot, contains('"/notes" -> "/notes/:id" [style=invis]'));
    final linked = NavMap.renderDot(nodes, NavMap.aggregate(nodes, [
      {'from': '/notes', 'to': '/notes/1', 'kind': 'push', 'label': 'Open'},
    ]));
    expect(linked, isNot(contains('cluster_self')));
  });
}
