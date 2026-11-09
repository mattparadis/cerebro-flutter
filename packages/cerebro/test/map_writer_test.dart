import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cerebro/cerebro.dart';

void main() {
  test('merges results into map.json and renders MAP.md', () {
    final dir = Directory.systemTemp.createTempSync('cerebro_out');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/routes.json').writeAsStringSync(jsonEncode({
      'config': {'themes': ['light']},
      'tree': [
        {'kind': 'route', 'path': '/', 'name': 'home'},
        {
          'kind': 'stateful_shell',
          'children': [
            {
              'kind': 'branch',
              'children': [
                {
                  'kind': 'route',
                  'path': '/a',
                  'children': [
                    {'kind': 'route', 'path': '/a/:id'},
                  ],
                },
              ],
            },
          ],
        },
      ],
      'targets': [
        {'route': '/', 'location': '/'},
        {'route': '/a/:id', 'location': '/a/:id', 'skipped': 'missing params: id'},
      ],
    }));
    File('${dir.path}/fonts.json').writeAsStringSync(jsonEncode({'families': ['Roboto'], 'warnings': []}));
    Directory('${dir.path}/results').createSync();
    File('${dir.path}/results/root__phone__light__android.json').writeAsStringSync(jsonEncode({
      'id': 'root__phone__light__android',
      'route': '/',
      'location': '/',
      'device': 'phone',
      'theme': 'light',
      'platform': 'android',
      'status': 'ok',
      'png': 'screens/root__phone__light__android.png',
      'exceptions': ['A RenderFlex overflowed by 12 pixels on the bottom.'],
      'tappables_below_min': [
        {'label': 'Edit', 'width': 32.0, 'height': 32.0},
      ],
    }));
    File('${dir.path}/results/a__phone__light__android.json').writeAsStringSync(jsonEncode({
      'id': 'a__phone__light__android',
      'route': '/a',
      'location': '/a',
      'device': 'phone',
      'theme': 'light',
      'platform': 'android',
      'status': 'error',
      'error': 'Bad state: boom',
    }));

    final map = MapWriter(dir.path, flutterVersion: '3.47.2').write();
    final summary = map['summary'] as Map;
    expect(summary['screens'], 2);
    expect(summary['ok'], 1);
    expect(summary['error'], 1);
    expect(summary['with_exceptions'], 1);
    expect(summary['with_small_tappables'], 1);
    expect((map['skipped'] as List).single, {'route': '/a/:id', 'reason': 'missing params: id'});
    expect(File('${dir.path}/map.json').existsSync(), isTrue);

    final md = File('${dir.path}/MAP.md').readAsStringSync();
    expect(md, contains('```mermaid'));
    expect(md, contains('subgraph'));
    expect(md, contains('"/a/:id"'));
    expect(md, contains('-->'));
    expect(md, contains('## Not captured'));
    expect(md, contains('<img src="screens/root__phone__light__android.png"'));
    expect(md, contains('1 exception(s); 1 small tap target(s)'));
    expect(md, contains('Bad state: boom'));
  });
}
