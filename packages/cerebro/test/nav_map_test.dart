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
}
