// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/features.dart';

void main(List<String> args) async {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    stdout.writeln('lib directory not found.');
    return;
  }

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart'),
      )
      .toList();

  final sb = StringBuffer();
  sb.writeln('# hdict API Documentation');
  sb.writeln();

  for (final file in files) {
    try {
      final content = file.readAsStringSync();
      final result = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      final unit = result.unit;
      if (unit.declarations.isEmpty) continue;

      sb.writeln('## File: `${file.path}`');
      sb.writeln();

      for (final decl in unit.declarations) {
        if (decl is ClassDeclaration) {
          final typeParams = decl.typeParameters?.toSource() ?? '';
          sb.writeln('### Class: `${decl.name}$typeParams`');
          _extractMembers(decl.members, sb, '####');
          sb.writeln();
        } else if (decl is MixinDeclaration) {
          final typeParams = decl.typeParameters?.toSource() ?? '';
          sb.writeln('### Mixin: `${decl.name}$typeParams`');
          _extractMembers(decl.members, sb, '####');
          sb.writeln();
        } else if (decl is ExtensionDeclaration) {
          final typeParams = decl.typeParameters?.toSource() ?? '';
          final onType = decl.onClause?.extendedType.toSource() ?? 'Unknown';
          sb.writeln(
            '### Extension: `${decl.name ?? 'Unnamed'}$typeParams` on `$onType`',
          );
          _extractMembers(decl.members, sb, '####');
          sb.writeln();
        } else if (decl is EnumDeclaration) {
          final typeParams = decl.typeParameters?.toSource() ?? '';
          sb.writeln('### Enum: `${decl.name}$typeParams`');
          if (decl.constants.isNotEmpty) {
            sb.writeln('#### Constants');
            for (final ec in decl.constants) {
              final argsStr = ec.arguments?.toSource() ?? '';
              sb.writeln('- `${ec.name}$argsStr`');
            }
          }
          _extractMembers(decl.members, sb, '####');
          sb.writeln();
        } else if (decl is FunctionDeclaration) {
          final retType = decl.returnType?.toSource() ?? 'void';
          final typeParams =
              decl.functionExpression.typeParameters?.toSource() ?? '';
          final paramsNode = decl.functionExpression.parameters;
          final paramsStr = paramsNode?.toSource() ?? '()';
          sb.writeln(
            '### Function: `$retType ${decl.name}$typeParams$paramsStr`',
          );
          if (paramsNode != null && paramsNode.parameters.isNotEmpty) {
            for (final p in paramsNode.parameters) {
              sb.writeln('  - Parameter: `${p.toSource()}`');
            }
          }
          sb.writeln();
        } else if (decl is TopLevelVariableDeclaration) {
          sb.writeln('### Top-Level Variables');
          for (final v in decl.variables.variables) {
            final type = decl.variables.type?.toSource() ?? 'var';
            final keyword = decl.variables.isConst
                ? 'const '
                : decl.variables.isFinal
                ? 'final '
                : '';
            final prefix = type != 'var' ? '$type ' : '';
            sb.writeln('- `$keyword$prefix${v.name}`');
          }
          sb.writeln();
        } else if (decl is GenericTypeAlias) {
          final typeParams = decl.typeParameters?.toSource() ?? '';
          final aliasedType = decl.type.toSource();
          sb.writeln(
            '### Type Alias: `${decl.name}$typeParams = $aliasedType`',
          );
          sb.writeln();
        } else if (decl is TypeAlias) {
          sb.writeln('### Type Alias: `${decl.name}`');
          sb.writeln();
        }
      }
    } catch (e) {
      stdout.writeln('Error parsing ${file.path}: $e');
    }
  }

  // To save it as an artifact or general doc file
  final outDir = Directory('reference');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  final outPath = 'reference/api_documentation.md';
  File(outPath).writeAsStringSync(sb.toString());
  stdout.writeln('API documentation generated in $outPath');
}

void _extractMembers(
  NodeList<ClassMember> members,
  StringBuffer sb,
  String prefix,
) {
  final fields = <String>[];
  final constructors = <String>[];
  final methods = <String>[];

  for (final m in members) {
    if (m is MethodDeclaration) {
      final isStatic = m.isStatic ? 'static ' : '';
      final retType = m.returnType?.toSource() ?? '';
      final retStr = retType.isNotEmpty ? '$retType ' : '';
      final kind = m.isGetter
          ? 'get '
          : m.isSetter
          ? 'set '
          : '';
      final typeStr = kind.isNotEmpty ? 'Property' : 'Method';
      final typeParams = m.typeParameters?.toSource() ?? '';
      final paramsNode = m.parameters;
      final paramsStr = paramsNode?.toSource() ?? '';
      methods.add(
        '- $typeStr: `$isStatic$retStr$kind${m.name}$typeParams$paramsStr`',
      );
      if (paramsNode != null && paramsNode.parameters.isNotEmpty) {
        for (final p in paramsNode.parameters) {
          methods.add('  - Parameter: `${p.toSource()}`');
        }
      }
    } else if (m is FieldDeclaration) {
      final isStatic = m.isStatic ? 'static ' : '';
      final keyword = m.fields.isConst
          ? 'const '
          : m.fields.isFinal
          ? 'final '
          : '';
      final type = m.fields.type?.toSource() ?? 'var';
      final tStr = type != 'var' ? '$type ' : '';
      for (final v in m.fields.variables) {
        fields.add('- Field: `$isStatic$keyword$tStr${v.name}`');
      }
    } else if (m is ConstructorDeclaration) {
      final isConst = m.constKeyword != null ? 'const ' : '';
      final isFactory = m.factoryKeyword != null ? 'factory ' : '';
      final name = m.name?.lexeme == null
          ? m.returnType.toSource()
          : '${m.returnType.toSource()}.${m.name!.lexeme}';
      final paramsNode = m.parameters;
      final paramsStr = paramsNode.toSource();
      constructors.add('- Constructor: `$isConst$isFactory$name$paramsStr`');
      if (paramsNode.parameters.isNotEmpty) {
        for (final p in paramsNode.parameters) {
          constructors.add('  - Parameter: `${p.toSource()}`');
        }
      }
    }
  }

  if (fields.isNotEmpty) {
    sb.writeln('$prefix Fields');
    for (final f in fields) {
      sb.writeln(f);
    }
  }
  if (constructors.isNotEmpty) {
    sb.writeln('$prefix Constructors');
    for (final c in constructors) {
      sb.writeln(c);
    }
  }
  if (methods.isNotEmpty) {
    sb.writeln('$prefix Methods');
    for (final m in methods) {
      sb.writeln(m);
    }
  }
}
