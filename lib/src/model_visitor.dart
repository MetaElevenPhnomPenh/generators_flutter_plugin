import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class FieldData {
  final String typeString;
  final List<String> metadata;

  const FieldData({
    required this.typeString,
    required this.metadata,
  });
}

class ModelVisitor extends RecursiveAstVisitor<void> {
  String className = '';
  Map<String, FieldData> fields = {};

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    className = node.name.lexeme;
    super.visitClassDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (var variable in node.fields.variables) {
      final name = variable.name.lexeme;

      final type = node.fields.type?.toSource() ?? 'dynamic';

      final metadata = node.metadata
          .map((m) => m.toSource())
          .toList();

      fields[name] = FieldData(
        typeString: type,
        metadata: metadata,
      );
    }

    super.visitFieldDeclaration(node);
  }
}