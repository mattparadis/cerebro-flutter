import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'edges.dart';

/// Merges `routes.json`, `fonts.json` and `results/*.json` into `map.json`
/// and renders `MAP.md` (Mermaid route tree + thumbnail table).
class MapWriter {
  MapWriter(this.outDir, {this.flutterVersion});

  final String outDir;
  final String? flutterVersion;

  Map<String, Object?> write() {
    final routes = _readJson(p.join(outDir, 'routes.json')) ?? {};
    final fonts = _readJson(p.join(outDir, 'fonts.json'));
    final resultsDir = Directory(p.join(outDir, 'results'));
    final screens = <Map<String, Object?>>[];
    if (resultsDir.existsSync()) {
      final files = resultsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        final j = _readJson(f.path);
        if (j != null) screens.add(j);
      }
    }
    final targets = (routes['targets'] as List?)?.cast<Map>() ?? const [];
    final skipped = [
      for (final t in targets)
        if (t['skipped'] != null) {'route': t['route'], 'reason': t['skipped']},
    ];
    final edges = <Map<String, Object?>>[
      for (final s in screens)
        for (final e in (s['edges'] as List?) ?? const []) (e as Map).cast<String, Object?>(),
    ];
    final noEffect = edges.where((e) => e['kind'] == 'no_observed_effect' || e['kind'] == 'none').toList();
    final stateChanges = edges.where((e) => e['kind'] == 'state_change').toList();
    final map = <String, Object?>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'flutter_version': flutterVersion,
      'config': routes['config'],
      'fonts': fonts,
      'routes_tree': routes['tree'],
      'skipped': skipped,
      'summary': {
        'screens': screens.length,
        'ok': screens.where((s) => s['status'] == 'ok').length,
        'error': screens.where((s) => s['status'] == 'error').length,
        'with_exceptions': screens.where((s) => ((s['exceptions'] as List?) ?? []).isNotEmpty).length,
        'with_small_tappables': screens.where((s) => ((s['tappables_below_min'] as List?) ?? []).isNotEmpty).length,
        'with_low_contrast': screens.where((s) => ((s['low_contrast'] as List?) ?? []).isNotEmpty).length,
        'explored_taps': edges.length,
        'no_effect_taps': noEffect.length,
        'state_change_taps': stateChanges.length,
      },
      'edges': edges,
      'no_effect_taps': noEffect,
      'screens': screens,
    };
    File(p.join(outDir, 'map.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
    File(p.join(outDir, 'MAP.md')).writeAsStringSync(renderMarkdown(map));
    return map;
  }

  static String renderMarkdown(Map<String, Object?> map) {
    final b = StringBuffer();
    final tree = (map['routes_tree'] as List?)?.cast<Map>() ?? const [];
    final screens = (map['screens'] as List?)?.cast<Map>() ?? const [];
    final summary = (map['summary'] as Map?) ?? const {};
    b.writeln('# UI map');
    b.writeln();
    b.writeln('Generated ${map['generated_at']} · ${summary['screens']} screenshots · '
        '${summary['error']} errors · ${summary['with_exceptions']} with layout exceptions · '
        '${summary['with_small_tappables']} with tap targets below minimum · '
        '${summary['with_low_contrast']} with low-contrast text.');
    b.writeln();
    b.writeln('## Navigation tree');
    b.writeln();
    b.writeln('```mermaid');
    b.writeln('graph TD');
    var counter = 0;
    String nextId() => 'n${counter++}';
    void walk(Map node, String? parentId, int indent) {
      final pad = '  ' * indent;
      final kind = node['kind'];
      if (kind == 'route') {
        final id = nextId();
        final label = node['path'];
        b.writeln('$pad$id["$label"]');
        if (parentId != null) b.writeln('$pad$parentId --> $id');
        for (final c in (node['children'] as List?)?.cast<Map>() ?? const []) {
          walk(c, id, indent);
        }
      } else {
        final id = nextId();
        final title = kind == 'stateful_shell'
            ? 'StatefulShellRoute'
            : kind == 'branch'
                ? 'branch'
                : kind == 'shell'
                    ? 'ShellRoute'
                    : '$kind';
        b.writeln('${pad}subgraph $id["$title"]');
        for (final c in (node['children'] as List?)?.cast<Map>() ?? const []) {
          walk(c, parentId, indent + 1);
        }
        b.writeln('${pad}end');
      }
    }

    for (final n in tree) {
      walk(n, null, 1);
    }
    b.writeln('```');
    b.writeln();

    final edges = (map['edges'] as List?)?.cast<Map>().map((e) => e.cast<String, Object?>()).toList() ?? const [];
    if (edges.isNotEmpty) {
      b.writeln('## Navigation graph (explored by tapping)');
      b.writeln();
      b.writeln('Thick arrows push, thin arrows pop, dashed arrows open an overlay. '
          '${summary['explored_taps']} taps explored: ${summary['state_change_taps']} changed the '
          'page content in place, ${summary['no_effect_taps']} had no effect the harness could observe.');
      b.writeln();
      b.writeln('```mermaid');
      b.write(renderEdgesMermaid(edges));
      b.writeln('```');
      b.writeln();
      final dead = (map['no_effect_taps'] as List?)?.cast<Map>() ?? const [];
      if (dead.isNotEmpty) {
        b.writeln('### Taps with no observed effect');
        b.writeln();
        b.writeln('Controls with a tap action after which neither the location, the stack, an overlay '
            'nor the semantics tree changed. Suspects, not confirmed defects: focus-only controls, '
            'actions whose effect is outside the screen (network, clipboard, haptics) and handlers '
            'that are genuinely empty all look the same here. Confirm in the source.');
        b.writeln();
        for (final d in dead) {
          b.writeln('- `${d['from']}` · "${d['label']}" at (${d['x']}, ${d['y']})');
        }
        b.writeln();
      }
    }

    final limits = <String>[];
    final fontsMap = map['fonts'] as Map?;
    for (final w in (fontsMap?['warnings'] as List?) ?? const []) {
      limits.add('fonts: $w');
    }
    for (final s in screens) {
      if (s['status'] == 'error') limits.add('`${s['location']}` (${s['theme']}): did not render: ${s['error']}');
      if (s['redirected_to'] != null) limits.add('`${s['location']}`: redirected to `${s['redirected_to']}` on open');
      final nofam = (s['text_without_font_family'] as List?) ?? const [];
      if (nofam.isNotEmpty) limits.add('`${s['location']}` (${s['theme']}): ${nofam.length} text(s) without font family render as blocks');
      final nm = (s['contrast_not_measurable'] as List?) ?? const [];
      if (nm.isNotEmpty) limits.add('`${s['location']}` (${s['theme']}): contrast not measurable for ${nm.length} text(s)');
    }
    if (limits.isNotEmpty) {
      b.writeln('## Capture limits');
      b.writeln();
      b.writeln('Harness limits, not app defects. Each one is something the audit cannot judge from this capture.');
      b.writeln();
      for (final l in limits.toSet()) {
        b.writeln('- $l');
      }
      b.writeln();
    }

    final skipped = (map['skipped'] as List?)?.cast<Map>() ?? const [];
    if (skipped.isNotEmpty) {
      b.writeln('## Not captured');
      b.writeln();
      for (final s in skipped) {
        b.writeln('- `${s['route']}`: ${s['reason']}');
      }
      b.writeln();
    }

    b.writeln('## Screens');
    b.writeln();
    final byLocation = <String, List<Map>>{};
    for (final s in screens) {
      final key = s['scenario'] == null ? '${s['location']}' : '${s['location']} [${s['scenario']}]';
      byLocation.putIfAbsent(key, () => []).add(s);
    }
    for (final entry in byLocation.entries) {
      final first = entry.value.first;
      b.writeln('### `${entry.key}`');
      b.writeln();
      b.writeln('Route `${first['route']}`${first['name'] != null ? ' · name `${first['name']}`' : ''}');
      b.writeln();
      b.writeln('| Variant | Screenshot | Status | Notes |');
      b.writeln('|---|---|---|---|');
      for (final s in entry.value) {
        final notes = <String>[];
        final exc = (s['exceptions'] as List?) ?? const [];
        if (exc.isNotEmpty) notes.add('${exc.length} exception(s)');
        final small = (s['tappables_below_min'] as List?) ?? const [];
        if (small.isNotEmpty) notes.add('${small.length} small tap target(s)');
        final lowc = (s['low_contrast'] as List?) ?? const [];
        if (lowc.isNotEmpty) notes.add('${lowc.length} low-contrast text(s)');
        final nofam = (s['text_without_font_family'] as List?) ?? const [];
        if (nofam.isNotEmpty) notes.add('${nofam.length} text(s) without font family (blocks in PNG)');
        if (s['redirected_to'] != null) notes.add('redirects to `${s['redirected_to']}`');
        if (s['error'] != null) notes.add('${s['error']}');
        final png = s['png'];
        final img = png == null ? '' : '<img src="$png" width="120" alt="${s['id']}">';
        final sc = s['scenario'] == null ? '' : ' · scenario `${s['scenario']}`';
        if (s['scenario_issue'] != null) notes.add('${s['scenario_issue']}');
        b.writeln('| ${s['device']} · ${s['theme']} · ${s['platform']}$sc | $img | ${s['status']} | ${notes.join('; ')} |');
      }
      b.writeln();
    }
    return b.toString();
  }

  static Map<String, Object?>? _readJson(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    final v = jsonDecode(f.readAsStringSync());
    return v is Map ? v.cast<String, Object?>() : null;
  }
}
