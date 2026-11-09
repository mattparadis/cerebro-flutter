import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/notes_repository.dart';
import 'prototypes/note_detail_proto.dart';
import 'screens/about_screen.dart';
import 'screens/login_screen.dart';
import 'screens/note_detail_screen.dart';
import 'screens/note_new_screen.dart';
import 'screens/notes_list_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell_scaffold.dart';

/// Compile-time flag that exposes prototype routes (`/__proto/...`) to the
/// cerebro capture: `dart run cerebro capture -D UI_PROTO=true`.
const kUiProto = bool.fromEnvironment('UI_PROTO');

/// Builds the app router. [initialLocation] exists so tests and the cerebro
/// harness can open the app directly on any screen.
GoRouter buildRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/paywall',
        name: 'paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      if (kUiProto)
        GoRoute(
          path: '/__proto/note-detail',
          name: 'protoNoteDetail',
          builder: (context, state) => switch (state.uri.queryParameters['v']) {
            'b' => const NoteDetailProtoB(),
            _ => const NoteDetailProtoA(),
          },
        ),
      GoRoute(
        path: '/notes/new',
        name: 'noteNew',
        pageBuilder: (context, state) => const MaterialPage<void>(
          fullscreenDialog: true,
          child: NoteNewScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                name: 'notes',
                builder: (context, state) => NotesListScreen(
                  state: parseState(state.uri.queryParameters['state']),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'noteDetail',
                    builder: (context, state) =>
                        NoteDetailScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    name: 'about',
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
