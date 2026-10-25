import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'fonts.dart';
import 'routes.dart';

typedef RouterBuilder = GoRouter Function({required String initialLocation});
typedef AppBuilder = Widget Function(GoRouter router, {required ThemeMode themeMode});

/// Entry point called by the generated `test/ui_map/ui_map_capture_test.dart`.
///
/// Registers one `testWidgets` per (location × device × theme × platform)
/// so a failing screen never blocks the others. Reads `ui_map.yaml` and
/// the `UI_MAP_OUT` / `UI_MAP_CONFIG` / `UI_MAP_MODE` dart-defines.
class UiMap {
  UiMap._();

  static void run({required RouterBuilder buildRouter, required AppBuilder buildApp}) {
    TestWidgetsFlutterBinding.ensureInitialized();

    const outEnv = String.fromEnvironment('UI_MAP_OUT');
    const cfgEnv = String.fromEnvironment('UI_MAP_CONFIG');
    const mode = String.fromEnvironment('UI_MAP_MODE', defaultValue: 'capture');

    final projectRoot = Directory.current.path;
    final configPath = cfgEnv.isEmpty ? p.join(projectRoot, 'ui_map.yaml') : cfgEnv;
    final config = UiMapConfig.load(configPath);
    final outDir = outEnv.isEmpty ? p.join(projectRoot, config.outDir) : outEnv;
    Directory(outDir).createSync(recursive: true);

    final tree = enumerateRoutes(buildRouter(initialLocation: '/'));
    final targets = expandTargets(tree, config);
    _writeJson(p.join(outDir, 'routes.json'), {
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'config_path': configPath,
      'config': config.toJson(),
      'tree': tree.map((n) => n.toJson()).toList(),
      'targets': [
        for (final t in targets)
          {
            'route': t.routePath,
            if (t.routeName != null) 'name': t.routeName,
            'location': t.location,
            if (t.skipped) 'skipped': t.skippedReason,
          },
      ],
    });

    if (mode == 'list') {
      test('ui_map: routes written to routes.json', () {});
      return;
    }

    setUpAll(() async {
      final report = await loadRealFonts(extraFonts: _resolveFonts(config.fonts, projectRoot));
      _writeJson(p.join(outDir, 'fonts.json'), report.toJson());
    });

    for (final t in targets.where((t) => !t.skipped)) {
      for (final device in config.devices) {
        for (final theme in config.themes) {
          for (final platform in config.platforms) {
            final id = '${slugForLocation(t.location)}__${device.name}__${theme}__$platform';
            testWidgets('ui_map $id', (tester) async {
              await _captureOne(
                tester,
                id: id,
                target: t,
                device: device,
                theme: theme,
                platform: platform,
                config: config,
                outDir: outDir,
                buildRouter: buildRouter,
                buildApp: buildApp,
              );
            });
          }
        }
      }
    }
  }

  static Future<void> _captureOne(
    WidgetTester tester, {
    required String id,
    required ScreenTarget target,
    required DeviceSpec device,
    required String theme,
    required String platform,
    required UiMapConfig config,
    required String outDir,
    required RouterBuilder buildRouter,
    required AppBuilder buildApp,
  }) async {
    final sw = Stopwatch()..start();
    final result = <String, Object?>{
      'id': id,
      'route': target.routePath,
      'name': target.routeName,
      'location': target.location,
      'device': device.name,
      'theme': theme,
      'platform': platform,
      'status': 'ok',
    };
    final screensDir = Directory(p.join(outDir, 'screens'))..createSync(recursive: true);
    final semDir = Directory(p.join(outDir, 'semantics'))..createSync(recursive: true);
    final resultsDir = Directory(p.join(outDir, 'results'))..createSync(recursive: true);

    tester.view.physicalSize = Size(device.width * device.dpr, device.height * device.dpr);
    tester.view.devicePixelRatio = device.dpr;
    final insets = FakeViewPadding(
      top: device.safeTop * device.dpr,
      bottom: device.safeBottom * device.dpr,
    );
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
    addTearDown(tester.view.reset);
    result['safe_area'] = {'top': device.safeTop, 'bottom': device.safeBottom};

    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = switch (platform) {
      'ios' => TargetPlatform.iOS,
      'macos' => TargetPlatform.macOS,
      'linux' => TargetPlatform.linux,
      'windows' => TargetPlatform.windows,
      _ => TargetPlatform.android,
    };
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;

    SemanticsHandle? handle;
    String? failure;
    try {
      handle = tester.ensureSemantics();
      final key = GlobalKey();
      final themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      final router = buildRouter(initialLocation: target.location);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _withInsetBands(
            buildApp(router, themeMode: themeMode),
            top: device.safeTop,
            bottom: device.safeBottom,
          ),
        ),
      );
      const step = Duration(milliseconds: 100);
      final steps = (config.settleMs / 100).ceil().clamp(1, 600);
      for (var i = 0; i < steps; i++) {
        await tester.pump(step);
      }

      // Layout/paint exceptions (e.g. RenderFlex overflow) are findings, not
      // reasons to abort: collect them and keep going.
      final exceptions = <String>[];
      for (var e = tester.takeException(); e != null; e = tester.takeException()) {
        exceptions.add(_firstLine(e.toString()));
      }
      result['exceptions'] = exceptions;

      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pngPath = p.join(screensDir.path, '$id.png');
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: config.exportScale);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(pngPath).writeAsBytesSync(bytes!.buffer.asUint8List());
          result['width_px'] = image.width;
          result['height_px'] = image.height;
        } finally {
          image.dispose();
        }
      });
      result['png'] = p.relative(pngPath, from: outDir);
      result['sha256_png'] = sha256.convert(File(pngPath).readAsBytesSync()).toString();

      final renderView = tester.binding.renderViews.firstWhere((r) => r.flutterView == tester.view);
      final root = renderView.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) {
        // Object hash suffixes (e.g. `OrdinalSortKey#cba7c`) change per run;
        // strip them so the dump and its sha256 are deterministic.
        final dump = root.toStringDeep().replaceAll(RegExp(r'#[0-9a-f]{5}\b'), '');
        final semPath = p.join(semDir.path, '$id.txt');
        File(semPath).writeAsStringSync(dump);
        result['semantics'] = p.relative(semPath, from: outDir);
        result['sha256_semantics'] = sha256.convert(utf8.encode(dump)).toString();
        final tappables = collectTappables(root, dpr: device.dpr, minTapSize: config.minTapSize);
        result['tappables_count'] = tappables.length;
        result['tappables_below_min'] = [
          for (final t in tappables)
            if ((t.width < config.minTapSize || t.height < config.minTapSize) && !t.nestedInLargerTarget)
              t.toJson(),
        ];
        result['tappables_below_min_nested'] = [
          for (final t in tappables)
            if ((t.width < config.minTapSize || t.height < config.minTapSize) && t.nestedInLargerTarget)
              t.toJson(),
        ];
      } else {
        result['semantics'] = null;
      }
    } catch (e, st) {
      failure = '${_firstLine(e.toString())}\n$st';
      result['status'] = 'error';
      result['error'] = _firstLine(e.toString());
    } finally {
      handle?.dispose();
      debugDisableShadows = previousShadows;
      debugDefaultTargetPlatformOverride = previousPlatform;
      result['duration_ms'] = sw.elapsedMilliseconds;
      _writeJson(p.join(resultsDir.path, '$id.json'), result);
    }
    if (failure != null) fail('ui_map: $id failed: $failure');
  }

  /// Draws the simulated status-bar and navigation-bar areas as translucent
  /// bands over the app, outside its widget tree, so a screenshot shows
  /// whether content respects `SafeArea`.
  static Widget _withInsetBands(Widget app, {required double top, required double bottom}) {
    const band = Color(0x40000000);
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        app,
        if (top > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top,
            child: const IgnorePointer(child: ExcludeSemantics(child: ColoredBox(color: band))),
          ),
        if (bottom > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: bottom,
            child: const IgnorePointer(child: ExcludeSemantics(child: ColoredBox(color: band))),
          ),
      ],
    );
  }

  static Map<String, List<String>> _resolveFonts(Map<String, List<String>> fonts, String root) => {
        for (final e in fonts.entries)
          e.key: [for (final f in e.value) p.isAbsolute(f) ? f : p.join(root, f)],
      };

  static void _writeJson(String path, Object data) {
    File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  }

  static String _firstLine(String s) => s.split('\n').first.trim();
}

/// A tappable semantics node with its rect in logical pixels.
class Tappable {
  const Tappable({
    required this.label,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.nestedInLargerTarget = false,
  });

  final String label;
  final double left;
  final double top;
  final double width;
  final double height;

  /// True when an ancestor tappable node of at least the minimum size
  /// contains this one (e.g. a Switch inside a SwitchListTile). The real
  /// hit area is the ancestor, so this is not a touch-target defect.
  final bool nestedInLargerTarget;

  Map<String, Object?> toJson() => {
        'label': label,
        'x': _r(left),
        'y': _r(top),
        'width': _r(width),
        'height': _r(height),
        'nested_in_larger_target': nestedInLargerTarget,
      };

  static double _r(double v) => (v * 10).roundToDouble() / 10;
}

/// Walks the semantics tree accumulating transforms; rects come out in
/// physical pixels (the root is the RenderView), so divide by [dpr].
List<Tappable> collectTappables(
  SemanticsNode root, {
  required double dpr,
  double minTapSize = 48,
}) {
  final out = <Tappable>[];
  final seen = <String>{};
  void walk(SemanticsNode n, Matrix4 parent, Rect? enclosingTarget) {
    final m = n.transform == null ? parent : (parent.clone()..multiply(n.transform!));
    final data = n.getSemanticsData();
    final hidden = n.flagsCollection.isHidden;
    var enclosing = enclosingTarget;
    if (!hidden && data.hasAction(SemanticsAction.tap) && !n.rect.isEmpty) {
      final r = MatrixUtils.transformRect(m, n.rect);
      final logical = Rect.fromLTWH(r.left / dpr, r.top / dpr, r.width / dpr, r.height / dpr);
      final nested = enclosingTarget != null &&
          enclosingTarget.contains(logical.topLeft) &&
          enclosingTarget.contains(logical.bottomRight - const Offset(0.01, 0.01));
      if (logical.width >= minTapSize && logical.height >= minTapSize) enclosing = logical;
      final label = (data.label.isNotEmpty
              ? data.label
              : data.tooltip.isNotEmpty
                  ? data.tooltip
                  : data.hint)
          .replaceAll('\n', ' / ');
      final key = '$label|${r.left.round()}|${r.top.round()}|${r.width.round()}|${r.height.round()}';
      if (seen.add(key)) {
        out.add(Tappable(
          label: label,
          left: logical.left,
          top: logical.top,
          width: logical.width,
          height: logical.height,
          nestedInLargerTarget: nested,
        ));
      }
    }
    n.visitChildren((c) {
      walk(c, m, enclosing);
      return true;
    });
  }

  walk(root, Matrix4.identity(), null);
  return out;
}
