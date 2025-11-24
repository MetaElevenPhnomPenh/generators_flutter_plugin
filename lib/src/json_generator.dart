import 'package:analyzer/dart/element/element.dart';
import 'package:annotations/annotations.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'model_visitor.dart';

class JsonGenerator extends GeneratorForAnnotation<JsonAnnotation> {
  @override
  String generateForAnnotatedElement(
      Element element,
      ConstantReader annotation,
      BuildStep buildStep,
      ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'JsonGenerator can only be used on classes.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Collect fields
    final fields = <String, FieldData>{};
    for (var field in classElement.fields) {
      if (field.isStatic) continue;

      final typeStr = field.type.getDisplayString(withNullability: true);
      final meta = field.metadata.annotations.map((e) => e.toSource()).toList();

      fields[field.name!] = FieldData(typeString: typeStr, metadata: meta);
    }

    final buffer = StringBuffer();

    // Generate fromJson
    buffer.writeln(_generateFromJson(className!, fields));

    // Generate toJson
    buffer.writeln(_generateToJson(className, fields));

    // Generate copyWith
    buffer.writeln(_generateCopyWith(className, fields));

    return buffer.toString();
  }

  String _generateFromJson(String className, Map<String, FieldData> fields) {
    final buffer = StringBuffer();
    buffer.writeln('$className _\$${className}FromJson(Map<String, dynamic> json) => $className(');
    for (var entry in fields.entries) {
      final name = entry.key;
      final type = entry.value.typeString.replaceAll('?', '');
      final isOptional = entry.value.typeString.endsWith('?');

      String valueExpr;
      if (type.startsWith('List<')) {
        final inner = type.replaceAll('List<', '').replaceAll('>', '');
        valueExpr =
        'List<$inner>.from(json[\'$name\']?.map((v) => ${_tranformValue(inner, 'v', false)}) ?? [])';
      } else if (['int', 'double', 'String', 'bool'].contains(type)) {
        valueExpr = _tranformValue(type, "json['$name']", isOptional);
      } else {
        // Custom object type
        valueExpr = isOptional
            ? 'json[\'$name\'] != null ? $type.fromJson(json[\'$name\']) : null'
            : '$type.fromJson(json[\'$name\'])';
      }

      buffer.writeln('$name: $valueExpr,');
    }
    buffer.writeln(');');
    return buffer.toString();
  }

  String _generateToJson(String className, Map<String, FieldData> fields) {
    final buffer = StringBuffer();
    buffer.writeln('Map<String, dynamic> _\$${className}ToJson($className instance) => <String, dynamic>{');
    for (var entry in fields.entries) {
      final name = entry.key;
      final type = entry.value.typeString.replaceAll('?', '');
      if (type.startsWith('List<')) {
        buffer.writeln(
            '\'$name\': instance.$name.map((e) => e${type.contains('String') ? '' : '.toJson()'}).toList(),');
      } else if (['int', 'double', 'String', 'bool'].contains(type)) {
        buffer.writeln('\'$name\': instance.$name,');
      } else {
        buffer.writeln(
            '\'$name\': instance.$name${entry.value.typeString.endsWith('?') ? '?' : ''}.toJson(),');
      }
    }
    buffer.writeln('};');
    return buffer.toString();
  }

  String _generateCopyWith(String className, Map<String, FieldData> fields) {
    final buffer = StringBuffer();
    buffer.writeln('extension \$${className}Extension on $className {');
    buffer.writeln('$className copyWith({');
    for (var entry in fields.entries) {
      final type = entry.value.typeString;
      buffer.writeln('$type ${entry.key},');
    }
    buffer.writeln('}) {');
    buffer.writeln('return $className(');
    for (var entry in fields.entries) {
      buffer.writeln('${entry.key}: ${entry.key} ?? this.${entry.key},');
    }
    buffer.writeln(');');
    buffer.writeln('}');
    buffer.writeln('}');
    return buffer.toString();
  }

  /// Transform value based on type, same as your original function
  String _tranformValue(String type, String v, bool isOptional) {
    switch (type) {
      case 'String':
        return '$v.toString().toAppString()${isOptional ? '' : '!'}';
      case 'int':
        return '$v.toString().toAppInt()';
      case 'double':
        return '$v.toString().toAppDouble()';
      case 'bool':
        return '$v == true';
      default:
        return v;
    }
  }
}