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
    buffer.writeln(generateFromJsonMethod(className!, fields));

    // Generate toJson
    buffer.writeln(generateToJsonMethod(className, fields));

    // Generate copyWith
    buffer.writeln(generateCopyWithMethod(className, fields));

    return buffer.toString();
  }

  // Method to generate fromJSon method
  String generateFromJsonMethod(String className, Map<String, FieldData> fields) {
    // Class name from model visitor

    // Buffer to write each part of generated class
    final buffer = StringBuffer();

    // --------------------Start fromJson Generation Code--------------------//
    buffer.writeln('// From Json Method');
    buffer.writeln('$className _\$${className}FromJson(Map<String, dynamic> json) => ');
    buffer.write('$className(');

    for (var entry in fields.entries) {
      final name = entry.key;
      String dataType = entry.value.typeString.replaceAll('?', '');
      final bool isOptional = entry.value.typeString.contains('?');
      dataType = dataType.replaceAll("?", "");
      bool isList = dataType.startsWith('List<');
      if (isList) {
        dataType = dataType.replaceAll("List<", "");
        dataType = dataType.replaceAll(">", "");
      }
      String fieldName = camelCaseToSnakeCase(name);
      String mapValue = "json['$fieldName']";
      if (isObject(dataType)) {
        String fromJson = '$dataType.fromJson($mapValue)';
        if (isList) {
          fromJson = 'List<$dataType>.from($mapValue.map((v) => $dataType.fromJson(v)))';
        }
        mapValue = isOptional ? '$mapValue == null ? null : $fromJson' : fromJson;
      } else {
        if (isList) {
          mapValue = 'List<$dataType>.from($mapValue.map((v) => ${tranformValue(type: dataType, v: 'v', isOptional: isOptional)}))';
        } else {
          mapValue = tranformValue(type: dataType, v: mapValue, isOptional: isOptional);
        }
        if (isOptional) {
          mapValue = "json['$fieldName'] == null ? null : $mapValue";
        }
      }
      /*     for (var v in field.metaDrtObject) {
        if(v?.type?.element == JsonKey){
          var value = v?.getField('defaultValue')?.toBoolValue();
        }
      }*/
      buffer.writeln(
        "$name: $mapValue,",
      );
    }
    buffer.writeln(');');
    buffer.toString();
    return buffer.toString();
    // --------------------End fromJson Generation Code--------------------//
  }

  String tranformValue({required String type, required String v, required bool isOptional}) {
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

  bool isObject(String v) {
    if (['String', 'int', 'double', 'bool', 'Color', 'num', 'dynamic'].contains(v)) {
      return false;
    }
    return true;
  }

  String camelCaseToSnakeCase(String input) {
    String result = input;
/*    result = result.replaceAllMapped(RegExp(r'([A-Z])'), (Match match) {
      return '_' + match.group(0)!.toLowerCase();
    });

    // Remove leading underscore if present
    if (result.startsWith('_')) {
      result = result.substring(1);
    }*/

    return result;
  }

  // Method to generate fromJSon method
  String generateToJsonMethod(String className, Map<String, FieldData> fields) {
    // Buffer to write each part of generated class
    final buffer = StringBuffer();

    // --------------------Start toJson Generation Code--------------------//
    buffer.writeln('// To Json Method');
    buffer.writeln('Map<String, dynamic> _\$${className}ToJson($className instance) => ');
    buffer.write('<String, dynamic>{');
    for (var entry in fields.entries) {
      final name = entry.key;
      String dataType = entry.value.typeString.replaceAll('?', '');
      final bool isOptional = entry.value.typeString.contains('?');
      dataType = dataType.replaceAll("?", "");
      bool isList = dataType.startsWith('List<');
      if (isList) {
        dataType = dataType.replaceAll("List<", "");
        dataType = dataType.replaceAll(">", "");
      }
      dataType = dataType.replaceAll("?", "");
      String fieldName = name;
      String jsonValue = "instance.$fieldName";
      if (isObject(dataType)) {
        if (isList) {
          jsonValue = 'List.from($jsonValue${isOptional ? '!' : ''}.map((v) => v.toJson()))';
          if (isOptional) {
            jsonValue = "instance.$fieldName == null ? null : $jsonValue";
          }
        } else {
          jsonValue = '$jsonValue${isOptional ? '?' : ''}.toJson()';
        }
      }
      buffer.writeln(
        "'${camelCaseToSnakeCase(fieldName)}': $jsonValue,",
      );
    }
    buffer.writeln('};');
    return buffer.toString();
    // --------------------End toJson Generation Code--------------------//
  }

  // Method to generate fromJSon method
  String generateCopyWithMethod(String className, Map<String, FieldData> fields) {
    // Buffer to write each part of generated class
    final buffer = StringBuffer();

    // --------------------Start copyWith Generation Code--------------------//
    buffer.writeln("// Extension for a $className class to provide 'copyWith' method");
    buffer.writeln('extension \$${className}Extension on $className {');
    buffer.writeln('$className copyWith({');
    for (var entry in fields.entries) {
      final name = entry.key;
      String dataType = entry.value.typeString.replaceAll('?', '');
      final bool isOptional = entry.value.typeString.contains('?');
      dataType = dataType.replaceAll("?", "");
      bool isList = dataType.startsWith('List<');
      String fieldName = name;
      buffer.writeln(
        '$dataType? $fieldName,',
      );
    }
    buffer.writeln('}) {');
    buffer.writeln('return $className(');
    for (var entry in fields.entries) {
      final name = entry.key;
      buffer.writeln(
        "$name: $name ?? this.$name,",
      );
    }
    buffer.writeln(');');
    buffer.writeln('}');
    buffer.writeln('}');
    buffer.toString();
    return buffer.toString();
    // --------------------End copyWith Generation Code--------------------//
  }
}
