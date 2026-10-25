import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Compares two `map.json` files (or a baseline directory and the current
/// capture) and reports added, removed and changed screens.
///
/// Change detection uses the sha256 of the PNG and of the semantics dump
/// recorded by the capture, so it needs no image library. A changed
/// semantics hash with an unchanged PNG means an accessibility-only change
/// (labels, actions); a changed PNG with unchanged semantics means a
/// purely visual change (colour, spacing).
class CaptureDiff {
  CaptureDiff({
    required this.added,
    required this.removed,
    required this.changed,
    required this.unchanged,
    required this.baselineGeneratedAt,
    required this.currentGeneratedAt,
  });

  final List<Map<String, Object?>> added;
  final List<Map<String, Object?>> removed;
  final List<ScreenChange> changed;
  final int unchanged;
  final String? baselineGeneratedAt;
  final String? currentGeneratedAt;

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty || changed.isNotEmpty;

  Map<String, Object?> toJson() => {
        'baseline_generated_at': baselineGeneratedAt,
        'current_generated_at': currentGeneratedAt,
        'summary': {
          'added': added.length,
          'removed': removed.length,
          'changed': changed.length,
          'unchanged': unchanged,
        },
        'added': added.map(_brief).toList(),
        'removed': removed.map(_brief).toList(),
        'changed': changed.map((c) => c.toJson()).toList(),
      };

  static Map<String, Object?> _brief(Map<String, Object?> s) => {
        'id': s['id'],
        'location': s['location'],
        'theme': s['theme'],
        'png': s['png'],
      };

  /// [baselinePrefix] is prepended to baseline PNG paths so that DIFF.md,
  /// written next to the current capture, can show "before" images.
  static CaptureDiff compare(
    Map<String, Object?> baseline,
    Map<String, Object?> current, {
    String? baselinePrefix,
  }) {
    final before = _byId(baseline);
    final after = _byId(current);
    final added = <Map<String, Object?>>[];
    final removed = <Map<String, Object?>>[];
    final changed = <ScreenChange>[];
    var unchanged = 0;
    for (final entry in after.entries) {
      final b = before[entry.key];
      if (b == null) {
        added.add(entry.value);
        continue;
      }
      final change = ScreenChange.detect(b, entry.value, baselinePrefix: baselinePrefix);
      if (change == null) {
        unchanged++;
      } else {
        changed.add(change);
      }
    }
    for (final entry in before.entries) {
      if (!after.containsKey(entry.key)) removed.add(entry.value);
    }
    int bySeverity(ScreenChange a, ScreenChange b) => b.weight.compareTo(a.weight);
    changed.sort(bySeverity);
    return CaptureDiff(
      added: added,
      removed: removed,
      changed: changed,
      unchanged: unchanged,
      baselineGeneratedAt: baseline['generated_at'] as String?,
      currentGeneratedAt: current['generated_at'] as String?,
    );
  }

  static Map<String, Map<String, Object?>> _byId(Map<String, Object?> map) {
    final screens = (map['screens'] as List?)?.cast<Map>() ?? const [];
    return {for (final s in screens) '${s['id']}': s.cast<String, Object?>()};
  }

  String renderMarkdown() {
    final b = StringBuffer();
    b.writeln('# UI diff');
    b.writeln();
    b.writeln('Baseline ${baselineGeneratedAt ?? '?'} → current ${currentGeneratedAt ?? '?'} · '
        '${changed.length} changed · ${added.length} added · ${removed.length} removed · $unchanged unchanged.');
    b.writeln();
    if (!hasChanges) {
      b.writeln('No screen changed.');
      return b.toString();
    }
    if (changed.isNotEmpty) {
      b.writeln('## Changed');
      b.writeln();
      b.writeln('| Screen | What changed | Before | After |');
      b.writeln('|---|---|---|---|');
      for (final c in changed) {
        b.writeln('| `${c.location}` · ${c.theme}${c.textScale == 1.0 ? '' : ' · ×${c.textScale}'} '
            '| ${c.describe()} '
            '| ${_img(c.beforePng, 'before')} | ${_img(c.afterPng, 'after')} |');
      }
      b.writeln();
    }
    if (added.isNotEmpty) {
      b.writeln('## Added');
      b.writeln();
      for (final s in added) {
        b.writeln('- `${s['location']}` · ${s['theme']} ${_img(s['png'] as String?, 'new')}');
      }
      b.writeln();
    }
    if (removed.isNotEmpty) {
      b.writeln('## Removed');
      b.writeln();
      for (final s in removed) {
        b.writeln('- `${s['location']}` · ${s['theme']}');
      }
      b.writeln();
    }
    return b.toString();
  }

  static String _img(String? path, String alt) =>
      path == null ? '' : '<img src="$path" width="100" alt="$alt">';
}

class ScreenChange {
  ScreenChange({
    required this.id,
    required this.location,
    required this.theme,
    required this.textScale,
    required this.visual,
    required this.semantics,
    required this.statusBefore,
    required this.statusAfter,
    required this.exceptionsBefore,
    required this.exceptionsAfter,
    required this.smallTargetsBefore,
    required this.smallTargetsAfter,
    required this.beforePng,
    required this.afterPng,
  });

  final String id;
  final String location;
  final String theme;
  final double textScale;
  final bool visual;
  final bool semantics;
  final String statusBefore;
  final String statusAfter;
  final int exceptionsBefore;
  final int exceptionsAfter;
  final int smallTargetsBefore;
  final int smallTargetsAfter;
  final String? beforePng;
  final String? afterPng;

  /// Regressions first: errors, new exceptions, new small targets, then
  /// semantics, then visual.
  int get weight {
    var w = 0;
    if (statusAfter == 'error' && statusBefore != 'error') w += 100;
    if (exceptionsAfter > exceptionsBefore) w += 50;
    if (smallTargetsAfter > smallTargetsBefore) w += 40;
    if (semantics) w += 10;
    if (visual) w += 5;
    return w;
  }

  bool get isRegression =>
      (statusAfter == 'error' && statusBefore != 'error') ||
      exceptionsAfter > exceptionsBefore ||
      smallTargetsAfter > smallTargetsBefore;

  String describe() {
    final parts = <String>[];
    if (statusAfter != statusBefore) parts.add('status $statusBefore → $statusAfter');
    if (exceptionsAfter != exceptionsBefore) {
      parts.add('layout exceptions $exceptionsBefore → $exceptionsAfter');
    }
    if (smallTargetsAfter != smallTargetsBefore) {
      parts.add('small tap targets $smallTargetsBefore → $smallTargetsAfter');
    }
    if (semantics && visual) {
      parts.add('visual + semantics');
    } else if (semantics) {
      parts.add('semantics only (labels/actions)');
    } else if (visual) {
      parts.add('visual only (pixels)');
    }
    return parts.join('; ');
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'location': location,
        'theme': theme,
        'text_scale': textScale,
        'visual': visual,
        'semantics': semantics,
        'regression': isRegression,
        'status': {'before': statusBefore, 'after': statusAfter},
        'exceptions': {'before': exceptionsBefore, 'after': exceptionsAfter},
        'tappables_below_min': {'before': smallTargetsBefore, 'after': smallTargetsAfter},
        'description': describe(),
        'before_png': beforePng,
        'after_png': afterPng,
      };

  static ScreenChange? detect(
    Map<String, Object?> before,
    Map<String, Object?> after, {
    String? baselinePrefix,
  }) {
    final visual = before['sha256_png'] != after['sha256_png'];
    final semantics = before['sha256_semantics'] != after['sha256_semantics'];
    final statusBefore = '${before['status']}';
    final statusAfter = '${after['status']}';
    final exB = ((before['exceptions'] as List?) ?? const []).length;
    final exA = ((after['exceptions'] as List?) ?? const []).length;
    final smB = ((before['tappables_below_min'] as List?) ?? const []).length;
    final smA = ((after['tappables_below_min'] as List?) ?? const []).length;
    if (!visual && !semantics && statusBefore == statusAfter && exB == exA && smB == smA) {
      return null;
    }
    return ScreenChange(
      id: '${after['id']}',
      location: '${after['location']}',
      theme: '${after['theme']}',
      textScale: (after['text_scale'] as num?)?.toDouble() ?? 1.0,
      visual: visual,
      semantics: semantics,
      statusBefore: statusBefore,
      statusAfter: statusAfter,
      exceptionsBefore: exB,
      exceptionsAfter: exA,
      smallTargetsBefore: smB,
      smallTargetsAfter: smA,
      beforePng: before['png'] == null
          ? null
          : baselinePrefix == null
              ? before['png'] as String
              : p.join(baselinePrefix, before['png'] as String),
      afterPng: after['png'] as String?,
    );
  }
}

/// Reads a `map.json` from a file path or from a directory containing one.
Map<String, Object?> readMap(String pathOrDir) {
  var f = File(pathOrDir);
  if (FileSystemEntity.isDirectorySync(pathOrDir)) f = File(p.join(pathOrDir, 'map.json'));
  if (!f.existsSync()) {
    throw FileSystemException('map.json not found', f.path);
  }
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
}
