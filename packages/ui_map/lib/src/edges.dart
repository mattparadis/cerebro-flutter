/// Classification of what a tap did, derived from the router state before
/// and after the tap plus any overlay that appeared.
class NavEdge {
  const NavEdge({
    required this.from,
    required this.label,
    required this.to,
    required this.kind,
    this.overlay,
    this.error,
    required this.x,
    required this.y,
  });

  final String from;
  final String label;

  /// Location after the tap (equal to [from] when nothing navigated).
  final String to;

  /// `push`, `pop`, `go`, `overlay`, `state_change`, `no_observed_effect`,
  /// `error`. `state_change` = same page, but the semantics tree changed
  /// (filter applied, page scrolled, item expanded, text entered).
  /// `no_observed_effect` = nothing the harness can see changed; it is an
  /// observation, not proof that the control is broken.
  final String kind;

  /// `dialog`, `sheet`, `snackbar`, `menu` when [kind] is `overlay`.
  final String? overlay;
  final String? error;
  final double x;
  final double y;

  Map<String, Object?> toJson() => {
        'from': from,
        'label': label,
        'to': to,
        'kind': kind,
        if (overlay != null) 'overlay': overlay,
        if (error != null) 'error': error,
        'x': x,
        'y': y,
      };
}

/// Pure classification so it can be unit-tested without a router.
String classifyEdge({
  required String from,
  required String to,
  required int depthBefore,
  required int depthAfter,
  String? overlay,
  String? error,
  bool contentChanged = false,
}) {
  if (error != null) return 'error';
  if (overlay != null) return 'overlay';
  // Stack depth first: pushing the same location again is still a push.
  if (depthAfter > depthBefore) return 'push';
  if (depthAfter < depthBefore) return 'pop';
  if (to != from) return 'go';
  return contentChanged ? 'state_change' : 'no_observed_effect';
}

/// Mermaid graph of explored edges: nodes are locations, overlays hang off
/// their screen as dashed edges, dead taps are listed separately.
String renderEdgesMermaid(List<Map<String, Object?>> edges) {
  final ids = <String, String>{};
  String idFor(String loc) => ids.putIfAbsent(loc, () => 'e${ids.length}');
  final b = StringBuffer();
  b.writeln('graph LR');
  final seen = <String>{};
  var overlayCount = 0;
  for (final e in edges) {
    final kind = '${e['kind']}';
    if (kind == 'none' || kind == 'no_observed_effect' || kind == 'state_change' || kind == 'error') continue;
    final from = '${e['from']}', to = '${e['to']}';
    final label = _escape('${e['label']}');
    final a = idFor(from);
    if (kind == 'overlay') {
      final o = 'o${overlayCount++}';
      final key = '$from|$label|${e['overlay']}';
      if (!seen.add(key)) continue;
      b.writeln('  $a["$from"] -.->|$label| $o(["${e['overlay']}"])');
      continue;
    }
    final key = '$from|$label|$to';
    if (!seen.add(key)) continue;
    final z = idFor(to);
    final arrow = kind == 'pop' ? '-->' : '==>';
    b.writeln('  $a["$from"] $arrow|$label| $z["$to"]');
  }
  return b.toString();
}

String _escape(String s) {
  var t = s.replaceAll('"', "'").replaceAll('|', '/').replaceAll('\n', ' ');
  if (t.length > 28) t = '${t.substring(0, 28)}…';
  return t;
}
