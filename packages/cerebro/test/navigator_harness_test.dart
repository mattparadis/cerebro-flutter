// End-to-end check of the Navigator 1.0 driver on a tiny MaterialApp.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cerebro/cerebro.dart';

final _out = Directory.systemTemp.createTempSync('cerebro_nav').path;

class _App extends StatelessWidget {
  const _App({required this.themeMode});
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      initialRoute: '/home',
      routes: {
        '/home': (c) => Scaffold(
              appBar: AppBar(title: const Text('Home')),
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.pushNamed(c, '/detail', arguments: 7),
                  child: const Text('Open detail'),
                ),
              ),
            ),
        '/detail': (c) => Scaffold(
              appBar: AppBar(title: Text('Detail ${ModalRoute.of(c)!.settings.arguments}')),
              body: TextButton(onPressed: () => Navigator.pop(c), child: const Text('Back')),
            ),
        '/dialogs': (c) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(context: c, builder: (_) => const AlertDialog(title: Text('Hi'))),
                  child: const Text('Show dialog'),
                ),
              ),
            ),
      },
    );
  }
}

void main() {
  Cerebro.runNavigator(
    buildApp: ({required ThemeMode themeMode}) => _App(themeMode: themeMode),
    argumentsFor: (loc) => loc == '/detail' ? 42 : null,
    outDir: _out,
  );

  tearDownAll(() {
    final routes = jsonDecode(File('$_out/routes.json').readAsStringSync()) as Map;
    expect(routes['router'], 'navigator');
    final locations = (routes['targets'] as List).map((t) => t['location']).toList();
    expect(locations, containsAll(['/home', '/detail', '/dialogs']));

    final results = Directory('$_out/results').listSync().whereType<File>().toList();
    expect(results.length, greaterThanOrEqualTo(3));
    final detail = results.firstWhere((f) => f.path.contains('detail__phone__light'));
    final j = jsonDecode(detail.readAsStringSync()) as Map;
    expect(j['status'], 'ok');
    expect(File('$_out/${j['png']}').lengthSync(), greaterThan(500));
    // The semantics dump proves the argument reached the screen.
    expect(File('$_out/${j['semantics']}').readAsStringSync(), contains('Detail 42'));
    Directory(_out).deleteSync(recursive: true);
  });
}
