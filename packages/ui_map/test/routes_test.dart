import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_map/ui_map.dart';

GoRouter _fixtureRouter() {
  Widget page(BuildContext c, GoRouterState s) => const SizedBox();
  return GoRouter(
    routes: [
      GoRoute(path: '/', name: 'home', builder: page),
      GoRoute(
        path: '/items',
        builder: page,
        routes: [
          GoRoute(path: ':id', name: 'item', builder: page, routes: [
            GoRoute(path: 'edit', builder: page),
          ]),
        ],
      ),
      ShellRoute(
        builder: (c, s, child) => child,
        routes: [GoRoute(path: '/shelled', builder: page)],
      ),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/a', builder: page)]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/b', builder: page, routes: [GoRoute(path: 'sub', builder: page)]),
          ]),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('enumerateRoutes', () {
    test('walks GoRoute, ShellRoute and StatefulShellRoute without duplicates', () {
      final tree = enumerateRoutes(_fixtureRouter());
      final paths = flattenRoutes(tree).map((r) => r.path).toList();
      expect(paths, [
        '/',
        '/items',
        '/items/:id',
        '/items/:id/edit',
        '/shelled',
        '/a',
        '/b',
        '/b/sub',
      ]);
      expect(tree.map((n) => n.kind).toList(), ['route', 'route', 'shell', 'stateful_shell']);
      expect(tree[3].children.map((n) => n.kind).toSet(), {'branch'});
      expect(tree[3].children.length, 2);
    });

    test('keeps route names', () {
      final names = flattenRoutes(enumerateRoutes(_fixtureRouter())).map((r) => r.name).toList();
      expect(names, ['home', null, 'item', null, null, null, null, null]);
    });
  });

  group('expandTargets', () {
    test('substitutes params, appends variants, reports missing params and exclusions', () {
      final tree = enumerateRoutes(_fixtureRouter());
      final config = UiMapConfig.fromMap({
        'routes': {
          '/items/:id': {'params': {'id': '7'}},
          '/items': {'variants': ['?state=empty', 'state=error']},
          '/a': {'skip': true},
        },
        'exclude': ['/shelled'],
      });
      final targets = expandTargets(tree, config);
      final byRoute = {for (final t in targets) '${t.routePath}|${t.location}': t};

      expect(byRoute['/items/:id|/items/7']!.skipped, isFalse);
      expect(byRoute['/items/:id/edit|/items/:id/edit']!.skippedReason, contains('missing params: id'));
      expect(targets.where((t) => t.routePath == '/items').map((t) => t.location), [
        '/items',
        '/items?state=empty',
        '/items?state=error',
      ]);
      expect(byRoute['/a|/a']!.skippedReason, contains('excluded'));
      expect(byRoute['/shelled|/shelled']!.skippedReason, contains('excluded'));
      expect(byRoute['/b/sub|/b/sub']!.skipped, isFalse);
    });

    test('scenarios add one target per name on the plain location', () {
      final tree = enumerateRoutes(_fixtureRouter());
      final config = UiMapConfig.fromMap({
        'routes': {
          '/b': {'variants': ['?x=1'], 'scenarios': ['empty', 'logged in']},
        },
      });
      final b = expandTargets(tree, config).where((t) => t.routePath == '/b').toList();
      expect(b.map((t) => '${t.location}|${t.scenario}'), ['/b|null', '/b?x=1|null', '/b|empty', '/b|logged in']);
      expect(slugForScenario('logged in'), 'logged-in');
    });

    test('keyboard: true adds a keyboard target', () {
      final tree = enumerateRoutes(_fixtureRouter());
      final config = UiMapConfig.fromMap({'routes': {'/': {'keyboard': true}}});
      final root = expandTargets(tree, config).where((t) => t.routePath == '/').toList();
      expect(root.map((t) => t.keyboard), [false, true]);
    });
  });

  group('slugForLocation', () {
    test('produces stable file-safe ids', () {
      expect(slugForLocation('/'), 'root');
      expect(slugForLocation('/notes'), 'notes');
      expect(slugForLocation('/notes/1'), 'notes_1');
      expect(slugForLocation('/notes?state=empty'), 'notes__state-empty');
      expect(slugForLocation('/a/b?x=1&y=2'), 'a_b__x-1_y-2');
      expect(slugForLocation('/weird path/ü'), 'weird-path_-');
    });
  });
}
