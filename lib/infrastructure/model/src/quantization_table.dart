import 'block.dart';

class QuantizationTable {
  int precision;
  int qtId;
  Block block;
  QuantizationTable({
    required this.precision,
    required this.qtId,
    required this.block,
  });

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    buffer
      ..writeln('id:$qtId')
      ..writeln(block.toString());

    return buffer.toString();
  }
}
