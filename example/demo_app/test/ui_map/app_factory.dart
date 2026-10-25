// ui_map factory for the demo app: builds the app on any route under
// `flutter test`. Keep it free of side effects.
import 'package:demo_app/app.dart';
import 'package:demo_app/router.dart' as demo;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter({required String initialLocation}) =>
    demo.buildRouter(initialLocation: initialLocation);

Widget buildApp(GoRouter router, {required ThemeMode themeMode}) =>
    DemoApp(router: router, themeMode: themeMode);
