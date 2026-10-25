import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:ui_map/src/config.dart';
import 'package:ui_map/src/diff.dart';
import 'package:ui_map/src/lint.dart';
import 'package:ui_map/src/map_writer.dart';
import 'package:ui_map/src/templates.dart';

const _usage = '''
ui_map: headless screenshots + navigation map for Flutter apps.

Usage: dart run ui_map <command> [options]

Commands:
  init      Scaffold ui_map.yaml, test/ui_map/app_factory.dart and the capture test.
  routes    Print the route tree and the locations that would be captured.
  capture   Capture every screen, then write .ui-map/map.json and MAP.md.
  baseline  Save the current capture as the baseline (.ui-map/baseline/) for diff.
  diff      Compare the current capture with the baseline; write diff.json and DIFF.md.
  lint      Scan lib/ for design-rule violations (hardcoded colours, small targets, ...).
  check     capture + diff + lint in one step (for pre-commit hooks and CI).

Run from the root of the Flutter app (where pubspec.yaml is).
''';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addFlag('force', help: 'Overwrite scaffolded files (init).', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', help: 'Path to ui_map.yaml (default: ./ui_map.yaml).')
    ..addOption('out', help: 'Output directory (default: out_dir in config, else .ui-map).')
    ..addMultiOption('dart-define', abbr: 'D',
        help: 'Extra --dart-define=KEY=VALUE forwarded to flutter test (e.g. -D UI_PROTO=true).')
    ..addFlag('explore', negatable: false,
        help: 'Also tap every target of each screen and record the navigation edges (slower).')
    ..addOption('baseline', help: 'Baseline map.json or directory (default: <out>/baseline).')
    ..addOption('fail-on',
        allowed: ['none', 'regression', 'any'],
        defaultsTo: 'regression',
        help: 'diff/check exit code 1 on: regressions (errors, new layout exceptions, new small '
            'targets), any change, or never.')
    ..addOption('lint-fail-on',
        allowed: ['none', 'error', 'warning', 'info'],
        defaultsTo: 'error',
        help: 'lint/check exit code 1 when findings of this severity or higher exist.');
  final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(_usage);
    exit(64);
  }
  if (args['help'] == true || args.rest.isEmpty) {
    stdout.writeln(_usage);
    stdout.writeln(parser.usage);
    exit(args.rest.isEmpty ? 64 : 0);
  }
  final root = Directory.current.path;
  if (!File(p.join(root, 'pubspec.yaml')).existsSync()) {
    stderr.writeln('ui_map: no pubspec.yaml in $root. Run from the Flutter app root.');
    exit(66);
  }
  final configPath = p.absolute(args['config'] as String? ?? p.join(root, 'ui_map.yaml'));
  final outDir = p.absolute(args['out'] as String? ?? _outDirFromConfig(configPath) ?? p.join(root, '.ui-map'));

  final defines = [
    ...(args['dart-define'] as List<String>),
    if (args['explore'] == true) 'UI_MAP_EXPLORE=true',
  ];
  switch (args.rest.first) {
    case 'init':
      _init(root, configPath, force: args['force'] == true);
    case 'routes':
      exit(await _routes(root, configPath, outDir, defines));
    case 'capture':
      exit(await _capture(root, configPath, outDir, defines));
    case 'baseline':
      exit(_baseline(root, outDir));
    case 'diff':
      exit(_diff(root, outDir, args['baseline'] as String?, args['fail-on'] as String));
    case 'lint':
      exit(_lint(root, configPath, outDir, args['lint-fail-on'] as String));
    case 'check':
      final code = await _capture(root, configPath, outDir, defines);
      if (code != 0) exit(code);
      final diffCode = _diff(root, outDir, args['baseline'] as String?, args['fail-on'] as String);
      final lintCode = _lint(root, configPath, outDir, args['lint-fail-on'] as String);
      exit(diffCode != 0 ? diffCode : lintCode);
    default:
      stderr.writeln('Unknown command: ${args.rest.first}');
      stderr.writeln(_usage);
      exit(64);
  }
}

String? _outDirFromConfig(String configPath) {
  final f = File(configPath);
  if (!f.existsSync()) return null;
  final m = RegExp(r'^out_dir:\s*(\S+)', multiLine: true).firstMatch(f.readAsStringSync());
  return m == null ? null : p.join(p.dirname(configPath), m.group(1)!);
}

void _init(String root, String configPath, {required bool force}) {
  final testDir = Directory(p.join(root, 'test', 'ui_map'))..createSync(recursive: true);
  _scaffold(configPath, configTemplate, force: force);
  _scaffold(p.join(testDir.path, 'app_factory.dart'), appFactoryTemplate, force: force);
  _scaffold(p.join(testDir.path, 'ui_map_capture_test.dart'), captureTestTemplate, force: true);
  stdout.writeln('''
Next steps:
  1. Fill in test/ui_map/app_factory.dart (buildRouter / buildApp).
  2. dart run ui_map routes     # check which locations will be captured
  3. dart run ui_map capture    # writes ${p.relative(_outDirFromConfig(configPath) ?? '.ui-map', from: root)}/
''');
}

void _scaffold(String path, String content, {required bool force}) {
  final f = File(path);
  if (f.existsSync() && !force) {
    stdout.writeln('kept     ${p.relative(path)} (use --force to overwrite)');
    return;
  }
  f.writeAsStringSync(content.trimLeft());
  stdout.writeln('wrote    ${p.relative(path)}');
}

bool _ensureScaffolded(String root) {
  final test = File(p.join(root, 'test', 'ui_map', 'ui_map_capture_test.dart'));
  final factory = File(p.join(root, 'test', 'ui_map', 'app_factory.dart'));
  if (!test.existsSync() || !factory.existsSync()) {
    stderr.writeln('ui_map: not initialised. Run `dart run ui_map init` first.');
    return false;
  }
  if (factory.readAsStringSync().contains('UnimplementedError(')) {
    stderr.writeln('ui_map: test/ui_map/app_factory.dart still has the TODO stubs. Fill in buildRouter and buildApp.');
    return false;
  }
  return true;
}

Future<int> _runFlutterTest(
    String root, String configPath, String outDir, String mode, List<String> defines) async {
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final proc = await Process.start(
    flutter,
    [
      'test',
      p.join('test', 'ui_map', 'ui_map_capture_test.dart'),
      '--dart-define=UI_MAP_OUT=$outDir',
      '--dart-define=UI_MAP_CONFIG=$configPath',
      '--dart-define=UI_MAP_MODE=$mode',
      for (final d in defines) '--dart-define=$d',
      '--reporter=compact',
    ],
    workingDirectory: root,
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  return proc.exitCode;
}

Future<int> _routes(String root, String configPath, String outDir, List<String> defines) async {
  if (!_ensureScaffolded(root)) return 65;
  Directory(outDir).createSync(recursive: true);
  final code = await _runFlutterTest(root, configPath, outDir, 'list', defines);
  if (code != 0) return code;
  final routes = jsonDecode(File(p.join(outDir, 'routes.json')).readAsStringSync()) as Map;
  final targets = (routes['targets'] as List).cast<Map>();
  stdout.writeln();
  stdout.writeln('Locations to capture (${targets.where((t) => t['skipped'] == null).length}):');
  for (final t in targets) {
    final name = t['name'] != null ? '  (${t['name']})' : '';
    if (t['skipped'] != null) {
      stdout.writeln('  SKIP ${t['route']}$name: ${t['skipped']}');
    } else {
      stdout.writeln('       ${t['location']}$name');
    }
  }
  return 0;
}

Future<int> _capture(String root, String configPath, String outDir, List<String> defines) async {
  if (!_ensureScaffolded(root)) return 65;
  for (final sub in ['screens', 'semantics', 'results']) {
    final d = Directory(p.join(outDir, sub));
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
  // A diff from a previous capture would contradict the new map.json.
  for (final stale in ['diff.json', 'DIFF.md']) {
    final f = File(p.join(outDir, stale));
    if (f.existsSync()) f.deleteSync();
  }
  Directory(outDir).createSync(recursive: true);
  final testCode = await _runFlutterTest(root, configPath, outDir, 'capture', defines);
  final map = MapWriter(outDir, flutterVersion: _flutterVersion()).write();
  final summary = map['summary'] as Map;
  stdout.writeln();
  stdout.writeln('ui_map: ${summary['ok']}/${summary['screens']} screens captured, '
      '${summary['error']} errors, ${summary['with_exceptions']} with layout exceptions, '
      '${summary['with_small_tappables']} with small tap targets, '
      '${summary['with_low_contrast']} with low-contrast text'
      '${(summary['explored_taps'] as int) > 0 ? ', ${summary['explored_taps']} taps explored (${summary['dead_taps']} dead)' : ''}.');
  stdout.writeln('ui_map: ${p.relative(p.join(outDir, 'map.json'), from: root)} and MAP.md written.');
  if (testCode != 0 || (summary['error'] as int) > 0) return 1;
  return 0;
}

int _baseline(String root, String outDir) {
  final map = File(p.join(outDir, 'map.json'));
  if (!map.existsSync()) {
    stderr.writeln('ui_map: no capture found at ${p.relative(map.path, from: root)}. Run `dart run ui_map capture` first.');
    return 66;
  }
  final base = Directory(p.join(outDir, 'baseline'));
  if (base.existsSync()) base.deleteSync(recursive: true);
  Directory(p.join(base.path, 'screens')).createSync(recursive: true);
  map.copySync(p.join(base.path, 'map.json'));
  var copied = 0;
  final screens = Directory(p.join(outDir, 'screens'));
  if (screens.existsSync()) {
    for (final f in screens.listSync().whereType<File>()) {
      f.copySync(p.join(base.path, 'screens', p.basename(f.path)));
      copied++;
    }
  }
  stdout.writeln('ui_map: baseline saved to ${p.relative(base.path, from: root)}/ ($copied screenshots).');
  stdout.writeln('ui_map: commit that directory to diff against it in CI.');
  return 0;
}

int _diff(String root, String outDir, String? baselineArg, String failOn) {
  final currentPath = p.join(outDir, 'map.json');
  if (!File(currentPath).existsSync()) {
    stderr.writeln('ui_map: no capture found. Run `dart run ui_map capture` first.');
    return 66;
  }
  final baselinePath = p.absolute(baselineArg ?? p.join(outDir, 'baseline'));
  final Map<String, Object?> baseline;
  try {
    baseline = readMap(baselinePath);
  } on FileSystemException catch (e) {
    stderr.writeln('ui_map: baseline not found (${e.path}). Run `dart run ui_map baseline` after a capture you trust.');
    return 66;
  }
  final current = readMap(currentPath);
  final baselineDir = FileSystemEntity.isDirectorySync(baselinePath) ? baselinePath : p.dirname(baselinePath);
  final diff = CaptureDiff.compare(baseline, current, baselinePrefix: p.relative(baselineDir, from: outDir));
  File(p.join(outDir, 'diff.json'))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(diff.toJson()));
  File(p.join(outDir, 'DIFF.md')).writeAsStringSync(diff.renderMarkdown());
  final regressions = diff.changed.where((c) => c.isRegression).length;
  stdout.writeln('ui_map diff: ${diff.changed.length} changed ($regressions regressions), '
      '${diff.added.length} added, ${diff.removed.length} removed, ${diff.unchanged} unchanged.');
  for (final c in diff.changed.take(10)) {
    stdout.writeln('  ${c.isRegression ? '!!' : '  '} ${c.location} · ${c.theme}'
        '${c.textScale == 1.0 ? '' : ' · x${c.textScale}'}: ${c.describe()}');
  }
  if (diff.changed.length > 10) stdout.writeln('  ... see ${p.relative(p.join(outDir, 'DIFF.md'), from: root)}');
  stdout.writeln('ui_map: ${p.relative(p.join(outDir, 'DIFF.md'), from: root)} written.');
  return switch (failOn) {
    'any' => diff.hasChanges ? 1 : 0,
    'regression' => regressions > 0 ? 1 : 0,
    _ => 0,
  };
}

int _lint(String root, String configPath, String outDir, String failOn) {
  final config = UiMapConfig.load(configPath);
  final options = LintOptions(
    excludeGlobs: config.lintExclude ?? const LintOptions().excludeGlobs,
    rules: config.lintRules,
  );
  final findings = lintProject(root, options: options);
  Directory(outDir).createSync(recursive: true);
  File(p.join(outDir, 'lint.json')).writeAsStringSync(const JsonEncoder.withIndent('  ')
      .convert({'generated_at': DateTime.now().toUtc().toIso8601String(), 'findings': findings.map((f) => f.toJson()).toList()}));
  File(p.join(outDir, 'LINT.md')).writeAsStringSync(renderLintMarkdown(findings));
  final counts = <String, int>{};
  for (final f in findings) {
    counts[f.severity] = (counts[f.severity] ?? 0) + 1;
  }
  stdout.writeln('ui_map lint: ${findings.length} findings · ${counts['error'] ?? 0} errors · '
      '${counts['warning'] ?? 0} warnings · ${counts['info'] ?? 0} info.');
  for (final f in findings.where((f) => f.severity != 'info').take(15)) {
    stdout.writeln('  ${f.severity == 'error' ? '!!' : ' !'} ${f.file}:${f.line}  ${f.rule}  ${f.snippet}');
  }
  stdout.writeln('ui_map: ${p.relative(p.join(outDir, 'LINT.md'), from: root)} written.');
  const rank = {'error': 3, 'warning': 2, 'info': 1, 'none': 0};
  final threshold = rank[failOn]!;
  if (threshold == 0) return 0;
  return findings.any((f) => rank[f.severity]! >= threshold) ? 1 : 0;
}

String? _flutterVersion() {
  try {
    final r = Process.runSync('flutter', ['--version', '--machine'], runInShell: true);
    if (r.exitCode != 0) return null;
    final j = jsonDecode(r.stdout as String) as Map;
    return '${j['frameworkVersion']}';
  } catch (_) {
    return null;
  }
}
