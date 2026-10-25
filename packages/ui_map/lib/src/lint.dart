import 'dart:io';

import 'package:path/path.dart' as p;

/// A deterministic, regex-based scan of Dart UI code for the defects the
/// audit most often finds. Not a replacement for the analyzer: it targets
/// design rules the analyzer does not know about.
class LintFinding {
  const LintFinding({
    required this.rule,
    required this.severity,
    required this.file,
    required this.line,
    required this.message,
    required this.snippet,
  });

  final String rule;

  /// `error`, `warning` or `info`.
  final String severity;
  final String file;
  final int line;
  final String message;
  final String snippet;

  Map<String, Object?> toJson() => {
        'rule': rule,
        'severity': severity,
        'file': file,
        'line': line,
        'message': message,
        'snippet': snippet,
      };
}

class LintRule {
  const LintRule(this.id, this.severity, this.message);

  final String id;
  final String severity;
  final String message;
}

const lintRules = <String, LintRule>{
  'hardcoded-color': LintRule('hardcoded-color', 'warning',
      'Colour literal bypasses ColorScheme; dark mode and contrast are unverified.'),
  'literal-font-size': LintRule('literal-font-size', 'warning',
      'fontSize literal bypasses the TextTheme type scale.'),
  'empty-handler': LintRule('empty-handler', 'warning',
      'Empty onPressed/onTap: the control looks interactive but does nothing. Use null to disable.'),
  'small-icon-button': LintRule('small-icon-button', 'warning',
      'IconButton constrained below 48 dp.'),
  'deprecated-will-pop-scope': LintRule('deprecated-will-pop-scope', 'error',
      'WillPopScope is deprecated; use PopScope.'),
  'platform-io-check': LintRule('platform-io-check', 'warning',
      'Platform.isIOS/isAndroid in UI code breaks tests and web; use Theme.of(context).platform.'),
  'no-safe-area': LintRule('no-safe-area', 'info',
      'File builds a Scaffold without AppBar or SafeArea; content may sit under system bars.'),
  'network-image-no-error-builder': LintRule('network-image-no-error-builder', 'info',
      'Image.network without errorBuilder shows a broken image on failure.'),
  'gesture-without-semantics': LintRule('gesture-without-semantics', 'info',
      'GestureDetector with onTap and no Semantics/Tooltip nearby is invisible to assistive tech.'),
  'pump-and-settle': LintRule('pump-and-settle', 'info',
      'pumpAndSettle hangs on indeterminate progress indicators; prefer pump(duration).'),
};

class LintOptions {
  const LintOptions({
    this.excludeGlobs = const ['**/*.g.dart', '**/*.freezed.dart', '**/theme.dart', '**/theme/**'],
    this.rules = const {},
  });

  /// Path patterns (simple `*`/`**` globs) skipped for colour and font rules.
  final List<String> excludeGlobs;

  /// Rule id -> enabled. Missing rules are enabled.
  final Map<String, bool> rules;

  bool enabled(String id) => rules[id] ?? true;

  bool excluded(String relPath) => excludeGlobs.any((g) => _globMatch(g, relPath));

  static bool _globMatch(String glob, String path) {
    final re = RegExp('^${RegExp.escape(glob).replaceAll(r'\*\*/', '(?:.*/)?').replaceAll(r'\*\*', '.*').replaceAll(r'\*', '[^/]*')}\$');
    return re.hasMatch(path);
  }
}

final _colorLiteral = RegExp(r'\bColor\(0x[0-9A-Fa-f]{6,8}\)|\bColors\.(?!transparent\b)[a-zA-Z]+(\[\d+\]|\.shade\d+)?');
final _fontSize = RegExp(r'\bfontSize:\s*\d+(\.\d+)?');
final _emptyHandler = RegExp(r'\b(onPressed|onTap|onLongPress|onChanged)\s*:\s*\(\s*[_\w]*\s*\)\s*(async\s*)?\{\s*\}');
final _sizedBox = RegExp(r'\bSizedBox(\.square)?\(');
final _dimension = RegExp(r'\b(?:width|height|dimension):\s*(\d+(?:\.\d+)?)');
final _willPop = RegExp(r'\bWillPopScope\b');
final _platformIo = RegExp(r'\bPlatform\.is(IOS|Android|MacOS|Windows|Linux)\b');
final _gesture = RegExp(r'\bGestureDetector\(');
final _imageNetwork = RegExp(r'\bImage\.network\(');
final _pumpAndSettle = RegExp(r'\bpumpAndSettle\(');

List<LintFinding> lintFile(String relPath, String source, {LintOptions options = const LintOptions()}) {
  final out = <LintFinding>[];
  final lines = source.split('\n');
  final isTest = relPath.startsWith('test/') || relPath.contains('/test/');
  final skipStyleRules = options.excluded(relPath);

  void add(String rule, int lineIdx, [String? extra]) {
    if (!options.enabled(rule)) return;
    final r = lintRules[rule]!;
    out.add(LintFinding(
      rule: rule,
      severity: r.severity,
      file: relPath,
      line: lineIdx + 1,
      message: extra == null ? r.message : '${r.message} $extra',
      snippet: lines[lineIdx].trim(),
    ));
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final code = _stripComment(line);
    if (code.trim().isEmpty) continue;
    if (isTest) {
      if (_pumpAndSettle.hasMatch(code)) add('pump-and-settle', i);
      continue;
    }
    if (!skipStyleRules) {
      if (_colorLiteral.hasMatch(code)) add('hardcoded-color', i);
      if (_fontSize.hasMatch(code)) add('literal-font-size', i);
    }
    if (_emptyHandler.hasMatch(code)) add('empty-handler', i);
    if (_willPop.hasMatch(code)) add('deprecated-will-pop-scope', i);
    if (_platformIo.hasMatch(code)) add('platform-io-check', i);
    if (_sizedBox.hasMatch(code)) {
      final window = lines.skip(i).take(6).map(_stripComment).join('\n');
      final small = _dimension
          .allMatches(window)
          .map((m) => double.parse(m.group(1)!))
          .where((v) => v < 48)
          .toList();
      if (small.isNotEmpty && window.contains('IconButton(')) {
        add('small-icon-button', i, '(${small.first.toStringAsFixed(0)} dp)');
      }
    }
    if (_gesture.hasMatch(code)) {
      final window = lines.skip(i).take(8).join('\n');
      final before = lines.skip(i < 3 ? 0 : i - 3).take(3).join('\n');
      if (window.contains('onTap:') &&
          !window.contains('Semantics(') &&
          !before.contains('Semantics(') &&
          !window.contains('Tooltip(') &&
          !before.contains('Tooltip(')) {
        add('gesture-without-semantics', i);
      }
    }
    if (_imageNetwork.hasMatch(code)) {
      final window = lines.skip(i).take(8).join('\n');
      if (!window.contains('errorBuilder:')) add('network-image-no-error-builder', i);
    }
  }

  if (!isTest && source.contains('Scaffold(') && !source.contains('CupertinoPageScaffold(')) {
    final hasChrome = source.contains('appBar:') ||
        source.contains('SafeArea(') ||
        source.contains('SliverAppBar') ||
        source.contains('CupertinoNavigationBar') ||
        source.contains('bottomNavigationBar:') ||
        source.contains('navigationShell');
    if (!hasChrome) {
      final idx = lines.indexWhere((l) => l.contains('Scaffold('));
      add('no-safe-area', idx < 0 ? 0 : idx);
    }
  }
  return out;
}

String _stripComment(String line) {
  final idx = line.indexOf('//');
  return idx < 0 ? line : line.substring(0, idx);
}

/// Scans `lib/` (and `test/` for test-only rules) under [root].
List<LintFinding> lintProject(String root, {LintOptions options = const LintOptions()}) {
  final out = <LintFinding>[];
  for (final dirName in ['lib', 'test']) {
    final dir = Directory(p.join(root, dirName));
    if (!dir.existsSync()) continue;
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final rel = p.relative(f.path, from: root).replaceAll('\\', '/');
      if (rel.startsWith('test/ui_map/')) continue;
      out.addAll(lintFile(rel, f.readAsStringSync(), options: options));
    }
  }
  return out;
}

String renderLintMarkdown(List<LintFinding> findings) {
  final b = StringBuffer();
  final counts = <String, int>{};
  for (final f in findings) {
    counts[f.severity] = (counts[f.severity] ?? 0) + 1;
  }
  b.writeln('# UI lint');
  b.writeln();
  b.writeln('${findings.length} findings · ${counts['error'] ?? 0} errors · '
      '${counts['warning'] ?? 0} warnings · ${counts['info'] ?? 0} info.');
  b.writeln();
  if (findings.isEmpty) return b.toString();
  final byRule = <String, List<LintFinding>>{};
  for (final f in findings) {
    byRule.putIfAbsent(f.rule, () => []).add(f);
  }
  for (final entry in byRule.entries) {
    final rule = lintRules[entry.key]!;
    b.writeln('## ${entry.key} (${rule.severity}, ${entry.value.length})');
    b.writeln();
    b.writeln(rule.message);
    b.writeln();
    for (final f in entry.value) {
      b.writeln('- `${f.file}:${f.line}` `${f.snippet}`');
    }
    b.writeln();
  }
  return b.toString();
}
