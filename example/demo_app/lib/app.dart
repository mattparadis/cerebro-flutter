import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Root widget. Kept free of side effects so tests can build it with any
/// router and theme mode.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.router, required this.themeMode});

  final GoRouter router;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fieldnotes',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
