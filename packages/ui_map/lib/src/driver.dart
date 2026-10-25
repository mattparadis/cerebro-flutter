import 'package:flutter/cupertino.dart' show CupertinoPageScaffold;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

typedef RouterBuilder = GoRouter Function({required String initialLocation});
typedef AppBuilder = Widget Function(GoRouter router, {required ThemeMode themeMode});

/// Navigator 1.0 apps: build the root widget (which contains the
/// `MaterialApp`) for a theme mode.
typedef RootBuilder = Widget Function({required ThemeMode themeMode});

/// Navigator 1.0 apps: arguments to pass when opening [location]
/// (`Navigator.pushNamed(..., arguments:)`). Return null for none.
typedef ArgumentsFor = Object? Function(String location);

typedef AppWrap = Widget Function(Widget app);

class NavSnapshot {
  const NavSnapshot({required this.location, required this.depth, this.popup = false});

  /// Location of the top-most page route.
  final String location;

  /// Number of page routes on the stack.
  final int depth;

  /// True when a popup route (dialog, sheet, menu) is on top.
  final bool popup;
}

/// How the harness opens a screen and reads the navigation state. Two
/// implementations: go_router (declarative, location = URI) and Navigator
/// 1.0 (`MaterialApp.routes`, location = route name).
abstract class ScreenDriver {
  String get kind;

  /// Pumps the app showing [location]. [wrap] adds the harness chrome
  /// (RepaintBoundary, inset bands) around the app widget.
  Future<void> open(WidgetTester tester, String location, ThemeMode themeMode, AppWrap wrap);

  NavSnapshot snapshot(WidgetTester tester);
}

class GoRouterDriver implements ScreenDriver {
  GoRouterDriver({required this.buildRouter, required this.buildApp});

  final RouterBuilder buildRouter;
  final AppBuilder buildApp;
  GoRouter? _router;

  @override
  String get kind => 'go_router';

  @override
  Future<void> open(WidgetTester tester, String location, ThemeMode themeMode, AppWrap wrap) async {
    final router = buildRouter(initialLocation: location);
    _router = router;
    await tester.pumpWidget(wrap(buildApp(router, themeMode: themeMode)));
  }

  @override
  NavSnapshot snapshot(WidgetTester tester) {
    final router = _router!;
    // `router.state` describes the top-most route, including imperative
    // pushes, which the configuration's own `uri` does not reflect.
    return NavSnapshot(
      location: router.state.uri.toString(),
      depth: router.routerDelegate.currentConfiguration.matches.length,
    );
  }
}

class NavigatorDriver implements ScreenDriver {
  NavigatorDriver({required this.buildApp, this.argumentsFor, this.configArgs = const {}});

  final RootBuilder buildApp;
  final ArgumentsFor? argumentsFor;

  /// `routes.<path>.args` from ui_map.yaml, used when [argumentsFor] is
  /// null or returns null.
  final Map<String, Object?> configArgs;

  @override
  String get kind => 'navigator';

  /// Route names declared on the app's `MaterialApp` (`routes` keys, plus
  /// `/` when `home` is set). Requires a pumped app.
  List<String> enumerate(WidgetTester tester) {
    final finder = find.byType(MaterialApp);
    if (finder.evaluate().isEmpty) {
      throw StateError('ui_map: no MaterialApp found in the widget tree built by buildApp().');
    }
    final app = tester.widget<MaterialApp>(finder.first);
    final names = <String>[];
    if (app.home != null && !(app.routes?.containsKey('/') ?? false)) names.add('/');
    names.addAll(app.routes?.keys ?? const <String>[]);
    return names;
  }

  @override
  Future<void> open(WidgetTester tester, String location, ThemeMode themeMode, AppWrap wrap) async {
    await tester.pumpWidget(wrap(buildApp(themeMode: themeMode)));
    await tester.pump(const Duration(milliseconds: 50));
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    final routeName = location.split('?').first;
    final args = argumentsFor?.call(location) ?? configArgs[location] ?? configArgs[routeName];
    // Push on top of the app's initial route, as the app itself would:
    // screens that pop themselves (auth guards) then land on the initial
    // route instead of crashing on an empty stack. The capture records a
    // `redirected_to` when the final location differs from the target.
    nav.pushNamed(location, arguments: args);
  }

  @override
  NavSnapshot snapshot(WidgetTester tester) {
    final routes = <ModalRoute<Object?>>{};
    for (final e in tester.allElements) {
      final w = e.widget;
      if (w is! Scaffold &&
          w is! Material &&
          w is! Dialog &&
          w is! AlertDialog &&
          w is! SimpleDialog &&
          w is! BottomSheet &&
          w is! CupertinoPageScaffold) {
        continue;
      }
      final r = ModalRoute.of(e);
      if (r != null) routes.add(r);
    }
    final pages = routes.where((r) => r is PageRoute && r.isActive).toList();
    final current = routes.where((r) => r.isCurrent).firstOrNull;
    String? name;
    if (current is PageRoute) {
      name = _nameOf(current);
    } else {
      // Popup on top: report the page beneath. Prefer the page with the
      // highest animation value as a proxy for being on top.
      final top = pages.where((r) => !r.isCurrent).lastOrNull ?? pages.lastOrNull;
      name = top == null ? null : _nameOf(top);
    }
    return NavSnapshot(
      location: name ?? '(unknown)',
      depth: pages.length,
      popup: current != null && current is! PageRoute,
    );
  }

  static String _nameOf(ModalRoute<Object?> r) =>
      r.settings.name ?? '(unnamed ${r.runtimeType})';
}
