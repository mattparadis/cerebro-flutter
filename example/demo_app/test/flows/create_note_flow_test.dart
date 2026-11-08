// Flow contract for note creation (see skills/design-screen/references/patterns.md,
// "Flow contracts"): verified against the in-memory repository, not the UI alone.
import 'package:demo_app/app.dart';
import 'package:demo_app/data/notes_repository.dart';
import 'package:demo_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester, String location) async {
  await tester.pumpWidget(DemoApp(router: buildRouter(initialLocation: location), themeMode: ThemeMode.light));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the editor the way the user does: from the list, via the FAB.
Future<void> _openEditor(WidgetTester tester) async {
  await _pumpApp(tester, '/notes');
  await tester.tap(find.byType(FloatingActionButton));
  await _settle(tester);
}

Finder get _editorTitle => find.descendant(of: find.byType(AppBar), matching: find.text('New note'));


void main() {
  setUp(NotesRepository.reset);

  testWidgets('empty form: Save is disabled, Discard pops without asking', (tester) async {
    await _openEditor(tester);
    expect(_editorTitle, findsOneWidget);
    final save = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));
    expect(save.onPressed, isNull);
    await tester.tap(find.byTooltip('Discard'));
    await _settle(tester);
    expect(_editorTitle, findsNothing);
  });

  testWidgets('valid form: Save persists, closes, and the list shows the note first', (tester) async {
    await _openEditor(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Compost turned');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Write what you see…'), 'Steaming, good smell.');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 50));
    // in flight: spinner, no second submit possible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextButton>(find.byWidgetPredicate(
      (w) => w is TextButton && w.child is SizedBox,
    )).onPressed, isNull);
    await _settle(tester, 1200);
    // persisted and visible where the user looks next
    expect(find.text('Saved "Compost turned"'), findsOneWidget);
    expect(find.text('Compost turned'), findsWidgets);
    // Repository futures use real delays: await them outside the fake-async zone.
    final first = await tester.runAsync(() => const NotesRepository().list(ListState.full));
    expect(first!.first.title, 'Compost turned');
  });

  testWidgets('failed save: inline error, text kept, Retry succeeds, no duplicate', (tester) async {
    NotesRepository.failNextAdd = true;
    await _openEditor(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Fence post');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _settle(tester, 800);
    expect(find.textContaining("Couldn't save"), findsOneWidget);
    expect(find.text('Fence post'), findsOneWidget); // text kept
    await tester.tap(find.text('Retry'));
    await _settle(tester, 800);
    final notes = await tester.runAsync(() => const NotesRepository().list(ListState.full));
    expect(notes!.where((n) => n.title == 'Fence post').length, 1);
  });

  testWidgets('dirty form: Discard asks, Keep editing keeps the text', (tester) async {
    await _openEditor(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Draft');
    await tester.pump();
    await tester.tap(find.byTooltip('Discard'));
    await _settle(tester);
    expect(find.text('Discard this note?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await _settle(tester);
    expect(find.text('Draft'), findsOneWidget);
    expect(_editorTitle, findsOneWidget);
  });
}
