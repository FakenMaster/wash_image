import 'package:stringx/stringx.dart';

class HaffmanTable {
  /// 0 = DC table, 1 = AC table
  int type;

  /// number of HT (0..3, otherwise error)
  int id;

  List<int> category;
  List<String> codeWord;

  HaffmanTable({
    required this.type,
    required this.id,
    this.category = const [],
    this.codeWord = const [],
  });

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    String categoryLabel = type == 0 ? 'Category' : 'Run/Size';
    buffer
      ..writeln('type:${type==0?'DC':'AC'}$id')
      ..write('$categoryLabel'.padRight(20, ' '))
      ..write('Code Length'.padRight(20, ' '))
      ..writeln('Code Word'.padRight(20, ' '));

    category.mapWithIndex((i, value) {
      String codeWordValue = codeWord[i];
      String categoryString = '$value';
      if (type == 1) {
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
}
