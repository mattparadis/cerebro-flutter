import 'package:flutter_test/flutter_test.dart';
import 'package:ui_map/src/lint.dart';

void main() {
  test('flags colour, font, handler, icon button, deprecated and platform checks', () {
    const src = '''
import 'dart:io';
class S extends StatelessWidget {
  Widget build(BuildContext context) {
    final c = const Color(0xFFBDBDBD); // caption
    final g = Colors.grey[400];
    final ok = Colors.transparent;
    return Scaffold(
      body: Column(children: [
        Text('x', style: TextStyle(fontSize: 14)),
        TextButton(onPressed: () {}, child: Text('a')),
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(onPressed: () {}, icon: Icon(Icons.edit)),
        ),
        if (Platform.isIOS) Text('ios'),
        WillPopScope(onWillPop: () async => false, child: Text('x')),
        GestureDetector(
          onTap: () => print('x'),
          child: Icon(Icons.add),
        ),
        Image.network('https://x/y.png'),
      ]),
    );
  }
}
''';
    final f = lintFile('lib/screens/s.dart', src);
    final rules = f.map((e) => '${e.rule}@${e.line}').toList();
    expect(rules, containsAll([
      'hardcoded-color@4',
      'hardcoded-color@5',
      'literal-font-size@9',
      'empty-handler@10',
      'empty-handler@14',
      'small-icon-button@11',
      'platform-io-check@16',
      'deprecated-will-pop-scope@17',
      'gesture-without-semantics@18',
      'network-image-no-error-builder@22',
      'no-safe-area@7',
    ]));
    expect(rules.where((r) => r.startsWith('hardcoded-color')).length, 2, reason: 'transparent is allowed');
    expect(f.firstWhere((e) => e.rule == 'deprecated-will-pop-scope').severity, 'error');
    expect(f.firstWhere((e) => e.rule == 'hardcoded-color').severity, 'convention');
    expect(f.firstWhere((e) => e.rule == 'small-icon-button').severity, 'warning');
  });

  test('small-icon-button: siblings are not constraints, real constraints are (review item 3)', () {
    const siblings = '''
Column(children: [
  const SizedBox(height: 8),
  IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
  SizedBox(width: 24, child: Text('x')),
  IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
])
''';
    expect(lintFile('lib/a.dart', siblings).where((f) => f.rule == 'small-icon-button'), isEmpty);
    const constrained = '''
SizedBox(
  width: 32,
  height: 32,
  child: IconButton(padding: EdgeInsets.zero, onPressed: () {}, icon: const Icon(Icons.edit)),
)
''';
    final f = lintFile('lib/b.dart', constrained).where((f) => f.rule == 'small-icon-button').toList();
    expect(f, hasLength(1));
    expect(f.single.message, contains('32 dp'));
    const big = 'SizedBox(width: 56, height: 56, child: IconButton(onPressed: () {}, icon: Icon(Icons.x)))';
    expect(lintFile('lib/c.dart', big).where((f) => f.rule == 'small-icon-button'), isEmpty);
  });

  test('inline ignore disables rules for that line', () {
    const src = "final c = Color(0xFF000000); // ui_map: ignore brand colour\nfinal d = Color(0xFF111111);";
    expect(lintFile('lib/a.dart', src).map((f) => f.line), [2]);
  });

  test('theme files and comments are exempt from style rules; tests only get pumpAndSettle', () {
    const theme = "final c = Color(0xFF00695C); // Color(0xFF000000)\nfinal s = TextStyle(fontSize: 12);";
    expect(lintFile('lib/theme.dart', theme), isEmpty);
    expect(lintFile('lib/theme/colors.dart', theme), isEmpty);
    expect(lintFile('lib/x.dart', '// Color(0xFF000000)\n'), isEmpty);
    final t = lintFile('test/widget_test.dart', "await tester.pumpAndSettle();\nColor(0xFF000000);");
    expect(t.map((e) => e.rule), ['pump-and-settle']);
  });

  test('safe-area rule is satisfied by AppBar, SafeArea or a shell', () {
    expect(lintFile('lib/a.dart', 'Scaffold(appBar: AppBar())').where((f) => f.rule == 'no-safe-area'), isEmpty);
    expect(lintFile('lib/b.dart', 'Scaffold(body: SafeArea(child: x))').where((f) => f.rule == 'no-safe-area'), isEmpty);
    expect(lintFile('lib/c.dart', 'Scaffold(body: navigationShell)').where((f) => f.rule == 'no-safe-area'), isEmpty);
    expect(lintFile('lib/d.dart', 'Scaffold(body: Text("x"))').map((f) => f.rule), ['no-safe-area']);
  });

  test('rules can be disabled and markdown groups by rule', () {
    final f = lintFile('lib/a.dart', 'Color(0xFF000000)', options: const LintOptions(rules: {'hardcoded-color': false}));
    expect(f, isEmpty);
    final md = renderLintMarkdown(lintFile('lib/a.dart', 'Color(0xFF000000)'));
    expect(md, contains('## hardcoded-color (convention, 1)'));
    expect(md, contains('`lib/a.dart:1`'));
  });
}
