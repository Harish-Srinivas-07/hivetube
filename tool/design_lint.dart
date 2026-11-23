import 'dart:io';

class _Rule {
  const _Rule(this.label, this.expression, {this.skipZones = false});

  final String label;
  final RegExp expression;
  final bool skipZones;
}

final _rules = <_Rule>[
  _Rule('BoxShadow', RegExp(r'BoxShadow')),
  _Rule('elevation', RegExp(r'\belevation\s*:\s*[^,\n]+')),
  _Rule('Card(', RegExp(r'\bCard\s*\(')),
  _Rule('GlassSurface', RegExp(r'GlassSurface')),
  _Rule('BackdropFilter', RegExp(r'BackdropFilter')),
  _Rule('ImageFilter.blur', RegExp(r'ImageFilter\.blur')),
  _Rule('ShaderMask', RegExp(r'ShaderMask')),
  _Rule('Divider(', RegExp(r'\bDivider\s*\(')),
  _Rule('fontSize', RegExp(r'fontSize\s*:'), skipZones: true),
  _Rule('Color(0x', RegExp(r'Color\s*\(\s*0x'), skipZones: true),
  _Rule('Colors.', RegExp(r'\bColors\.[A-Za-z_]\w*'), skipZones: true),
];

const _excludedZones = <String>[
  'lib/theme/',
  'lib/widgets/player/',
  'lib/features/shorts/',
];

void main() {
  final hasAppColorsTransparent = File('lib/theme/app_colors.dart')
      .readAsStringSync()
      .contains(RegExp(r'\btransparent\s*=\s*Colors\.transparent\b'));
  final files =
      Directory('lib')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final hitsByRule = <_Rule, List<String>>{
    for (final rule in _rules) rule: <String>[],
  };

  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final previous = index == 0 ? '' : lines[index - 1];
      if (line.contains('// allowed:') || previous.contains('// allowed:')) {
        continue;
      }
      for (final rule in _rules) {
        if (rule.skipZones && _excludedZones.any(path.startsWith)) continue;
        for (final match in rule.expression.allMatches(line)) {
          if (rule.label == 'elevation') {
            final value = double.tryParse(
              line
                  .substring(match.start)
                  .split(':')
                  .skip(1)
                  .join(':')
                  .split(',')
                  .first
                  .trim(),
            );
            if (value == 0) continue;
          }
          if (rule.label == 'Colors.' &&
              match.group(0) == 'Colors.transparent' &&
              !hasAppColorsTransparent) {
            continue;
          }
          hitsByRule[rule]!.add('$path:${index + 1}');
        }
      }
    }
  }

  var total = 0;
  for (final rule in _rules) {
    final hits = hitsByRule[rule]!;
    total += hits.length;
    stdout.writeln('${rule.label}: ${hits.length}');
    for (final hit in hits) {
      stdout.writeln('  $hit');
    }
  }
  exitCode = total == 0 ? 0 : 1;
}
