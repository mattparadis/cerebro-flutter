import 'package:go_router/go_router.dart';

import 'config.dart';

/// One route in the app's route tree, with its full path.
class RouteNode {
  RouteNode({
    required this.kind,
    required this.path,
    required this.name,
    required this.children,
  });

  /// `route`, `shell`, `stateful_shell`, `branch`.
  final String kind;

  /// Full path for `route` nodes (e.g. `/notes/:id`); null for shells.
  final String? path;
  final String? name;
  final List<RouteNode> children;

  bool get hasParams => path != null && path!.contains(':');

  Map<String, Object?> toJson() => {
        'kind': kind,
        if (path != null) 'path': path,
        if (name != null) 'name': name,
        if (children.isNotEmpty) 'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Walks `router.configuration.routes`. For [StatefulShellRoute] only
/// `branches[].routes` is visited: its `routes` getter is already the
/// flattened union of all branches.
List<RouteNode> enumerateRoutes(GoRouter router) {
  final config = router.configuration;

  RouteNode visit(RouteBase route) {
    if (route is GoRoute) {
      return RouteNode(
        kind: 'route',
        path: config.locationForRoute(route),
        name: route.name,
        children: route.routes.map(visit).toList(),
      );
    }
    if (route is StatefulShellRoute) {
      return RouteNode(
        kind: 'stateful_shell',
        path: null,
        name: null,
        children: [
          for (final branch in route.branches)
            RouteNode(
              kind: 'branch',
              path: null,
              name: null,
              children: branch.routes.map(visit).toList(),
            ),
        ],
      );
    }
    if (route is ShellRoute) {
      return RouteNode(
        kind: 'shell',
        path: null,
        name: null,
        children: route.routes.map(visit).toList(),
      );
    }
    // Unknown RouteBase subclass: still descend.
    return RouteNode(
      kind: route.runtimeType.toString(),
      path: null,
      name: null,
      children: route.routes.map(visit).toList(),
    );
  }

  return config.routes.map(visit).toList();
}

/// Builds a tree from flat route names by path prefix: `/account/payments`
/// becomes a child of `/account` when that exists, else of the root.
/// Used for Navigator 1.0 apps, whose `routes` map is flat.
List<RouteNode> treeFromPaths(Iterable<String> paths) {
  final sorted = paths.toSet().toList()..sort();
  final nodes = <String, RouteNode>{};
  final roots = <RouteNode>[];
  for (final path in sorted) {
    final node = RouteNode(kind: 'route', path: path, name: null, children: []);
    nodes[path] = node;
    RouteNode? parent;
    var prefix = path;
    while (prefix.contains('/') && prefix != '/') {
      prefix = prefix.substring(0, prefix.lastIndexOf('/'));
      if (prefix.isEmpty) prefix = '/';
      if (nodes.containsKey(prefix) && prefix != path) {
        parent = nodes[prefix];
        break;
      }
      if (prefix == '/') break;
    }
    (parent?.children ?? roots).add(node);
  }
  return roots;
}

/// Flat list of `route` nodes in tree order.
List<RouteNode> flattenRoutes(List<RouteNode> tree) {
  final out = <RouteNode>[];
  void walk(RouteNode n) {
    if (n.kind == 'route') out.add(n);
    n.children.forEach(walk);
  }

  tree.forEach(walk);
  return out;
}

/// A concrete location to render.
class ScreenTarget {
  const ScreenTarget({
    required this.routePath,
    required this.routeName,
    required this.location,
    this.skippedReason,
    this.scenario,
    this.keyboard = false,
  });

  final String routePath;
  final String? routeName;
  final String location;

  /// Factory scenario to set up before opening the screen; null = default.
  final String? scenario;

  /// Capture with the soft keyboard open.
  final bool keyboard;

  /// Non-null when the route cannot be rendered (missing params, excluded).
  final String? skippedReason;

  bool get skipped => skippedReason != null;
}

/// Expands routes into locations using config params / variants / exclusions.
List<ScreenTarget> expandTargets(List<RouteNode> tree, CerebroConfig config) {
  final targets = <ScreenTarget>[];
  for (final r in flattenRoutes(tree)) {
    final path = r.path!;
    final opts = config.routes[path] ?? const RouteOptions();
    if (opts.skip || config.exclude.contains(path)) {
      targets.add(ScreenTarget(
        routePath: path,
        routeName: r.name,
        location: path,
        skippedReason: 'excluded in cerebro.yaml',
      ));
      continue;
    }
    final missing = <String>[];
    final keys = <String>[];
    for (final m in RegExp(r':(\w+)').allMatches(path)) {
      final key = m.group(1)!;
      keys.add(key);
      if (opts.params[key] == null || opts.params[key]!.isEmpty) missing.add(key);
    }
    if (missing.isNotEmpty) {
      targets.add(ScreenTarget(
        routePath: path,
        routeName: r.name,
        location: path,
        skippedReason: 'missing params: ${missing.join(', ')} (add routes."$path".params in cerebro.yaml)',
      ));
      continue;
    }
    // Cartesian product of the param values; the first combination is primary.
    var combos = <Map<String, String>>[{}];
    for (final key in keys) {
      combos = [
        for (final c in combos)
          for (final v in opts.params[key]!) {...c, key: v},
      ];
    }
    String fill(Map<String, String> c) =>
        path.replaceAllMapped(RegExp(r':(\w+)'), (m) => c[m.group(1)!]!);
    final location = fill(combos.first);
    targets.add(ScreenTarget(routePath: path, routeName: r.name, location: location));
    for (final c in combos.skip(1)) {
      targets.add(ScreenTarget(routePath: path, routeName: r.name, location: fill(c)));
    }
    for (final v in opts.variants) {
      final suffix = v.startsWith('?') ? v : '?$v';
      targets.add(ScreenTarget(routePath: path, routeName: r.name, location: '$location$suffix'));
    }
    for (final sc in opts.scenarios) {
      targets.add(ScreenTarget(routePath: path, routeName: r.name, location: location, scenario: sc));
    }
    if (opts.keyboard) {
      targets.add(ScreenTarget(routePath: path, routeName: r.name, location: location, keyboard: true));
    }
  }
  return targets;
}

/// Id-safe form of a scenario name.
String slugForScenario(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '-');

/// File-system safe id for a location: `/notes?state=empty` -> `notes__state-empty`,
/// `/` -> `root`, `/notes/1` -> `notes_1`.
String slugForLocation(String location) {
  var s = location;
  if (s.startsWith('/')) s = s.substring(1);
  if (s.isEmpty) return 'root';
  final parts = s.split('?');
  var slug = parts.first.isEmpty ? 'root' : parts.first.replaceAll('/', '_');
  if (parts.length > 1 && parts[1].isNotEmpty) {
    slug += '__${parts[1].replaceAll('=', '-').replaceAll('&', '_')}';
  }
  slug = slug.replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '-');
  return slug;
}
