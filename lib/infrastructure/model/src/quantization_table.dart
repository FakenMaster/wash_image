import 'dart:typed_data';

import 'package:collection/collection.dart';

class QuantizationTable {
  int qtId;
  Int16List block;
  QuantizationTable({
    required this.qtId,
    required this.block,
  });

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('id:$qtId');

    block.forEachIndexed((index, element) {
      if (index % 8 == 0) {
        buffer.write('[');
      }
      buffer.write('$element, ');
      if (index % 8 == 7) {
        buffer.writeln(']');
      }
    });

    return buffer.toString();
  }
}
