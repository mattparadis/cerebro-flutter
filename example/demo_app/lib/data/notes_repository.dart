import 'dart:async';

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.tag,
    required this.updated,
  });

  final String id;
  final String title;
  final String body;
  final String tag;
  final String updated;
}

/// Screen states addressable from the URL: `/notes?state=empty|loading|error`.
/// Any other value (or none) returns the full list.
///
/// This is the demo's "scenario hook": a scenario is just a location, so the
/// capture tool can reach every state without test-only wiring.
enum ListState { full, empty, loading, error }

ListState parseState(String? raw) => switch (raw) {
      'empty' => ListState.empty,
      'loading' => ListState.loading,
      'error' => ListState.error,
      _ => ListState.full,
    };

class NotesRepository {
  const NotesRepository();

  /// Test seam: when set, every list() ignores the requested state and uses
  /// this one. ui_map scenarios in test/ui_map/app_factory.dart set it to
  /// capture screens whose URL has no `?state=` hook.
  static ListState? scenarioOverride;

  static const _notes = <Note>[
    Note(
      id: '1',
      title: 'Soil sample, north field',
      body:
          'pH 6.4, slightly compacted at 20 cm. Earthworm count good. Re-test after the rain.',
      tag: 'Field',
      updated: 'Today, 09:12',
    ),
    Note(
      id: '2',
      title: 'Irrigation timer',
      body: 'Zone 3 runs 10 minutes too long. Check the valve before Friday.',
      tag: 'Maintenance',
      updated: 'Yesterday',
    ),
    Note(
      id: '3',
      title: 'Seed order',
      body: 'Buckwheat ×2, clover ×1. Ask about bulk pricing.',
      tag: 'Orders',
      updated: 'Mon',
    ),
    Note(
      id: '4',
      title: 'Fence line walk',
      body: 'Two posts leaning near the creek crossing. Wire intact.',
      tag: 'Field',
      updated: 'Last week',
    ),
    Note(
      id: '5',
      title: 'Equipment hours',
      body: 'Tractor at 1,240 h. Oil change due at 1,250.',
      tag: 'Maintenance',
      updated: 'Last week',
    ),
  ];

  Future<List<Note>> list(ListState requested) {
    final state = scenarioOverride ?? requested;
    switch (state) {
      case ListState.loading:
        return Completer<List<Note>>().future; // never completes
      case ListState.error:
        return Future<List<Note>>.delayed(
          const Duration(milliseconds: 200),
          () => throw StateError('Sync failed: the server returned 503.'),
        );
      case ListState.empty:
        return Future<List<Note>>.delayed(
          const Duration(milliseconds: 200),
          () => const <Note>[],
        );
      case ListState.full:
        return Future<List<Note>>.delayed(
          const Duration(milliseconds: 200),
          () => _notes,
        );
    }
  }

  Note? byId(String id) {
    for (final n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }
}
