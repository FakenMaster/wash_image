import 'dart:math';
import 'dart:typed_data';
import '../../util/util.dart';
import 'package:collection/collection.dart';

const ZigZag = [
  // [0,0],
  // [0,1],[1,0],
  // [2,0],[1,1],[0,2],
  // [0,3],[1,2],[2,1],[3,0],
  // [4,0],[3,1],[2,2],[1,3],[0,4],
  // [0,5],[1,4],[2,3],[3,2],[4,1],[5,0],
  // [6,0],[5,1],[4,2],[3,3],[2,4],[1,5],[0,6],
  // [0,7],[1,6],[2,5],[3,4],[4,3],[5,2],[6,1],[7,0],
  // [7,1],[6,2],[5,3],[4,4],[3,5],[2,6],[1,7],
  // [2,7],[3,6],[4,5],[5,4],[6,3],[7,2],
  // [7,3],[6,4],[5,5],[4,6],[3,7],
  // [4,7],[5,6],[6,5],[7,4],
  // [7,5],[6,6],[5,7],
  // [6,7],[7,6],
  // [7,7],
  [0, 0],
  [0, 1], [1, 0],
  [2, 0], [1, 1], [0, 2],
  [0, 3], [1, 2], [2, 1], [3, 0],
  [4, 0], [3, 1], [2, 2], [1, 3], [0, 4],
  [0, 5], [1, 4], [2, 3], [3, 2], [4, 1], [5, 0],
  [6, 0], [5, 1], [4, 2], [3, 3], [2, 4], [1, 5], [0, 6],
  [0, 7], [1, 6], [2, 5], [3, 4], [4, 3], [5, 2], [6, 1], [7, 0],
  [7, 1], [6, 2], [5, 3], [4, 4], [3, 5], [2, 6], [1, 7],
  [2, 7], [3, 6], [4, 5], [5, 4], [6, 3], [7, 2],
  [7, 3], [6, 4], [5, 5], [4, 6], [3, 7],
  [4, 7], [5, 6], [6, 5], [7, 4],
  [7, 5], [6, 6], [5, 7],
  [6, 7], [7, 6],
  [7, 7],
];

const List<int> ZIGZAG = [
  0,
  1,
  5,
  6,
  14,
  15,
  27,
  28,
  2,
  4,
  7,
  13,
  16,
  26,
  29,
  42,
  3,
  8,
  12,
  17,
  25,
  30,
  41,
  43,
  9,
  11,
  18,
  24,
  31,
  40,
  44,
  53,
  10,
  19,
  23,
  32,
  39,
  45,
  52,
  54,
  20,
  22,
  33,
  38,
  46,
  51,
  55,
  60,
  21,
  34,
  37,
  47,
  50,
  56,
  59,
  61,
  35,
  36,
  48,
  49,
  57,
  58,
  62,
  63
];

/// block是8*8的矩阵
class Block {
  List<int> _block;
  Block([List<int>? block]) : this._block = block ?? Int32List(64);

  List<int> get block => _block;

  Block operator *(Block input) {
    _block.forEachIndexed((index, element) {
      _block[index] *= input.block[index];
    });
    return this;
  }

  /// Z型还原
  zigZag() {
    _block.forEachIndexed((index, element) {
      _block[ZIGZAG[index]] = element;
    });
  }

  /// 反量化:origin = input * qt;
  inverseQT(List<int> quantizationTable) {
    _block.forEachIndexed((index, element) {
      _block[index] *= quantizationTable[index];
    });
  }

  /// 反离散余弦转换
  void inverseDCT() {
    double c(int value) => value == 0 ? 1 / sqrt2 : 1;

    int d(int x, int y, List<int> origin) {
      double value = 0;
      for (int u = 0; u < 8; u++) {
        for (int v = 0; v < 8; v++) {
          value += (c(u) *
              c(v) *
              origin[u * 8 + v] *
              cos((2 * x + 1) * u * pi / 16) *
              cos((2 * y + 1) * v * pi / 16));
        }
      }
      return (value / 4).round();
    }

    _block.forEachIndexed((index, value) {
      _block[index] =
          (d(index ~/ 8, index % 8, _block) + 128).clampUnsignedByte;
    });
  }

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    block.forEachIndexed((index, element) {
      buffer.write('$element, ');
      if (index % 8 == 7) {
        buffer.writeln(']');
      }
    });
    return buffer.toString();
  }
}
