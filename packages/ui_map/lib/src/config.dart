import 'dart:io';

import 'package:yaml/yaml.dart';

/// A logical screen size the app is rendered at.
class DeviceSpec {
  const DeviceSpec({
    required this.name,
    required this.width,
    required this.height,
    required this.dpr,
    this.safeTop = 24,
    this.safeBottom = 24,
  });

  final String name;
  final double width;
  final double height;
  final double dpr;

  /// System insets in dp (status bar / navigation bar). Applied as the
  /// view padding so `SafeArea` and `MediaQuery.padding` behave as on a
  /// device, and drawn as translucent bands on the screenshot.
  final double safeTop;
  final double safeBottom;

  Map<String, Object?> toJson() => {
        'name': name,
        'width': width,
        'height': height,
        'dpr': dpr,
        'safe_area': {'top': safeTop, 'bottom': safeBottom},
      };
}

/// Per-route options from `ui_map.yaml`.
class RouteOptions {
  const RouteOptions({
    this.params = const {},
    this.variants = const [],
    this.skip = false,
    this.args,
    this.scenarios = const [],
    this.keyboard = false,
  });

  /// Values substituted for `:param` segments.
  final Map<String, String> params;

  /// Navigator 1.0 only: `Navigator.pushNamed(..., arguments:)` payload
  /// (a YAML map/list/scalar) used when the factory gives none.
  final Object? args;

  /// Names of factory scenarios to capture this route under, in addition
  /// to the default (no scenario). Each one becomes a screen with an
  /// `__s-<name>` id suffix.
  final List<String> scenarios;

  /// Also capture this route with the soft keyboard open (first text field
  /// focused, bottom view inset = `keyboard_inset`), id suffix `__kb`.
  final bool keyboard;

  /// Query strings (e.g. `?state=empty`) appended as extra locations.
  /// The plain location is always captured too.
  final List<String> variants;

  final bool skip;
}

class UiMapConfig {
  const UiMapConfig({
    this.devices = const [DeviceSpec(name: 'phone', width: 393, height: 852, dpr: 3)],
    this.themes = const ['light', 'dark'],
    this.platforms = const ['android'],
    this.textScales = const [1.0],
    this.settleMs = 600,
    this.realAsyncMs = 0,
    this.exportScale = 2,
    this.minTapSize = 48,
    this.minTapSizeByPlatform = const {'ios': 44, 'macos': 44},
    this.keyboardInset = 300,
    this.locales = const [],
    this.routes = const {},
    this.exclude = const [],
    this.fonts = const {},
    this.outDir = '.ui-map',
    this.lintExclude,
    this.lintRules = const {},
    this.explore = false,
    this.exploreMaxTaps = 40,
    this.defaultScenario,
  });

  final List<DeviceSpec> devices;
  final List<String> themes;
  final List<String> platforms;

  /// Text scale factors to capture (1.0 = default). Ids get a `__x1.3`
  /// suffix for scales other than 1.0.
  final List<double> textScales;
  final int settleMs;

  /// When > 0, after the settle pumps the harness waits this many real
  /// milliseconds inside `tester.runAsync` and pumps again, so that real
  /// I/O (HTTP, which flutter_test answers with 400, file reads) can
  /// complete and screens reach their loaded/error state instead of
  /// spinning forever in the fake-async zone.
  final int realAsyncMs;
  final double exportScale;

  /// Default minimum tap target (dp). Material: 48.
  final double minTapSize;

  /// Per-platform overrides; Apple HIG: 44 pt. `min_tap_size` in the yaml
  /// accepts a number or a map `{android: 48, ios: 44}`.
  final Map<String, double> minTapSizeByPlatform;

  /// Simulated keyboard height (dp) for routes with `keyboard: true`.
  final double keyboardInset;

  /// Locales to capture (BCP 47, e.g. `[en, it, ar]`); the first is the
  /// default and gets no id suffix. Applied through the platform locale, so
  /// apps that force `MaterialApp.locale` ignore it.
  final List<String> locales;

  double minTapSizeFor(String platform) => minTapSizeByPlatform[platform] ?? minTapSize;
  final Map<String, RouteOptions> routes;
  final List<String> exclude;

  /// family -> font file paths (absolute, project-relative, or asset keys).
  final Map<String, List<String>> fonts;
  final String outDir;

  /// `lint.exclude` globs (null = lint defaults) and `lint.rules` id -> bool.
  final List<String>? lintExclude;
  final Map<String, bool> lintRules;

  /// Tap every semantics target of each screen and record where it leads.
  final bool explore;
  final int exploreMaxTaps;

  /// Factory scenario applied to every screen that names none (e.g.
  /// `logged-in`). Screens still get no `__s-` suffix for it.
  final String? defaultScenario;

  static UiMapConfig load(String path) {
    final file = File(path);
    if (!file.existsSync()) return const UiMapConfig();
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) return const UiMapConfig();
    return fromMap(_deep(doc) as Map<String, Object?>);
  }

  static UiMapConfig fromMap(Map<String, Object?> m) {
    const d = UiMapConfig();
    final devices = (m['devices'] as List?)
        ?.map((e) => e as Map)
        .map((e) {
          final safe = e['safe_area'];
          return DeviceSpec(
            name: '${e['name'] ?? 'phone'}',
            width: (e['width'] as num? ?? 393).toDouble(),
            height: (e['height'] as num? ?? 852).toDouble(),
            dpr: (e['dpr'] as num? ?? 3).toDouble(),
            safeTop: (safe is Map ? safe['top'] as num? : null)?.toDouble() ?? 24,
            safeBottom: (safe is Map ? safe['bottom'] as num? : null)?.toDouble() ?? 24,
          );
        })
        .toList();
    final routes = <String, RouteOptions>{};
    final rawRoutes = m['routes'];
    if (rawRoutes is Map) {
      for (final entry in rawRoutes.entries) {
        final v = entry.value;
        if (v is! Map) {
          routes['${entry.key}'] = const RouteOptions();
          continue;
        }
        routes['${entry.key}'] = RouteOptions(
          params: {
            for (final p in ((v['params'] as Map?) ?? {}).entries) '${p.key}': '${p.value}',
          },
          variants: [for (final s in (v['variants'] as List?) ?? []) '$s'],
          skip: v['skip'] == true,
          args: v['args'],
          scenarios: [for (final n in (v['scenarios'] as List?) ?? []) '$n'],
          keyboard: v['keyboard'] == true,
        );
      }
    }
    final fonts = <String, List<String>>{};
    final rawFonts = m['fonts'];
    if (rawFonts is Map) {
      for (final e in rawFonts.entries) {
        fonts['${e.key}'] = [for (final f in (e.value as List?) ?? []) '$f'];
      }
    }
    return UiMapConfig(
      devices: devices == null || devices.isEmpty ? d.devices : devices,
      themes: _strings(m['themes']) ?? d.themes,
      platforms: _strings(m['platforms']) ?? d.platforms,
      textScales: (m['text_scales'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? d.textScales,
      settleMs: (m['settle_ms'] as num?)?.toInt() ?? d.settleMs,
      realAsyncMs: (m['real_async_ms'] as num?)?.toInt() ?? d.realAsyncMs,
      exportScale: (m['export_scale'] as num?)?.toDouble() ?? d.exportScale,
      minTapSize: m['min_tap_size'] is num ? (m['min_tap_size'] as num).toDouble() : d.minTapSize,
      minTapSizeByPlatform: m['min_tap_size'] is Map
          ? {for (final e in (m['min_tap_size'] as Map).entries) '${e.key}': (e.value as num).toDouble()}
          : d.minTapSizeByPlatform,
      keyboardInset: (m['keyboard_inset'] as num?)?.toDouble() ?? d.keyboardInset,
      locales: _strings(m['locales']) ?? d.locales,
      routes: routes,
      exclude: _strings(m['exclude']) ?? const [],
      fonts: fonts,
      outDir: '${m['out_dir'] ?? d.outDir}',
      explore: m['explore'] == true,
      defaultScenario: m['default_scenario'] == null ? null : '${m['default_scenario']}',
      exploreMaxTaps: (m['explore_max_taps'] as num?)?.toInt() ?? d.exploreMaxTaps,
      lintExclude: _strings((m['lint'] as Map?)?['exclude']),
      lintRules: {
        for (final e in (((m['lint'] as Map?)?['rules'] as Map?) ?? {}).entries) '${e.key}': e.value == true,
      },
    );
  }

  Map<String, Object?> toJson() => {
        'devices': devices.map((d) => d.toJson()).toList(),
        'themes': themes,
        'platforms': platforms,
        'text_scales': textScales,
        'settle_ms': settleMs,
        'real_async_ms': realAsyncMs,
        'export_scale': exportScale,
        'min_tap_size': minTapSize,
        'min_tap_size_by_platform': minTapSizeByPlatform,
        'keyboard_inset': keyboardInset,
        'locales': locales,
        'routes': {
          for (final e in routes.entries)
            e.key: {
              'params': e.value.params,
              'variants': e.value.variants,
              'skip': e.value.skip,
              if (e.value.args != null) 'args': e.value.args,
              if (e.value.scenarios.isNotEmpty) 'scenarios': e.value.scenarios,
              if (e.value.keyboard) 'keyboard': true,
            },
        },
        'exclude': exclude,
        'fonts': fonts,
        'out_dir': outDir,
        'lint': {'exclude': lintExclude, 'rules': lintRules},
        'explore': explore,
        'explore_max_taps': exploreMaxTaps,
        if (defaultScenario != null) 'default_scenario': defaultScenario,
      };

  static List<String>? _strings(Object? v) =>
      v is List ? [for (final s in v) '$s'] : null;

  static Object? _deep(Object? v) {
    if (v is YamlMap) {
      return {for (final e in v.entries) '${e.key}': _deep(e.value)};
    }
    if (v is YamlList) return [for (final e in v) _deep(e)];
    return v;
  }
}
