import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'contrast.dart';
import 'driver.dart';
import 'edges.dart';
import 'fonts.dart';
import 'routes.dart';

export 'driver.dart' show AppBuilder, ArgumentsFor, RootBuilder, RouterBuilder;

/// A named test fixture: seeds fakes, overrides dependencies, logs a user
/// in, puts a repository in its error state. Runs (with real async
/// allowed) right before the screen is built. Pair it with [ScenarioReset]
/// so scenarios do not leak into the next screen.
typedef ScenarioSetup = Future<void> Function();
typedef ScenarioReset = Future<void> Function();

/// Entry point called by the generated `test/ui_map/ui_map_capture_test.dart`.
///
/// Registers one `testWidgets` per (location × device × theme × platform)
/// so a failing screen never blocks the others. Reads `ui_map.yaml` and
/// the `UI_MAP_OUT` / `UI_MAP_CONFIG` / `UI_MAP_MODE` dart-defines.
class UiMap {
  UiMap._();

  /// go_router apps.
  ///
  /// [scenarios] are named fixtures the capture can apply per route
  /// (`routes.<path>.scenarios` / `default_scenario` in ui_map.yaml);
  /// [resetScenario] runs before every screen so state never leaks.
  static void run({
    required RouterBuilder buildRouter,
    required AppBuilder buildApp,
    Map<String, ScenarioSetup> scenarios = const {},
    ScenarioReset? resetScenario,
  }) {
    final env = _Env.read(scenarios: scenarios, resetScenario: resetScenario);
    final tree = enumerateRoutes(buildRouter(initialLocation: '/'));
    final targets = expandTargets(tree, env.config);
    _writeRoutes(env, tree, targets, kind: 'go_router');
    if (env.mode == 'list') {
      test('ui_map: routes written to routes.json', () {});
      return;
    }
    _registerFonts(env);
    final driver = GoRouterDriver(buildRouter: buildRouter, buildApp: buildApp);
    final firstLocale = env.config.locales.isEmpty ? null : env.config.locales.first;
    for (final combo in _combos(env)) {
      for (final t in targets.where((t) => !t.skipped)) {
        final id = _idFor(t, combo, firstLocale: combo.locale == firstLocale);
        testWidgets('ui_map $id', (tester) async {
          await _captureOne(tester, id: id, target: t, combo: combo, env: env, driver: driver);
        });
      }
    }
    final protos = targets.where((t) => !t.skipped && t.routePath.startsWith('/__proto/')).toList();
    if (protos.isNotEmpty) {
      testWidgets('ui_map proto sheet', (tester) async => _protoSheet(tester, env, protos));
    }
  }

  /// Navigator 1.0 apps (`MaterialApp.routes`). Route names are read from
  /// the running app, so enumeration happens inside the test: one test per
  /// device × theme × platform × text scale, looping over the screens.
  static void runNavigator({
    required RootBuilder buildApp,
    ArgumentsFor? argumentsFor,
    Map<String, ScenarioSetup> scenarios = const {},
    ScenarioReset? resetScenario,
    String? outDir,
  }) {
    final env = _Env.read(outDirOverride: outDir, scenarios: scenarios, resetScenario: resetScenario);
    final configArgs = {
      for (final e in env.config.routes.entries)
        if (e.value.args != null) e.key: e.value.args,
    };
    final driver = NavigatorDriver(buildApp: buildApp, argumentsFor: argumentsFor, configArgs: configArgs);
    if (env.mode != 'list') _registerFonts(env);
    final combos = env.mode == 'list' ? [_combos(env).first] : _combos(env).toList();
    for (final combo in combos) {
      testWidgets('ui_map ${env.mode} ${combo.id}', (tester) async {
        await tester.pumpWidget(buildApp(themeMode: ThemeMode.light));
        await tester.pump(const Duration(milliseconds: 50));
        final names = driver.enumerate(tester);
        // Routes mentioned in ui_map.yaml but not in the map (onGenerateRoute).
        for (final extra in env.config.routes.keys) {
          if (!names.contains(extra) && !extra.contains('?')) names.add(extra);
        }
        final tree = treeFromPaths(names);
        final targets = expandTargets(tree, env.config);
        if (combo == combos.first) _writeRoutes(env, tree, targets, kind: 'navigator');
        while (tester.takeException() != null) {}
        if (env.mode == 'list') return;
        final firstLocale = env.config.locales.isEmpty ? null : env.config.locales.first;
        for (final t in targets.where((t) => !t.skipped)) {
          final id = _idFor(t, combo, firstLocale: combo.locale == firstLocale);
          // ignore: avoid_print
          print('ui_map $id');
          await _captureOne(tester, id: id, target: t, combo: combo, env: env, driver: driver, rethrowFailures: false);
        }
      });
    }
  }

  static Iterable<_Combo> _combos(_Env env) sync* {
    final c = env.config;
    final locales = c.locales.isEmpty ? <String?>[null] : c.locales.cast<String?>();
    for (final device in c.devices) {
      for (final theme in c.themes) {
        for (final platform in c.platforms) {
          for (final scale in c.textScales) {
            for (final locale in locales) {
              yield _Combo(
                device: device,
                theme: theme,
                platform: platform,
                textScale: scale,
                locale: locale,
                explore: env.explore &&
                    scale == 1.0 &&
                    theme == c.themes.first &&
                    platform == c.platforms.first &&
                    device == c.devices.first &&
                    locale == locales.first,
              );
            }
          }
        }
      }
    }
  }

  static String _idFor(ScreenTarget t, _Combo c, {bool firstLocale = true}) {
    final scale = c.textScale == 1.0 ? '' : '__x${_fmtScale(c.textScale)}';
    final sc = t.scenario == null ? '' : '__s-${slugForScenario(t.scenario!)}';
    final kb = t.keyboard ? '__kb' : '';
    final loc = c.locale == null || firstLocale ? '' : '__${c.locale}';
    return '${slugForLocation(t.location)}$sc${kb}__${c.device.name}__${c.theme}__${c.platform}$scale$loc';
  }

  /// Runs the reset hook, then the screen's scenario (or the default one).
  /// Unknown scenario names are recorded on the result and skipped.
  static Future<String?> _applyScenario(WidgetTester tester, _Env env, ScreenTarget target) async {
    final name = target.scenario ?? env.config.defaultScenario;
    final reset = env.resetScenario;
    if (reset != null) await tester.runAsync(reset);
    if (name == null) return null;
    final setup = env.scenarios[name];
    if (setup == null) {
      return 'unknown scenario "$name": not in the factory\'s scenarios map';
    }
    await tester.runAsync(setup);
    return null;
  }

  static void _writeRoutes(_Env env, List<RouteNode> tree, List<ScreenTarget> targets, {required String kind}) {
    _writeJson(p.join(env.outDir, 'routes.json'), {
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'router': kind,
      'config_path': env.configPath,
      'config': env.config.toJson(),
      'tree': tree.map((n) => n.toJson()).toList(),
      'targets': [
        for (final t in targets)
          {
            'route': t.routePath,
            if (t.routeName != null) 'name': t.routeName,
            'location': t.location,
            if (t.scenario != null) 'scenario': t.scenario,
            if (t.skipped) 'skipped': t.skippedReason,
          },
      ],
      'scenarios': env.scenarios.keys.toList(),
    });
  }

  static void _registerFonts(_Env env) {
    setUpAll(() async {
      final report = await loadRealFonts(extraFonts: _resolveFonts(env.config.fonts, env.projectRoot));
      _writeJson(p.join(env.outDir, 'fonts.json'), report.toJson());
    });
  }

  static Future<void> _captureOne(
    WidgetTester tester, {
    required String id,
    required ScreenTarget target,
    required _Combo combo,
    required _Env env,
    required ScreenDriver driver,
    bool rethrowFailures = true,
  }) async {
    final device = combo.device;
    final theme = combo.theme;
    final platform = combo.platform;
    final textScale = combo.textScale;
    final explore = combo.explore;
    final config = env.config;
    final outDir = env.outDir;
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
      if (combo.locale != null) 'locale': combo.locale,
      if (target.keyboard) 'keyboard': true,
      if (target.scenario != null || config.defaultScenario != null)
        'scenario': target.scenario ?? config.defaultScenario,
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
    result['safe_area'] = {'top': device.safeTop, 'bottom': device.safeBottom};
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
    }
    if (combo.locale != null) {
      final parts = combo.locale!.split(RegExp('[-_]'));
      tester.platformDispatcher.localesTestValue = [
        Locale(parts.first, parts.length > 1 ? parts[1] : null),
      ];
      tester.platformDispatcher.localeTestValue = tester.platformDispatcher.locales.first;
    }
    final minTap = config.minTapSizeFor(platform);
    result['min_tap_size'] = minTap;

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
      Widget wrap(Widget app) => RepaintBoundary(
            key: key,
            child: _withInsetBands(app, top: device.safeTop, bottom: device.safeBottom),
          );
      final scenarioProblem = await _applyScenario(tester, env, target);
      if (scenarioProblem != null) result['scenario_issue'] = scenarioProblem;
      await driver.open(tester, target.location, themeMode, wrap);
      await _settle(tester, config);
      if (target.keyboard) {
        // Focus the first text field and raise a keyboard-sized bottom inset,
        // so CTA reachability and overflow with the keyboard open are visible.
        final fields = find.byType(EditableText);
        if (fields.evaluate().isNotEmpty) {
          await tester.showKeyboard(fields.first);
          result['keyboard_focused'] = true;
        } else {
          result['keyboard_focused'] = false;
        }
        tester.view.viewInsets = FakeViewPadding(bottom: config.keyboardInset * device.dpr);
        await _settle(tester, config);
      }
      final landed = driver.snapshot(tester).location;
      if (landed != target.location && landed != target.location.split('?').first) {
        result['redirected_to'] = landed;
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
      ContrastReport? report;
      if (rgba != null) {
        report = measureTextContrast(tester, rgba!, imageW, imageH, scale: config.exportScale);
        result['text_nodes_checked'] = report.checked;
        result['low_contrast'] = report.low.map((e) => e.toJson()).toList();
        result['low_contrast_icons'] = report.lowIcons.map((e) => e.toJson()).toList();
        result['text_without_font_family'] = report.noFontFamily;
        result['contrast_not_measurable'] = report.notMeasurable;
        result['contrast_coverage'] = {
          'found': report.found,
          'measured': report.checked,
          'failed': report.low.length,
          'icons_failed': report.lowIcons.length,
          'not_measurable': report.notMeasurable.length,
          'no_font_family': report.noFontFamily.length,
        };
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
        final visible = Rect.fromLTWH(
          0,
          0,
          device.width,
          device.height - (target.keyboard ? config.keyboardInset : 0),
        );
        final tappables = collectTappables(root, dpr: device.dpr, minTapSize: minTap, visible: visible);
        if (report != null) {
          final (kept, occluded) = splitOccluded(report.low, tappables, screenArea: device.width * device.height);
          if (occluded.isNotEmpty) {
            result['low_contrast'] = kept.map((e) => e.toJson()).toList();
            result['contrast_not_measurable'] = [...report.notMeasurable, ...occluded];
            result['contrast_coverage'] = {
              ...(result['contrast_coverage'] as Map<String, Object?>),
              'failed': kept.length,
              'not_measurable': report.notMeasurable.length + occluded.length,
              'occluded': occluded.length,
            };
          }
        }
        if (explore) {
          result['edges'] = (await _explore(
            tester,
            target: target,
            tappables: tappables,
            themeMode: themeMode,
            config: config,
            driver: driver,
            wrap: (app) => _withInsetBands(app, top: device.safeTop, bottom: device.safeBottom),
            env: env,
          ))
              .map((e) => e.toJson())
              .toList();
        }
        result['tappables_count'] = tappables.length;
        result['tappables_below_min'] = [
          for (final t in tappables)
            if ((t.width < minTap || t.height < minTap) && !t.nestedInLargerTarget && !t.clipped) t.toJson(),
        ];
        result['tappables_clipped'] = [
          for (final t in tappables)
            if (t.clipped) t.toJson(),
        ];
        result['tappables_below_min_nested'] = [
          for (final t in tappables)
            if ((t.width < minTap || t.height < minTap) && t.nestedInLargerTarget) t.toJson(),
        ];
      } else {
        result['semantics'] = null;
      }
    } catch (e, st) {
      failure = '${_firstLine(e.toString())}\n$st';
      result['status'] = 'error';
      result['error'] = _firstLine(e.toString());
    } finally {
      // Let one-shot timers started by the screen or by explore taps fire
      // while the tree is still mounted (see UiMapConfig.drainTimersMs).
      try {
        for (var elapsed = 0; elapsed < config.drainTimersMs; elapsed += 5000) {
          await tester.pump(const Duration(seconds: 5));
        }
        for (var e = tester.takeException(); e != null; e = tester.takeException()) {}
      } catch (_) {}
      handle?.dispose();
      debugDisableShadows = previousShadows;
      debugDefaultTargetPlatformOverride = previousPlatform;
      if (textScale != 1.0) tester.platformDispatcher.clearTextScaleFactorTestValue();
      if (combo.locale != null) {
        tester.platformDispatcher.clearLocalesTestValue();
        tester.platformDispatcher.clearLocaleTestValue();
      }
      tester.view.reset();
      result['duration_ms'] = sw.elapsedMilliseconds;
      _writeJson(p.join(resultsDir.path, '$id.json'), result);
    }
    if (failure != null) {
      if (rethrowFailures) fail('ui_map: $id failed: $failure');
      // ignore: avoid_print
      print('ui_map: $id failed: ${_firstLine(failure)}');
    }
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
    required ScreenDriver driver,
    required AppWrap wrap,
    required _Env env,
  }) async {
    final edges = <NavEdge>[];
    final candidates = tappables
        .where((t) => !t.nestedInLargerTarget && !t.fullScreen)
        .take(config.exploreMaxTaps)
        .toList();
    var unlabeled = 0;
    final frameKey = GlobalKey();
    final outerWrap = wrap;
    wrap = (app) => RepaintBoundary(key: frameKey, child: outerWrap(app));
    for (final t in candidates) {
      final label = t.label.isEmpty ? 'unlabeled#${++unlabeled}' : t.label;
      await _applyScenario(tester, env, target);
      await driver.open(tester, target.location, themeMode, wrap);
      await _settle(tester, config);
      while (tester.takeException() != null) {}
      final before = driver.snapshot(tester);
      final depthBefore = before.depth;
      final from = before.location;
      final semanticsBefore = _semanticsFingerprint(tester);
      String? error;
      final mask = Rect.fromLTWH(t.left - 8, t.top - 8, t.width + 16, t.height + 16);
      final sampler = _FrameSampler(tester, frameKey, mask);
      final busyBefore = await sampler.changedOver(const Duration(milliseconds: 50));
      try {
        // The tap runs in a guarded zone: an `async` handler that throws
        // (e.g. `context.pop()` with nothing to pop) completes an unawaited
        // future with an error, which would otherwise fail the whole test
        // instead of becoming an `error` edge.
        await runZonedGuarded(() async {
          await tester.tapAt(Offset(t.left + t.width / 2, t.top + t.height / 2));
          await tester.pump();
        }, (e, st) => error ??= _firstLine(e.toString()));
        for (var e = tester.takeException(); e != null; e = tester.takeException()) {
          error ??= _firstLine(e.toString());
        }
        await sampler.sample(const Duration(milliseconds: 50), count: 12);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } catch (e) {
        error = _firstLine(e.toString());
      }
      final motion = busyBefore ? _Motion.unknown : sampler.classify();
      final selfMotion = busyBefore ? _Motion.unknown : sampler.classifySelf();
      for (var e = tester.takeException(); e != null; e = tester.takeException()) {
        error ??= _firstLine(e.toString());
      }
      final afterSnap = driver.snapshot(tester);
      final depthAfter = afterSnap.depth;
      final to = afterSnap.location;
      final contentChanged = _semanticsFingerprint(tester) != semanticsBefore;
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
      if (overlay == null && afterSnap.popup) overlay = 'popup';
      if (overlay != null && to != from) overlay = null; // navigation wins
      final kind = classifyEdge(
        from: from,
        to: to,
        depthBefore: depthBefore,
        depthAfter: depthAfter,
        overlay: overlay,
        error: error,
        contentChanged: contentChanged,
      );
      final noEffect = kind == 'no_observed_effect' && motion.kind == 'instant';
      edges.add(NavEdge(
        from: from,
        label: label,
        to: to,
        kind: kind,
        overlay: overlay,
        error: error,
        x: t.left + t.width / 2,
        y: t.top + t.height / 2,
        transition: noEffect ? null : motion.kind,
        transitionMs: motion.ms,
        selfTransition: noEffect ? null : selfMotion.kind,
      ));
    }
    return edges;
  }

  /// Composes `.ui-map/proto/<name>.png` for every `/__proto/<name>` route:
  /// one column per direction (base location + each variant), one row per
  /// theme, first device and platform, text scale 1.0. Lists them in
  /// `PROTO.md`, so a prototype review is one image per screen.
  static Future<void> _protoSheet(WidgetTester tester, _Env env, List<ScreenTarget> protos) async {
    final combos = _combos(env).toList();
    final firstLocale = env.config.locales.isEmpty ? null : env.config.locales.first;
    final rowsCombos = combos
        .where((c) =>
            c.textScale == 1.0 &&
            c.locale == firstLocale &&
            c.device == combos.first.device &&
            c.platform == combos.first.platform)
        .toList();
    final protoDir = Directory(p.join(env.outDir, 'proto'))..createSync(recursive: true);
    final md = StringBuffer('# Prototype directions\n\n');
    final byRoute = <String, List<ScreenTarget>>{};
    for (final t in protos) {
      if (t.keyboard || t.scenario != null) continue;
      byRoute.putIfAbsent(t.routePath, () => []).add(t);
    }
    for (final entry in byRoute.entries) {
      final name = entry.key.substring('/__proto/'.length).replaceAll('/', '_');
      final cols = entry.value;
      final labels = [for (final t in cols) t.location.contains('?') ? t.location.split('?').last : 'default'];
      final grid = <List<ui.Image?>>[];
      for (final c in rowsCombos) {
        final row = <ui.Image?>[];
        for (final t in cols) {
          final f = File(p.join(env.outDir, 'screens', '${_idFor(t, c, firstLocale: true)}.png'));
          if (!f.existsSync()) {
            row.add(null);
            continue;
          }
          final bytes = f.readAsBytesSync();
          row.add(await tester.runAsync(() async {
            final codec = await ui.instantiateImageCodec(bytes);
            return (await codec.getNextFrame()).image;
          }));
        }
        grid.add(row);
      }
      var cellW = 0, cellH = 0;
      for (final img in grid.expand((r) => r).whereType<ui.Image>()) {
        if (img.width > cellW) cellW = img.width;
        if (img.height > cellH) cellH = img.height;
      }
      if (cellW == 0) continue;
      const gutter = 24.0, header = 40.0;
      final w = cols.length * cellW + (cols.length + 1) * gutter;
      final h = grid.length * (cellH + header + gutter) + gutter;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFE6E6E6));
      for (var r = 0; r < grid.length; r++) {
        for (var col = 0; col < cols.length; col++) {
          final x = gutter + col * (cellW + gutter);
          final y = gutter + r * (cellH + header + gutter);
          final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 22))
            ..pushStyle(ui.TextStyle(color: const Color(0xFF222222)))
            ..addText('${labels[col]} · ${rowsCombos[r].theme}');
          final para = pb.build()..layout(ui.ParagraphConstraints(width: cellW.toDouble()));
          canvas.drawParagraph(para, Offset(x, y + 6));
          final img = grid[r][col];
          if (img != null) canvas.drawImage(img, Offset(x, y + header), Paint());
        }
      }
      final picture = rec.endRecording();
      final png = await tester.runAsync(() async {
        final sheet = await picture.toImage(w.toInt(), h.toInt());
        return sheet.toByteData(format: ui.ImageByteFormat.png);
      });
      if (png == null) continue;
      File(p.join(protoDir.path, '$name.png')).writeAsBytesSync(png.buffer.asUint8List());
      md
        ..writeln('## $name')
        ..writeln()
        ..writeln('![$name](proto/$name.png)')
        ..writeln()
        ..writeln('Columns: ${labels.join(' · ')}. Rows: ${rowsCombos.map((c) => c.theme).join(', ')}. '
            'Route `${entry.key}`; individual PNGs under `screens/`.')
        ..writeln();
    }
    File(p.join(env.outDir, 'PROTO.md')).writeAsStringSync(md.toString());
  }

  /// Cheap fingerprint of what assistive tech would read: labels, values,
  /// flags and rects, without object ids. Changes when a filter is applied,
  /// a page scrolls, an item expands or a field gets text.
  static String _semanticsFingerprint(WidgetTester tester) {
    final renderView = tester.binding.renderViews.firstWhere((r) => r.flutterView == tester.view);
    final root = renderView.owner?.semanticsOwner?.rootSemanticsNode;
    if (root == null) return '';
    final dump = root.toStringDeep().replaceAll(RegExp(r'#[0-9a-f]{5}\b'), '');
    return sha256.convert(utf8.encode(dump)).toString();
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

  /// Fixed pumps (never pumpAndSettle), optionally letting real async I/O
  /// complete in between so network-backed screens settle.
  static Future<void> _settle(WidgetTester tester, UiMapConfig config) async {
    const step = Duration(milliseconds: 100);
    final steps = (config.settleMs / 100).ceil().clamp(1, 600);
    for (var i = 0; i < steps; i++) {
      await tester.pump(step);
    }
    if (config.realAsyncMs > 0) {
      for (var round = 0; round < 2; round++) {
        await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: config.realAsyncMs)));
        for (var i = 0; i < steps; i++) {
          await tester.pump(step);
        }
      }
    }
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

class _Combo {
  const _Combo({
    required this.device,
    required this.theme,
    required this.platform,
    required this.textScale,
    required this.explore,
    this.locale,
  });

  final DeviceSpec device;
  final String theme;
  final String platform;
  final double textScale;
  final bool explore;
  final String? locale;

  String get id =>
      '${device.name}__${theme}__$platform${textScale == 1.0 ? '' : '__x$textScale'}${locale == null ? '' : '__$locale'}';
}

class _Env {
  _Env({
    required this.projectRoot,
    required this.configPath,
    required this.config,
    required this.outDir,
    required this.mode,
    required this.explore,
    this.scenarios = const {},
    this.resetScenario,
  });

  final String projectRoot;
  final String configPath;
  final UiMapConfig config;
  final String outDir;
  final String mode;
  final bool explore;
  final Map<String, ScenarioSetup> scenarios;
  final ScenarioReset? resetScenario;

  static _Env read({
    String? outDirOverride,
    Map<String, ScenarioSetup> scenarios = const {},
    ScenarioReset? resetScenario,
  }) {
    TestWidgetsFlutterBinding.ensureInitialized();
    const outEnv = String.fromEnvironment('UI_MAP_OUT');
    const cfgEnv = String.fromEnvironment('UI_MAP_CONFIG');
    const mode = String.fromEnvironment('UI_MAP_MODE', defaultValue: 'capture');
    const exploreEnv = String.fromEnvironment('UI_MAP_EXPLORE');
    final projectRoot = Directory.current.path;
    final configPath = cfgEnv.isEmpty ? p.join(projectRoot, 'ui_map.yaml') : cfgEnv;
    final config = UiMapConfig.load(configPath);
    final outDir = outDirOverride ?? (outEnv.isEmpty ? p.join(projectRoot, config.outDir) : outEnv);
    Directory(outDir).createSync(recursive: true);
    return _Env(
      projectRoot: projectRoot,
      configPath: configPath,
      config: config,
      outDir: outDir,
      mode: mode,
      explore: exploreEnv == 'true' || (exploreEnv.isEmpty && config.explore),
      scenarios: scenarios,
      resetScenario: resetScenario,
    );
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
  const ContrastReport({
    required this.checked,
    required this.low,
    this.found = 0,
    this.lowIcons = const [],
    this.noFontFamily = const [],
    this.notMeasurable = const [],
  });

  /// Text paragraphs found on the screen (icons and skipped ones included).
  final int found;

  /// Paragraphs actually measured. `found - checked` were skipped for the
  /// reasons listed in [notMeasurable] / [noFontFamily] or are icons.
  final int checked;
  final List<LowContrast> low;

  /// Texts that could not be measured, with the reason. Absence from [low]
  /// never means "passed" for these.
  final List<Map<String, Object?>> notMeasurable;

  /// Icon glyphs (private-use codepoints) below 3:1.
  final List<LowContrast> lowIcons;

  /// Texts whose TextStyle resolves to no font family: drawn as blocks in
  /// the capture, platform font on device.
  final List<Map<String, Object?>> noFontFamily;
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
  var found = 0;
  final low = <LowContrast>[];
  final icons = <LowContrast>[];
  final noFamily = <Map<String, Object?>>[];
  final notMeasurable = <Map<String, Object?>>[];
  final seen = <String>{};
  void skip(String text, String reason, [Rect? rect]) {
    notMeasurable.add({
      'text': text.length > 40 ? '${text.substring(0, 40)}…' : text,
      'reason': reason,
      if (rect != null) 'x': Tappable._r(rect.left),
      if (rect != null) 'y': Tappable._r(rect.top),
    });
  }

  for (final element in find.byType(RichText).evaluate()) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    final span = ro.text;
    final plain = span.toPlainText().trim();
    if (plain.isEmpty) continue;
    found++;
    final isIcon = plain.runes.length == 1 && _isPrivateUse(plain.runes.first);
    final style = _firstStyle(span);
    final color = style?.color;
    final offset = ro.localToGlobal(Offset.zero);
    final rect = offset & ro.size;
    if (color == null) {
      skip(plain, 'no colour in TextStyle (inherited from painter/theme at paint time)', rect);
      continue;
    }
    if (rect.isEmpty || rect.width < 2 || rect.height < 2) {
      skip(plain, 'rect too small or off-screen', rect);
      continue;
    }
    final key = '$plain|${rect.left.round()}|${rect.top.round()}';
    if (!seen.add(key)) continue;
    if (_hasMultipleColours(span)) {
      skip(plain, 'multiple span colours; only the first is measured', rect);
      // still measured below with the first colour, but flagged as partial
    }
    // No font family resolved: under `flutter test` this renders with the
    // FlutterTest font (solid blocks), so contrast is meaningless. Report
    // it instead: on device the platform font is used, and the text will
    // not follow the app's font family.
    if (!isIcon && (style?.fontFamily == null || style!.fontFamily!.isEmpty)) {
      noFamily.add({
        'text': plain.length > 40 ? '${plain.substring(0, 40)}…' : plain,
        'x': Tappable._r(rect.left),
        'y': Tappable._r(rect.top),
        'width': Tappable._r(rect.width),
        'height': Tappable._r(rect.height),
      });
      continue;
    }
    final argb = color.toARGB32();
    final left = (rect.left * scale).round(), top = (rect.top * scale).round();
    final w = (rect.width * scale).round(), h = (rect.height * scale).round();
    final fgOpaque = argb & 0xFFFFFF;
    final bg = sampleBackground(rgba, imageW, imageH, left: left, top: top, width: w, height: h, foreground: fgOpaque);
    if (bg == null) {
      skip(plain, 'background not distinguishable from text pixels', rect);
      continue;
    }
    final fg = compositeOver(argb, bg);
    final ratio = contrastRatio(fg, bg);
    final fontSize = style?.fontSize ?? 14;
    final bold = (style?.fontWeight?.value ?? 400) >= FontWeight.w700.value;
    // Icons are non-text UI: WCAG 1.4.11 asks 3:1.
    final required = isIcon ? 3.0 : requiredContrast(fontSize: fontSize, bold: bold);
    if (isIcon) {
      if (ratio < required) {
        icons.add(LowContrast(
          text: 'icon U+${plain.runes.first.toRadixString(16).toUpperCase()}',
          ratio: ratio,
          required: required,
          foreground: fg,
          background: bg,
          fontSize: fontSize,
          rect: rect,
        ));
      }
      continue;
    }
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
  icons.sort((a, b) => a.ratio.compareTo(b.ratio));
  return ContrastReport(
    checked: checked,
    found: found,
    low: low,
    lowIcons: icons,
    noFontFamily: noFamily,
    notMeasurable: notMeasurable,
  );
}

bool _hasMultipleColours(InlineSpan span) {
  final colours = <int>{};
  void walk(InlineSpan s) {
    final c = s.style?.color;
    if (c != null) colours.add(c.toARGB32());
    if (s is TextSpan) s.children?.forEach(walk);
  }

  walk(span);
  return colours.length > 1;
}

bool _isPrivateUse(int rune) =>
    (rune >= 0xE000 && rune <= 0xF8FF) || (rune >= 0xF0000 && rune <= 0x10FFFD);

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
    this.fullScreen = false,
    this.clipped = false,
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

  /// Covers 90%+ of the screen: a tap catcher, skipped by explore.
  final bool fullScreen;

  /// The visible rect is cut by the edge of its scroll view or of the
  /// viewport (keyboard inset): a chip half scrolled away, a field under the
  /// keyboard. Its real size is unknown, so it is not a small-target finding.
  final bool clipped;

  Map<String, Object?> toJson() => {
        'label': label,
        'x': _r(left),
        'y': _r(top),
        'width': _r(width),
        'height': _r(height),
        'nested_in_larger_target': nestedInLargerTarget,
        if (fullScreen) 'full_screen': true,
        if (clipped) 'clipped': true,
      };

  static double _r(double v) => (v * 10).roundToDouble() / 10;
}

/// Walks the semantics tree accumulating transforms; rects come out in
/// physical pixels (the root is the RenderView), so divide by [dpr].
List<Tappable> collectTappables(
  SemanticsNode root, {
  required double dpr,
  double minTapSize = 48,
  Rect? visible,
}) {
  final out = <Tappable>[];
  final seen = <String>{};
  final screen = root.rect;
  final screenArea = screen.width * screen.height / (dpr * dpr);
  final rootClip = _ClipInfo(
    hRect: null,
    vRect: visible ?? Rect.fromLTWH(0, 0, screen.width / dpr, screen.height / dpr),
  );
  void walk(SemanticsNode n, Matrix4 parent, Rect? enclosingTarget, _ClipInfo clip) {
    final m = n.transform == null ? parent : (parent.clone()..multiply(n.transform!));
    final data = n.getSemanticsData();
    final hidden = n.flagsCollection.isHidden;
    var enclosing = enclosingTarget;
    var innerClip = clip;
    final scrollsH = data.hasAction(SemanticsAction.scrollLeft) || data.hasAction(SemanticsAction.scrollRight);
    final scrollsV = data.hasAction(SemanticsAction.scrollUp) || data.hasAction(SemanticsAction.scrollDown);
    if ((scrollsH || scrollsV) && !n.rect.isEmpty) {
      final sr = MatrixUtils.transformRect(m, n.rect);
      final srl = Rect.fromLTWH(sr.left / dpr, sr.top / dpr, sr.width / dpr, sr.height / dpr);
      innerClip = _ClipInfo(
        hRect: scrollsH ? (clip.hRect == null ? srl : srl.intersect(clip.hRect!)) : clip.hRect,
        vRect: scrollsV ? (clip.vRect == null ? srl : srl.intersect(clip.vRect!)) : clip.vRect,
      );
    }
    if (!hidden && data.hasAction(SemanticsAction.tap) && !n.rect.isEmpty) {
      final r = MatrixUtils.transformRect(m, n.rect);
      final logical = Rect.fromLTWH(r.left / dpr, r.top / dpr, r.width / dpr, r.height / dpr);
      final h = clip.hRect, v = clip.vRect;
      final clipped = (h != null &&
              logical.width < minTapSize &&
              (logical.left <= h.left + 0.5 || logical.right >= h.right - 0.5)) ||
          (v != null &&
              logical.height < minTapSize &&
              (logical.top <= v.top + 0.5 || logical.bottom >= v.bottom - 0.5));
      final nested = enclosingTarget != null &&
          enclosingTarget.contains(logical.topLeft) &&
          enclosingTarget.contains(logical.bottomRight - const Offset(0.01, 0.01));
      // A target covering (almost) the whole screen is a tap catcher
      // (dismiss keyboard, close overlay), not a parent control: it must not
      // mark everything inside it as nested, and it is not worth exploring.
      final fullScreen = screenArea > 0 && logical.width * logical.height >= screenArea * 0.9;
      if (!fullScreen && logical.width >= minTapSize && logical.height >= minTapSize) enclosing = logical;
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
          fullScreen: fullScreen,
          clipped: clipped,
        ));
      }
    }
    n.visitChildren((c) {
      walk(c, m, enclosing, innerClip);
      return true;
    });
  }

  walk(root, Matrix4.identity(), null, rootClip);
  return out;
}

/// Nearest clipping rects per axis: the innermost horizontal scroll view
/// (if any) and the innermost vertical scroll view or the viewport.
class _ClipInfo {
  const _ClipInfo({required this.hRect, required this.vRect});
  final Rect? hRect;
  final Rect? vRect;
}

/// Splits low-contrast findings into real ones and texts whose sampled
/// background was another surface painted over them (a FAB or a sticky
/// button crossing the text rect, or a ratio no designer would ship).
/// Returns the kept findings and the not-measurable entries.
(List<LowContrast>, List<Map<String, Object?>>) splitOccluded(
  List<LowContrast> low,
  List<Tappable> tappables, {
  required double screenArea,
}) {
  final kept = <LowContrast>[];
  final occluded = <Map<String, Object?>>[];
  for (final lc in low) {
    String? reason;
    for (final t in tappables) {
      if (t.fullScreen) continue;
      final tr = Rect.fromLTWH(t.left, t.top, t.width, t.height);
      final area = t.width * t.height;
      if (area <= 0 || area > screenArea * 0.5) continue;
      if (!tr.overlaps(lc.rect)) continue;
      final containsText = tr.contains(lc.rect.topLeft) && tr.contains(lc.rect.bottomRight - const Offset(0.01, 0.01));
      if (containsText) continue;
      reason = 'occluded by "${t.label}"';
      break;
    }
    if (reason == null && lc.ratio < 1.3) reason = 'implausible ratio: text probably covered by another surface';
    if (reason == null) {
      kept.add(lc);
    } else {
      occluded.add({...lc.toJson(), 'reason': reason, 'status': 'suspected'});
    }
  }
  return (kept, occluded);
}


/// Result of [_FrameSampler.classify].
class _Motion {
  const _Motion(this.kind, [this.ms]);
  static const unknown = _Motion('unknown');
  final String kind;
  final int? ms;
}

/// Samples the explore boundary as raw RGBA at logical resolution and
/// compares consecutive frames outside a masked rect (the tapped target, so
/// ink ripples are ignored). Cheap enough to run for every explored tap.
class _FrameSampler {
  _FrameSampler(this.tester, this.key, this.mask);
  final WidgetTester tester;
  final GlobalKey key;
  final Rect mask;
  final List<bool> _changes = [];
  final List<bool> _selfChanges = [];
  Uint8List? _last;
  int _width = 0;
  int _height = 0;

  Future<Uint8List?> _grab() async {
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary || ro.debugNeedsPaint) return null;
    final bytes = await tester.runAsync(() async {
      final img = await ro.toImage(pixelRatio: 1.0);
      _width = img.width;
      _height = img.height;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      return data?.buffer.asUint8List();
    });
    return bytes;
  }

  /// Pixels inside the masked rect changed (the control's own animation).
  bool _differsInside(Uint8List a, Uint8List b) {
    if (a.length != b.length) return true;
    final x0 = mask.left.floor().clamp(0, _width), x1 = mask.right.ceil().clamp(0, _width);
    final y0 = mask.top.floor().clamp(0, _height), y1 = mask.bottom.ceil().clamp(0, _height);
    final stride = _width * 4;
    for (var y = y0; y < y1; y++) {
      final row = y * stride;
      for (var x = x0; x < x1; x++) {
        final i = row + x * 4;
        if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) return true;
      }
    }
    return false;
  }

  bool _differs(Uint8List a, Uint8List b) {
    if (a.length != b.length) return true;
    final x0 = mask.left.floor().clamp(0, _width), x1 = mask.right.ceil().clamp(0, _width);
    final y0 = mask.top.floor().clamp(0, _height), y1 = mask.bottom.ceil().clamp(0, _height);
    final stride = _width * 4;
    for (var y = 0; y < _height; y++) {
      final row = y * stride;
      final masked = y >= y0 && y < y1;
      for (var x = 0; x < _width; x++) {
        if (masked && x >= x0 && x < x1) continue;
        final i = row + x * 4;
        if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) return true;
      }
    }
    return false;
  }

  /// Two frames [gap] apart before the tap: true when the screen is already
  /// animating on its own.
  Future<bool> changedOver(Duration gap) async {
    final a = await _grab();
    await tester.pump(gap);
    final b = await _grab();
    _last = b;
    return a != null && b != null && _differs(a, b);
  }

  /// Pumps [count] frames [step] apart after the tap and records which of
  /// them differ from the previous one.
  Future<void> sample(Duration step, {required int count}) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
      final f = await _grab();
      if (f == null || _last == null || f.length != _last!.length) {
        _changes.add(false);
        _selfChanges.add(false);
      } else {
        _changes.add(_differs(_last!, f));
        _selfChanges.add(_differsInside(_last!, f));
      }
      if (f != null) _last = f;
    }
  }

  _Motion classify() => _classify(_changes);

  /// Same classification for the tapped control itself: a switch, chip or
  /// bookmark that flips with no motion is `instant` here. Ink ripples make
  /// most Material controls `animated`, so this is only informative.
  _Motion classifySelf() => _classify(_selfChanges);

  static _Motion _classify(List<bool> changes) {
    if (changes.isEmpty) return _Motion.unknown;
    final first = changes.indexOf(true);
    if (first < 0) return const _Motion('instant');
    final last = changes.lastIndexOf(true);
    if (changes.length >= 2 && changes[changes.length - 1] && changes[changes.length - 2]) {
      return const _Motion('continuous');
    }
    var consecutive = false;
    for (var i = 1; i < changes.length; i++) {
      if (changes[i] && changes[i - 1]) consecutive = true;
    }
    if (!consecutive) return const _Motion('instant');
    return _Motion('animated', (last - first + 1) * 50);
  }
}
