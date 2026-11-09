import 'dart:io';

import 'package:path/path.dart' as p;

/// Renders the explored navigation graph as a picture: one node per route
/// (its light, 1.0× screenshot as the thumbnail), one arrow per distinct
/// tap result between two routes. Always writes `map.dot`; when Graphviz
/// (`dot`) is on the PATH also writes `map.png` and `map.svg` with a
/// transparent background, so the picture sits on light and dark pages.
class NavMap {
  NavMap._();

  static const _colors = {
    'push': '#2E6BE6',
    'go': '#4C9A6A',
    'pop': '#9AA0AB',
    'overlay': '#D9822B',
    'error': '#D64545',
  };

  /// Returns `{dot, png?, svg?, graphviz, nodes, edges}` with paths relative
  /// to [outDir], or null when there is nothing to draw.
  static Map<String, Object?>? write(
    String outDir,
    List<Map<String, Object?>> screens,
    List<Map<String, Object?>> edges, {
    String theme = 'light',
  }) {
    final navEdges = edges.where((e) => const {'push', 'pop', 'go', 'overlay', 'error'}.contains(e['kind'])).toList();
    if (navEdges.isEmpty) return null;
    final nodes = pickNodes(screens, theme: theme);
    if (nodes.isEmpty) return null;
    final agg = aggregate(nodes, navEdges);
    // Only routes that some tap leads to or from are drawn; the rest would
    // stack into an unreadable column. They are reported instead.
    final connected = <String>{for (final g in agg) ...[g.from, g.to]};
    final drawn = nodes.where((n) => connected.contains(n.route)).toList();
    final unreached = nodes.where((n) => !connected.contains(n.route)).map((n) => n.route).toList();
    final unresolved = <String>{};
    var byFingerprint = 0;
    for (final e in navEdges) {
      if (e['kind'] == 'push' || e['kind'] == 'go') {
        if (targetFor(e, nodes) == null) {
          unresolved.add('${e['to']}');
        } else if (resolvedByFingerprint(e, nodes)) {
          byFingerprint++;
        }
      }
    }
    if (drawn.isEmpty) {
      return {
        'nodes': 0,
        'edges': 0,
        'unreached': unreached,
        'unresolved_targets': unresolved.toList(),
        'resolved_by_fingerprint': byFingerprint,
      };
    }
    final dot = renderDot(drawn, agg);
    final dotPath = p.join(outDir, 'map.dot');
    File(dotPath).writeAsStringSync(dot);
    final out = <String, Object?>{
      'dot': 'map.dot',
      'graphviz': false,
      'nodes': drawn.length,
      'edges': agg.length,
      'unreached': unreached,
      'unresolved_targets': unresolved.toList(),
      'resolved_by_fingerprint': byFingerprint,
    };
    for (final fmt in ['png', 'svg']) {
      try {
        final r = Process.runSync(
          'dot',
          ['-T$fmt', if (fmt == 'png') '-Gdpi=110', 'map.dot', '-o', 'map.$fmt'],
          workingDirectory: outDir,
        );
        if (r.exitCode == 0) {
          out[fmt] = 'map.$fmt';
          out['graphviz'] = true;
        } else {
          out['graphviz_error'] = '${r.stderr}'.trim().split('\n').first;
        }
      } on ProcessException {
        out['graphviz'] = false;
        break;
      }
    }
    return out;
  }

  /// One node per route pattern: the first base capture (no query, no
  /// keyboard, no scenario, text scale 1.0, first device) in [theme].
  static List<NavNode> pickNodes(List<Map<String, Object?>> screens, {String theme = 'light'}) {
    final themes = {for (final s in screens) '${s['theme']}'};
    final useTheme = themes.contains(theme) ? theme : (themes.isEmpty ? theme : themes.first);
    String? device;
    final byRoute = <String, NavNode>{};
    for (final s in screens) {
      if (s['status'] != 'ok' || s['png'] == null) continue;
      if ('${s['theme']}' != useTheme) continue;
      if ((s['text_scale'] as num?) != 1.0) continue;
      if (s['keyboard'] == true || s['scenario'] != null) continue;
      final location = '${s['location']}';
      if (location.contains('?')) continue;
      final route = '${s['route'] ?? location}';
      if (route.startsWith('/__proto')) continue;
      device ??= '${s['device']}';
      if ('${s['device']}' != device) continue;
      byRoute.putIfAbsent(
        route,
        () => NavNode(
          route: route,
          location: location,
          png: '${s['png']}',
          fingerprint: s['fingerprint'] as String?,
          redirected: s['redirected_to'] != null,
        ),
      );
    }
    return byRoute.values.toList();
  }

  /// Resolves a location to a node route: exact location first, then the
  /// most specific route pattern that matches its path.
  static String? routeFor(String location, List<NavNode> nodes) {
    final path = location.split('?').first;
    for (final n in nodes) {
      if (n.location == path) return n.route;
    }
    NavNode? best;
    for (final n in nodes) {
      final pattern = '^${RegExp.escape(n.route).replaceAllMapped(RegExp(r':\\?\w+|\\:(\w+)'), (m) => '[^/]+')}\$';
      final re = RegExp(n.route.replaceAllMapped(RegExp(r':(\w+)'), (m) => '[^/]+').replaceAll('/', r'\/'));
      if (RegExp('^${re.pattern}\$').hasMatch(path)) {
        if (best == null || n.route.length > best.route.length) best = n;
      }
      assert(pattern.isNotEmpty);
    }
    return best?.route;
  }

  /// Resolves an edge's target: by location first, then (for unnamed
  /// Navigator routes) by the labels fingerprint of the screen after the
  /// tap, when exactly one captured screen reads the same.
  static String? targetFor(Map<String, Object?> e, List<NavNode> nodes) {
    final byLocation = routeFor('${e['to']}', nodes);
    if (byLocation != null) return byLocation;
    final fp = e['to_fingerprint'];
    if (fp == null) return null;
    var matches = nodes.where((n) => n.fingerprint == fp).toList();
    // Routes that redirected show someone else's screen (an auth guard
    // sending /account to the login): the route that owns the screen is the
    // one that did not redirect.
    if (matches.length > 1) matches = matches.where((n) => !n.redirected).toList();
    return matches.length == 1 ? matches.first.route : null;
  }

  /// True when [targetFor] needed the fingerprint.
  static bool resolvedByFingerprint(Map<String, Object?> e, List<NavNode> nodes) =>
      routeFor('${e['to']}', nodes) == null && targetFor(e, nodes) != null;

  /// Groups edges by (from route, to route, kind); keeps up to two labels,
  /// the count and how many of them were instant.
  static List<NavEdgeGroup> aggregate(List<NavNode> nodes, List<Map<String, Object?>> edges) {
    final groups = <String, NavEdgeGroup>{};
    for (final e in edges) {
      final kind = '${e['kind']}';
      final from = routeFor('${e['from']}', nodes);
      if (from == null) continue;
      String? to;
      if (kind == 'overlay' || kind == 'error') {
        to = targetFor(e, nodes) ?? from;
      } else {
        to = targetFor(e, nodes);
        if (to == null || to == from) continue;
      }
      final key = '$from|$to|$kind';
      final g = groups.putIfAbsent(key, () => NavEdgeGroup(from: from, to: to!, kind: kind));
      g.count++;
      final label = '${e['label']}'.split(' / ').first.trim();
      if (label.isNotEmpty && g.labels.length < 2 && !g.labels.contains(label)) g.labels.add(label);
      if (e['transition'] == 'instant') g.instant++;
      if (kind == 'error' && e['error'] != null && g.error == null) g.error = '${e['error']}';
    }
    return groups.values.toList();
  }

  static String renderDot(List<NavNode> nodes, List<NavEdgeGroup> groups) {
    String esc(String s) => s.replaceAll('"', '\\"');
    String html(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    final b = StringBuffer()
      ..writeln('digraph cerebro {')
      ..writeln('  graph [rankdir=LR, bgcolor="transparent", pad=0.3, nodesep=0.45, ranksep=1.0, fontname="Helvetica"];')
      ..writeln('  node [shape=none, margin=0, fontname="Helvetica", fontsize=12, fontcolor="#6B7280"];')
      ..writeln('  edge [fontname="Helvetica", fontsize=9, arrowsize=0.7, penwidth=1.2];');
    String nodeDecl(NavNode n) => '"${esc(n.route)}" [label=<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0" CELLPADDING="2">'
        '<TR><TD WIDTH="112" HEIGHT="242" FIXEDSIZE="TRUE"><IMG SCALE="TRUE" SRC="${html(n.png)}"/></TD></TR>'
        '<TR><TD>${html(n.route)}</TD></TR></TABLE>>];';
    // Routes whose only edges point at themselves (a dialog, a retry) have
    // no rank of their own and would pile up in the first column; chain
    // them with invisible edges so they sit in one row, boxed apart.
    final linked = <String>{for (final g in groups) if (g.from != g.to) ...[g.from, g.to]};
    final selfOnly = nodes.where((n) => !linked.contains(n.route)).toList();
    final main = nodes.where((n) => linked.contains(n.route)).toList();
    for (final n in main) {
      b.writeln('  ${nodeDecl(n)}');
    }
    if (selfOnly.isNotEmpty) {
      b.writeln('  subgraph cluster_self {');
      b.writeln('    label="overlays only (dialogs, retries: no route change)"; labeljust=l; fontsize=10; fontcolor="#9AA0AB"; color="#9AA0AB"; style=dashed;');
      for (final n in selfOnly) {
        b.writeln('    ${nodeDecl(n)}');
      }
      if (selfOnly.length > 1) {
        b.writeln('    ${selfOnly.map((n) => '"${esc(n.route)}"').join(' -> ')} [style=invis];');
      }
      b.writeln('  }');
    }
    for (final g in groups) {
      final color = _colors[g.kind] ?? '#6B7280';
      var label = g.labels.join('\\n');
      if (g.kind == 'error') label = '⚠ $label';
      if (g.instant > 0 && g.kind != 'overlay') label = '$label${label.isEmpty ? '' : ' '}(instant)';
      final style = switch (g.kind) {
        'pop' => 'dashed',
        'overlay' => 'dotted',
        _ => 'solid',
      };
      final penwidth = switch (g.kind) {
        'push' || 'error' => '2.0',
        'go' => '1.0',
        _ => '1.2',
      };
      b.writeln('  "${esc(g.from)}" -> "${esc(g.to)}" [label="${esc(label)}", color="$color", fontcolor="$color", style=$style, penwidth=$penwidth];');
    }
    b.writeln('}');
    return b.toString();
  }
}

class NavNode {
  NavNode({required this.route, required this.location, required this.png, this.fingerprint, this.redirected = false});
  final String route;
  final String location;
  final String png;

  /// The capture of this route ended on another location (auth guard,
  /// redirect): its screenshot shows that other screen.
  final bool redirected;

  /// Labels fingerprint of the captured screen (see `fingerprint` in
  /// results), used to resolve taps whose target has no location.
  final String? fingerprint;
}

class NavEdgeGroup {
  NavEdgeGroup({required this.from, required this.to, required this.kind});
  final String from;
  final String to;
  final String kind;
  final List<String> labels = [];
  int count = 0;
  int instant = 0;
  String? error;
}
