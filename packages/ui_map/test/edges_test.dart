import 'package:flutter_test/flutter_test.dart';
import 'package:ui_map/src/edges.dart';

void main() {
  test('classifies taps', () {
    expect(classifyEdge(from: '/a', to: '/a', depthBefore: 1, depthAfter: 1), 'none');
    expect(classifyEdge(from: '/a', to: '/a/b', depthBefore: 1, depthAfter: 2), 'push');
    expect(classifyEdge(from: '/a/b', to: '/a', depthBefore: 2, depthAfter: 1), 'pop');
    expect(classifyEdge(from: '/a', to: '/c', depthBefore: 1, depthAfter: 1), 'go');
    expect(classifyEdge(from: '/a', to: '/a', depthBefore: 1, depthAfter: 1, overlay: 'dialog'), 'overlay');
    expect(classifyEdge(from: '/a', to: '/a', depthBefore: 1, depthAfter: 1, error: 'boom'), 'error');
  });

  test('renders mermaid with push, pop, overlays and dedup', () {
    final md = renderEdgesMermaid([
      {'from': '/notes', 'label': 'New note', 'to': '/notes/new', 'kind': 'push'},
      {'from': '/notes', 'label': 'New note', 'to': '/notes/new', 'kind': 'push'},
      {'from': '/notes/new', 'label': 'Discard', 'to': '/notes', 'kind': 'pop'},
      {'from': '/settings', 'label': 'Delete "all" | now', 'to': '/settings', 'kind': 'overlay', 'overlay': 'dialog'},
      {'from': '/settings', 'label': 'Theme', 'to': '/settings', 'kind': 'none'},
    ]);
    expect(md, startsWith('graph LR'));
    expect('New note'.allMatches(md).length, 1);
    expect(md, contains('==>|New note|'));
    expect(md, contains('-->|Discard|'));
    expect(md, contains("-.->|Delete 'all' / now| o0([\"dialog\"])"));
    expect(md, isNot(contains('Theme')));
  });
}
