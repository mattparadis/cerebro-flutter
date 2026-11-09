import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Result of [loadRealFonts], recorded in map.json so the agent knows whether
/// glyphs in the screenshots are real or the FlutterTest block font.
class FontLoadReport {
  FontLoadReport({required this.flutterRoot, required this.families, required this.warnings});

  final String? flutterRoot;
  final List<String> families;
  final List<String> warnings;

  Map<String, Object?> toJson() => {
        'flutter_root': flutterRoot,
        'families': families,
        'warnings': warnings,
      };
}

/// Locates the Flutter SDK root. `flutter test` exports FLUTTER_ROOT; as a
/// fallback walk up from the flutter_tester binary
/// (`<root>/bin/cache/artifacts/engine/<platform>/flutter_tester`).
String? findFlutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty && Directory(env).existsSync()) return env;
  var dir = p.dirname(Platform.resolvedExecutable);
  for (var i = 0; i < 8; i++) {
    if (File(p.join(dir, 'bin', 'flutter')).existsSync() &&
        Directory(p.join(dir, 'packages', 'flutter')).existsSync()) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) break;
    dir = parent;
  }
  return null;
}

/// Loads Roboto and MaterialIcons from the SDK cache, plus any extra font
/// files declared by the caller (family -> asset or file paths), so that
/// screenshots taken under `flutter test` show real glyphs instead of the
/// FlutterTest block font.
Future<FontLoadReport> loadRealFonts({
  Map<String, List<String>> extraFonts = const {},
}) async {
  final warnings = <String>[];
  final families = <String>[];
  final root = findFlutterRoot();

  if (root == null) {
    warnings.add('Flutter SDK root not found; screenshots use the FlutterTest font.');
  } else {
    final fontsDir = Directory(p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts'));
    if (!fontsDir.existsSync()) {
      warnings.add('material_fonts cache missing at ${fontsDir.path}');
    } else {
      final files = fontsDir.listSync().whereType<File>().toList();
      final roboto = FontLoader('Roboto');
      var robotoCount = 0;
      for (final f in files) {
        final name = p.basename(f.path);
        if (name.startsWith('Roboto-') && name.endsWith('.ttf')) {
          roboto.addFont(_bytes(f));
          robotoCount++;
        }
      }
      if (robotoCount > 0) {
        await roboto.load();
        families.add('Roboto');
      } else {
        warnings.add('No Roboto-*.ttf found in ${fontsDir.path}');
      }
      final icons = File(p.join(fontsDir.path, 'MaterialIcons-Regular.otf'));
      if (icons.existsSync()) {
        final loader = FontLoader('MaterialIcons')..addFont(_bytes(icons));
        await loader.load();
        families.add('MaterialIcons');
      } else {
        warnings.add('MaterialIcons-Regular.otf missing; icons render as boxes.');
      }
    }
  }

  for (final entry in extraFonts.entries) {
    final loader = FontLoader(entry.key);
    var added = 0;
    for (final path in entry.value) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(_bytes(file));
        added++;
      } else {
        try {
          loader.addFont(rootBundle.load(path));
          added++;
        } catch (e) {
          warnings.add('Font "$path" for family ${entry.key} not found: $e');
        }
      }
    }
    if (added > 0) {
      await loader.load();
      families.add(entry.key);
    }
  }

  return FontLoadReport(flutterRoot: root, families: families, warnings: warnings);
}

/// Resolves a font path from `cerebro.yaml` to a file path. Relative paths
/// are joined to [root]; a package asset key (`packages/<pkg>/fonts/x.ttf`,
/// the form `TextStyle(package:)` and `pubspec.yaml` fonts use) is mapped to
/// `<pkg root>/lib/fonts/x.ttf` through `.dart_tool/package_config.json`
/// ([packageConfig] overrides the file, for tests). Unknown packages fall
/// back to the literal path so the caller reports it as missing.
String resolveFontPath(String path, String root, {Map<String, Object?>? packageConfig}) {
  if (p.isAbsolute(path)) return path;
  final m = RegExp(r'^packages/([A-Za-z0-9_]+)/(.+)$').firstMatch(path);
  if (m != null) {
    final pkgRoot = _packageRoot(m.group(1)!, root, packageConfig);
    if (pkgRoot != null) return p.join(pkgRoot, 'lib', m.group(2)!);
  }
  return p.join(root, path);
}

String? _packageRoot(String name, String root, Map<String, Object?>? packageConfig) {
  var config = packageConfig;
  final file = File(p.join(root, '.dart_tool', 'package_config.json'));
  if (config == null) {
    if (!file.existsSync()) return null;
    try {
      config = (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }
  for (final pkg in (config['packages'] as List?) ?? const []) {
    if (pkg is! Map || pkg['name'] != name) continue;
    final uri = Uri.parse('${pkg['rootUri']}');
    final base = Uri.directory(p.join(root, '.dart_tool') + Platform.pathSeparator);
    final resolved = uri.hasScheme ? uri : base.resolveUri(uri);
    return resolved.scheme == 'file' ? resolved.toFilePath() : null;
  }
  return null;
}

/// Synchronous on purpose: this may run inside a `testWidgets` FakeAsync
/// zone, where real dart:io futures never complete. Call [loadRealFonts]
/// from `setUpAll` (outside FakeAsync) or from `tester.runAsync`.
Future<ByteData> _bytes(File f) {
  return SynchronousFuture(ByteData.sublistView(f.readAsBytesSync()));
}
