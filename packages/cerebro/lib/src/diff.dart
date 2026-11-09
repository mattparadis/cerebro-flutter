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
    final regressions = changed.where((c) => c.isRegression).length;
    final losses = changed.where((c) => c.hasCoverageLoss).length;
    b.writeln('Baseline ${baselineGeneratedAt ?? '?'} → current ${currentGeneratedAt ?? '?'} · '
        '${changed.length} changed ($regressions regressions, $losses with coverage loss) · '
        '${added.length} added · ${removed.length} removed · $unchanged unchanged.');
    b.writeln();
    b.writeln('Regression = a finding that was not in the baseline (by identity: label/text + size or '
        'ratio), or a screen that stopped rendering. Coverage loss = something the baseline could '
        'measure and this capture cannot. Visual/semantics = changed, judge it yourself.');
    b.writeln();
    if (!hasChanges) {
      b.writeln('No screen changed.');
      return b.toString();
    }
    if (changed.isNotEmpty) {
      b.writeln('## Changed');
      b.writeln();
      b.writeln('| Screen | Class | What changed | Before | After |');
      b.writeln('|---|---|---|---|---|');
      for (final c in changed) {
        final cls = c.isRegression
            ? '**regression**'
            : c.hasCoverageLoss
                ? 'coverage loss'
                : c.fixedFindings.isNotEmpty
                    ? 'improvement'
                    : c.semantics
                        ? 'semantics'
                        : 'visual';
        b.writeln('| `${c.location}` · ${c.theme}${c.textScale == 1.0 ? '' : ' · ×${c.textScale}'} '
            '| $cls | ${c.describe()} '
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
    this.newFindings = const [],
    this.fixedFindings = const [],
    this.coverageLoss = const [],
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

  /// Findings present now and absent in the baseline, by stable identity
  /// (kind + label/text + size or colours), not by count: a fixed defect
  /// and a new one of the same kind still surface the new one.
  final List<String> newFindings;
  final List<String> fixedFindings;

  /// Things the baseline could verify and the current capture cannot
  /// (fewer texts measured, screen no longer rendering). Not a regression
  /// of the app, but not a pass either.
  final List<String> coverageLoss;

  /// Regressions first, then coverage loss, then semantics, then visual.
  int get weight {
    var w = 0;
    if (statusAfter == 'error' && statusBefore != 'error') w += 100;
    w += newFindings.length * 40;
    w += coverageLoss.length * 20;
    if (semantics) w += 10;
    if (visual) w += 5;
    return w;
  }

  bool get isRegression =>
      (statusAfter == 'error' && statusBefore != 'error') || newFindings.isNotEmpty;

  bool get hasCoverageLoss => coverageLoss.isNotEmpty;

  String describe() {
    final parts = <String>[];
    if (statusAfter != statusBefore) parts.add('status $statusBefore → $statusAfter');
    if (newFindings.isNotEmpty) parts.add('new: ${newFindings.join(', ')}');
    if (fixedFindings.isNotEmpty) parts.add('fixed: ${fixedFindings.join(', ')}');
    if (coverageLoss.isNotEmpty) parts.add('coverage: ${coverageLoss.join(', ')}');
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
        'new_findings': newFindings,
        'fixed_findings': fixedFindings,
        'coverage_loss': coverageLoss,
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
    final idsBefore = findingIds(before);
    final idsAfter = findingIds(after);
    final newFindings = idsAfter.keys.where((k) => !idsBefore.containsKey(k)).map((k) => idsAfter[k]!).toList();
    final fixedFindings = idsBefore.keys.where((k) => !idsAfter.containsKey(k)).map((k) => idsBefore[k]!).toList();
    final coverage = <String>[];
    final covB = before['contrast_coverage'] as Map?;
    final covA = after['contrast_coverage'] as Map?;
    if (covB != null && covA != null) {
      final mb = (covB['measured'] as num?) ?? 0, ma = (covA['measured'] as num?) ?? 0;
      if (ma < mb) coverage.add('contrast measured $mb → $ma texts');
    }
    if (statusAfter == 'error' && statusBefore == 'ok') coverage.add('screen no longer renders');
    if (!visual &&
        !semantics &&
        statusBefore == statusAfter &&
        exB == exA &&
        smB == smA &&
        newFindings.isEmpty &&
        fixedFindings.isEmpty &&
        coverage.isEmpty) {
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
      newFindings: newFindings,
      fixedFindings: fixedFindings,
      coverageLoss: coverage,
      beforePng: before['png'] == null
          ? null
          : baselinePrefix == null
              ? before['png'] as String
              : p.join(baselinePrefix, before['png'] as String),
      afterPng: after['png'] as String?,
    );
  }
}

/// Stable identities of a screen's deterministic findings, mapped to a
/// short human label. Positions are left out so a layout shift does not
/// fake a new finding; sizes, colours and ratios are in, so a worse
/// contrast on the same text is a new finding.
Map<String, String> findingIds(Map<String, Object?> screen) {
  final out = <String, String>{};
  for (final t in ((screen['tappables_below_min'] as List?) ?? const []).cast<Map>()) {
    final key = 'target|${t['label']}|${(t['width'] as num?)?.round()}x${(t['height'] as num?)?.round()}';
    out[key] = 'small target "${t['label']}" ${(t['width'] as num?)?.round()}×${(t['height'] as num?)?.round()}';
  }
  for (final c in ((screen['low_contrast'] as List?) ?? const []).cast<Map>()) {
    final ratio = (c['ratio'] as num?)?.toDouble() ?? 0;
    // bucket to 0.1 so sampling noise does not churn
    final key = 'contrast|${c['text']}|${(ratio * 10).round()}';
    out[key] = 'contrast "${c['text']}" ${ratio.toStringAsFixed(2)}:1';
  }
  for (final e in ((screen['exceptions'] as List?) ?? const []).cast<String>()) {
    final head = e.length > 60 ? e.substring(0, 60) : e;
    out['exception|$head'] = 'exception "$head"';
  }
  for (final e in ((screen['edges'] as List?) ?? const []).cast<Map>()) {
    if (e['kind'] == 'error') out['edge-error|${e['label']}'] = 'tap "${e['label']}" errors';
  }
  return out;
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
