import 'package:cerebro/src/fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final config = {
    'configVersion': 2,
    'packages': [
      {'name': 'app', 'rootUri': '../', 'packageUri': 'lib/'},
      {'name': 'design_system', 'rootUri': '../../design_system', 'packageUri': 'lib/'},
      {'name': 'hosted_pkg', 'rootUri': 'file:///home/u/.pub-cache/hosted/pub.dev/hosted_pkg-1.0.0', 'packageUri': 'lib/'},
    ],
  };
  const root = '/proj/app';

  test('relative and absolute paths are left alone or joined to the root', () {
    expect(resolveFontPath('/abs/x.ttf', root, packageConfig: config), '/abs/x.ttf');
    expect(resolveFontPath('assets/fonts/x.ttf', root, packageConfig: config), p.join(root, 'assets/fonts/x.ttf'));
  });

  test('package asset keys resolve through package_config.json to <pkg>/lib/<path>', () {
    expect(
      p.normalize(resolveFontPath('packages/design_system/fonts/Inter-Regular.ttf', root, packageConfig: config)),
      '/proj/design_system/lib/fonts/Inter-Regular.ttf',
    );
    expect(
      resolveFontPath('packages/hosted_pkg/fonts/a.ttf', root, packageConfig: config),
      '/home/u/.pub-cache/hosted/pub.dev/hosted_pkg-1.0.0/lib/fonts/a.ttf',
    );
    expect(p.normalize(resolveFontPath('packages/app/fonts/a.ttf', root, packageConfig: config)), '/proj/app/lib/fonts/a.ttf');
  });

  test('unknown package falls back to the literal path so it is reported missing', () {
    expect(resolveFontPath('packages/nope/fonts/a.ttf', root, packageConfig: config), p.join(root, 'packages/nope/fonts/a.ttf'));
  });
}
