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

  /// `error` (deprecated API / will break), `warning` (structural defect
  /// visible to users), `convention` (bypasses the theme or project
  /// conventions; a defect only if the rendered result is wrong) or `info`
  /// (worth a look).
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
  'hardcoded-color': LintRule('hardcoded-color', 'convention',
      'Colour literal bypasses ColorScheme: dark mode and contrast are not guaranteed by the theme. '
      'Check the rendered result (low_contrast, dark capture) before calling it a defect.'),
  'literal-font-size': LintRule('literal-font-size', 'convention',
      'fontSize literal bypasses the TextTheme type scale; a defect only if it breaks hierarchy or large text.'),
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
final _sizedBox = RegExp(r'\b(?:SizedBox(?:\.square)?|ConstrainedBox|Container)\(');
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
    // `// cerebro: ignore` (or `// ignore: cerebro`) on the line disables every rule for it.
    if (_inlineIgnore.hasMatch(line)) continue;
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
    final sb = _sizedBox.firstMatch(code);
    if (sb != null) {
      // Only the box's own argument list counts: a sibling `SizedBox(height: 8)`
      // followed by an IconButton is not a constraint on the button.
      final span = _balancedArguments(lines, i, _lineOffset(line, code, sb.end - 1));
      if (span != null) {
        final small = _dimension
            .allMatches(span)
            .map((m) => double.parse(m.group(1)!))
            .where((v) => v < 48)
            .toList();
        if (small.isNotEmpty && RegExp(r'child:\s*(const\s+)?IconButton\(').hasMatch(span)) {
          add('small-icon-button', i, '(${small.first.toStringAsFixed(0)} dp)');
        }
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

final _inlineIgnore = RegExp(r'//\s*(cerebro:\s*ignore|ignore:\s*cerebro|ui_map:\s*ignore|ignore:\s*ui_map)');

int _lineOffset(String line, String code, int idx) => idx;

/// Text of the argument list that opens at [openParenIdx] on line [i],
/// up to its matching `)`, spanning lines; null when unbalanced within
/// 60 lines.
String? _balancedArguments(List<String> lines, int i, int openParenIdx) {
  final b = StringBuffer();
  var depth = 0;
  var started = false;
  for (var l = i; l < lines.length && l < i + 60; l++) {
    final text = _stripComment(lines[l]);
    final start = l == i ? openParenIdx : 0;
    for (var c = start; c < text.length; c++) {
      final ch = text[c];
      if (ch == '(') {
        depth++;
        started = true;
      } else if (ch == ')') {
        depth--;
        if (started && depth == 0) {
          b.write(text.substring(start, c + 1));
          return b.toString();
        }
      }
    }
    b.writeln(text.substring(start));
  }
  return null;
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
      if (rel.startsWith('test/cerebro/')) continue;
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
      '${counts['warning'] ?? 0} warnings · ${counts['convention'] ?? 0} convention · ${counts['info'] ?? 0} info.');
  b.writeln();
  b.writeln('Errors and warnings are structural defects with a `file:line`. Convention findings '
      'bypass the theme or project conventions and are defects only when the rendered result is '
      'wrong (check `low_contrast` and the dark capture). Add `// cerebro: ignore` to a line for a '
      'motivated exception.');
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
