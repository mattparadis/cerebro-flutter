// Guards the two skills shipped next to this package: Claude Code loads a
// SKILL.md whose frontmatter is not valid YAML, `npx skills add` skips it in
// silence (2026-11-09: an unquoted `: ` in a description). Skipped when the
// skills folder is not around (package consumed from pub.dev).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main() {
  final skillsDir = Directory(p.join(Directory.current.path, '..', '..', 'skills'));
  final skills = skillsDir.existsSync()
      ? skillsDir.listSync().whereType<Directory>().where((d) => File(p.join(d.path, 'SKILL.md')).existsSync()).toList()
      : <Directory>[];

  test('skills folder found', () {
    expect(skills, isNotEmpty);
  }, skip: !skillsDir.existsSync() ? 'skills/ not present (package used outside the repo)' : false);

  for (final dir in skills) {
    final name = p.basename(dir.path);
    test('$name/SKILL.md has valid frontmatter with name and description', () {
      final text = File(p.join(dir.path, 'SKILL.md')).readAsStringSync();
      final m = RegExp(r'^---\r?\n(.*?)\r?\n---\r?\n', dotAll: true).firstMatch(text);
      expect(m, isNotNull, reason: 'no frontmatter block');
      final doc = loadYaml(m!.group(1)!);
      expect(doc, isA<YamlMap>(), reason: 'frontmatter is not a YAML map');
      final map = doc as YamlMap;
      expect(map['name'], name, reason: 'name must match the folder');
      expect(map['description'], isA<String>());
      final desc = map['description'] as String;
      expect(desc.trim(), isNotEmpty);
      expect(desc.length, lessThanOrEqualTo(1024), reason: 'skills.sh truncates long descriptions');
      // Flow scalars with ": " must be quoted; loadYaml would have thrown or
      // produced a nested map above, this is the readable restatement.
      expect(map.keys.every((k) => k is String), isTrue);
    });
  }
}
