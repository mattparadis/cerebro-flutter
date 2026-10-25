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
  });

  /// Values substituted for `:param` segments.
  final Map<String, String> params;

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
    this.settleMs = 600,
    this.exportScale = 2,
    this.minTapSize = 48,
    this.routes = const {},
    this.exclude = const [],
    this.fonts = const {},
    this.outDir = '.ui-map',
  });

  final List<DeviceSpec> devices;
  final List<String> themes;
  final List<String> platforms;
  final int settleMs;
  final double exportScale;
  final double minTapSize;
  final Map<String, RouteOptions> routes;
  final List<String> exclude;

  /// family -> font file paths (absolute, project-relative, or asset keys).
  final Map<String, List<String>> fonts;
  final String outDir;

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
      settleMs: (m['settle_ms'] as num?)?.toInt() ?? d.settleMs,
      exportScale: (m['export_scale'] as num?)?.toDouble() ?? d.exportScale,
      minTapSize: (m['min_tap_size'] as num?)?.toDouble() ?? d.minTapSize,
      routes: routes,
      exclude: _strings(m['exclude']) ?? const [],
      fonts: fonts,
      outDir: '${m['out_dir'] ?? d.outDir}',
    );
  }

  Map<String, Object?> toJson() => {
        'devices': devices.map((d) => d.toJson()).toList(),
        'themes': themes,
        'platforms': platforms,
        'settle_ms': settleMs,
        'export_scale': exportScale,
        'min_tap_size': minTapSize,
        'routes': {
          for (final e in routes.entries)
            e.key: {
              'params': e.value.params,
              'variants': e.value.variants,
              'skip': e.value.skip,
            },
        },
        'exclude': exclude,
        'fonts': fonts,
        'out_dir': outDir,
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
