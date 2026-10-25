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
import 'contrast.dart';
import 'edges.dart';
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
    const exploreEnv = String.fromEnvironment('UI_MAP_EXPLORE');

    final projectRoot = Directory.current.path;
    final configPath = cfgEnv.isEmpty ? p.join(projectRoot, 'ui_map.yaml') : cfgEnv;
    final config = UiMapConfig.load(configPath);
    final explore = exploreEnv == 'true' || (exploreEnv.isEmpty && config.explore);
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
            for (final scale in config.textScales) {
              final suffix = scale == 1.0 ? '' : '__x${_fmtScale(scale)}';
              final id = '${slugForLocation(t.location)}__${device.name}__${theme}__$platform$suffix';
              final exploreThis = explore &&
                  scale == 1.0 &&
                  theme == config.themes.first &&
                  platform == config.platforms.first &&
                  device == config.devices.first;
              testWidgets('ui_map $id', (tester) async {
                await _captureOne(
                  tester,
                  id: id,
                  target: t,
                  device: device,
                  theme: theme,
                  platform: platform,
                  textScale: scale,
                  explore: exploreThis,
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
  }

  static Future<void> _captureOne(
    WidgetTester tester, {
    required String id,
    required ScreenTarget target,
    required DeviceSpec device,
    required String theme,
    required String platform,
    required double textScale,
    required bool explore,
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
      'text_scale': textScale,
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
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

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
      Uint8List? rgba;
      var imageW = 0, imageH = 0;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: config.exportScale);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(pngPath).writeAsBytesSync(bytes!.buffer.asUint8List());
          result['width_px'] = image.width;
          result['height_px'] = image.height;
          imageW = image.width;
          imageH = image.height;
          final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          rgba = raw?.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      });
      if (rgba != null) {
        final report = measureTextContrast(tester, rgba!, imageW, imageH, scale: config.exportScale);
        result['text_nodes_checked'] = report.checked;
        result['low_contrast'] = report.low.map((e) => e.toJson()).toList();
      }
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
        if (explore) {
          result['edges'] = (await _explore(
            tester,
            target: target,
            tappables: tappables,
            themeMode: themeMode,
            config: config,
            buildRouter: buildRouter,
            buildApp: buildApp,
            device: device,
          ))
              .map((e) => e.toJson())
              .toList();
        }
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

  /// Taps every (non-nested) semantics target of the screen, each time on a
  /// freshly built app, and records where the router ends up or which
  /// overlay appeared.
  static Future<List<NavEdge>> _explore(
    WidgetTester tester, {
    required ScreenTarget target,
    required List<Tappable> tappables,
    required ThemeMode themeMode,
    required UiMapConfig config,
    required RouterBuilder buildRouter,
    required AppBuilder buildApp,
    required DeviceSpec device,
  }) async {
    final edges = <NavEdge>[];
    final candidates = tappables.where((t) => !t.nestedInLargerTarget).take(config.exploreMaxTaps).toList();
    var unlabeled = 0;
    for (final t in candidates) {
      final label = t.label.isEmpty ? 'unlabeled#${++unlabeled}' : t.label;
      final router = buildRouter(initialLocation: target.location);
      await tester.pumpWidget(
        _withInsetBands(buildApp(router, themeMode: themeMode), top: device.safeTop, bottom: device.safeBottom),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      while (tester.takeException() != null) {}
      // `router.state` describes the top-most route, including imperative
      // pushes, which the configuration's own `uri` does not reflect.
      final depthBefore = router.routerDelegate.currentConfiguration.matches.length;
      final from = router.state.uri.toString();
      String? error;
      try {
        await tester.tapAt(Offset(t.left + t.width / 2, t.top + t.height / 2));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } catch (e) {
        error = _firstLine(e.toString());
      }
      for (var e = tester.takeException(); e != null; e = tester.takeException()) {
        error ??= _firstLine(e.toString());
      }
      final depthAfter = router.routerDelegate.currentConfiguration.matches.length;
      final to = router.state.uri.toString();
      String? overlay;
      if (find.byType(Dialog).evaluate().isNotEmpty || find.byType(AlertDialog).evaluate().isNotEmpty) {
        overlay = 'dialog';
      } else if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        overlay = 'sheet';
      } else if (find.byType(SnackBar).evaluate().isNotEmpty) {
        overlay = 'snackbar';
      } else if (find.byType(PopupMenuButton).evaluate().isNotEmpty &&
          find.byWidgetPredicate((w) => w.runtimeType.toString().contains('_PopupMenu')).evaluate().isNotEmpty) {
        overlay = 'menu';
      }
      if (overlay != null && to != from) overlay = null; // navigation wins
      edges.add(NavEdge(
        from: from,
        label: label,
        to: to,
        kind: classifyEdge(
          from: from,
          to: to,
          depthBefore: depthBefore,
          depthAfter: depthAfter,
          overlay: overlay,
          error: error,
        ),
        overlay: overlay,
        error: error,
        x: t.left + t.width / 2,
        y: t.top + t.height / 2,
      ));
    }
    return edges;
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

  static String _fmtScale(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }
}

class LowContrast {
  const LowContrast({
    required this.text,
    required this.ratio,
    required this.required,
    required this.foreground,
    required this.background,
    required this.fontSize,
    required this.rect,
  });

  final String text;
  final double ratio;
  final double required;
  final int foreground;
  final int background;
  final double fontSize;
  final Rect rect;

  Map<String, Object?> toJson() => {
        'text': text,
        'ratio': (ratio * 100).round() / 100,
        'required': required,
        'fg': _hex(foreground),
        'bg': _hex(background),
        'font_size': fontSize,
        'x': Tappable._r(rect.left),
        'y': Tappable._r(rect.top),
        'width': Tappable._r(rect.width),
        'height': Tappable._r(rect.height),
      };

  static String _hex(int c) => '#${c.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class ContrastReport {
  const ContrastReport({required this.checked, required this.low});

  final int checked;
  final List<LowContrast> low;
}

/// Measures WCAG contrast for every rendered paragraph: the text colour is
/// known from the `RenderParagraph`, the background is sampled from the
/// screenshot pixels under it. Text with an alpha colour is composited.
ContrastReport measureTextContrast(
  WidgetTester tester,
  Uint8List rgba,
  int imageW,
  int imageH, {
  required double scale,
}) {
  var checked = 0;
  final low = <LowContrast>[];
  final seen = <String>{};
  for (final element in find.byType(RichText).evaluate()) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    final span = ro.text;
    final plain = span.toPlainText().trim();
    if (plain.isEmpty) continue;
    final style = _firstStyle(span);
    final color = style?.color;
    if (color == null) continue;
    final offset = ro.localToGlobal(Offset.zero);
    final rect = offset & ro.size;
    if (rect.isEmpty || rect.width < 2 || rect.height < 2) continue;
    final key = '$plain|${rect.left.round()}|${rect.top.round()}';
    if (!seen.add(key)) continue;
    final argb = color.toARGB32();
    final left = (rect.left * scale).round(), top = (rect.top * scale).round();
    final w = (rect.width * scale).round(), h = (rect.height * scale).round();
    final fgOpaque = argb & 0xFFFFFF;
    final bg = sampleBackground(rgba, imageW, imageH, left: left, top: top, width: w, height: h, foreground: fgOpaque);
    if (bg == null) continue;
    final fg = compositeOver(argb, bg);
    final ratio = contrastRatio(fg, bg);
    final fontSize = style?.fontSize ?? 14;
    final bold = (style?.fontWeight?.value ?? 400) >= FontWeight.w700.value;
    final required = requiredContrast(fontSize: fontSize, bold: bold);
    checked++;
    if (ratio < required) {
      low.add(LowContrast(
        text: plain.length > 40 ? '${plain.substring(0, 40)}…' : plain,
        ratio: ratio,
        required: required,
        foreground: fg,
        background: bg,
        fontSize: fontSize,
        rect: rect,
      ));
    }
  }
  low.sort((a, b) => a.ratio.compareTo(b.ratio));
  return ContrastReport(checked: checked, low: low);
}

TextStyle? _firstStyle(InlineSpan span) {
  if (span.style?.color != null) return span.style;
  if (span is TextSpan && span.children != null) {
    for (final c in span.children!) {
      final s = _firstStyle(c);
      if (s != null) return s;
    }
  }
  return span.style;
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
