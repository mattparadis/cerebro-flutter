import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:ui_map/src/map_writer.dart';
import 'package:ui_map/src/templates.dart';

const _usage = '''
ui_map: headless screenshots + navigation map for Flutter apps.

Usage: dart run ui_map <command> [options]

Commands:
  init      Scaffold ui_map.yaml, test/ui_map/app_factory.dart and the capture test.
  routes    Print the route tree and the locations that would be captured.
  capture   Capture every screen, then write .ui-map/map.json and MAP.md.

Run from the root of the Flutter app (where pubspec.yaml is).
''';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addFlag('force', help: 'Overwrite scaffolded files (init).', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', help: 'Path to ui_map.yaml (default: ./ui_map.yaml).')
    ..addOption('out', help: 'Output directory (default: out_dir in config, else .ui-map).')
    ..addMultiOption('dart-define', abbr: 'D',
        help: 'Extra --dart-define=KEY=VALUE forwarded to flutter test (e.g. -D UI_PROTO=true).');
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

  final defines = (args['dart-define'] as List<String>);
  switch (args.rest.first) {
    case 'init':
      _init(root, configPath, force: args['force'] == true);
    case 'routes':
      exit(await _routes(root, configPath, outDir, defines));
    case 'capture':
      exit(await _capture(root, configPath, outDir, defines));
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
  Directory(outDir).createSync(recursive: true);
  final testCode = await _runFlutterTest(root, configPath, outDir, 'capture', defines);
  final map = MapWriter(outDir, flutterVersion: _flutterVersion()).write();
  final summary = map['summary'] as Map;
  stdout.writeln();
  stdout.writeln('ui_map: ${summary['ok']}/${summary['screens']} screens captured, '
      '${summary['error']} errors, ${summary['with_exceptions']} with layout exceptions, '
      '${summary['with_small_tappables']} with small tap targets.');
  stdout.writeln('ui_map: ${p.relative(p.join(outDir, 'map.json'), from: root)} and MAP.md written.');
  if (testCode != 0 || (summary['error'] as int) > 0) return 1;
  return 0;
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
