import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

const HuffmanTableDC = 0;
const HuffmanTableAC = 1;

class HuffmanTable with EquatableMixin {
  /// 0 = DC table, 1 = AC table
  int type;

  /// number of HT (0..3, otherwise error)
  int id;

  List<int> category;
  List<String> codeWord;

  HuffmanTable({
    required this.type,
    required this.id,
    this.category = const [],
    this.codeWord = const [],
  });

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    String categoryLabel = type == HuffmanTableDC ? 'Category' : 'Run/Size';
    buffer
      ..writeln('type:${type == HuffmanTableDC ? 'DC' : 'AC'}$id')
      ..write('$categoryLabel'.padRight(20, ' '))
      ..write('Code Length'.padRight(20, ' '))
      ..writeln('Code Word'.padRight(20, ' '));

    category.mapIndexed((i, value) {
      String codeWordValue = codeWord[i];
      String categoryString = '$value';
      if (type == HuffmanTableAC) {
        int run = (value & 0xF0) >> 4;
        int size = (value & 0x0F);
        categoryString = '$run/$size';
      }

      buffer
        ..write('$categoryString'.padRight(30, ' '))
        ..write('${codeWordValue.length}'.padRight(30, ' '))
        ..write(codeWordValue.padRight(30, ' '))
        ..writeln();
    }).toList();

    return buffer.toString();
  }

  @override
  List<Object?> get props => [id, type];
}
