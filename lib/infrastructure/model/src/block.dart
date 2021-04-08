import 'dart:math';
import '../../util/util.dart';
import 'package:stringx/stringx.dart';

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

/// block是8*8的矩阵
class Block {
  List<List<int>> _block;
  Block([List<List<int>>? block])
      : this._block = block ??
            List.generate(8, (index) => List.generate(8, (index) => 0));

  List<List<int>> get block => _block;

  int item(int i, int j) => _block[i][j];

  void setItem(int i, int j, int value) {
    _block[i][j] = value;
  }

  Block operator *(Block input) {
    return Block(block
        .mapWithIndex((i, list) =>
            list.mapWithIndex((j, value) => value * input.item(i, j)).toList())
        .toList());
  }

  Iterable<T> mapWithIndex<T>(T Function(int i, List<int> list) function) {
    return block.asMap().entries.map((e) => function(e.key, e.value));
  }

  /// Z型还原
  Block zigZag() {
    return Block(mapWithIndex((i, list) => list.mapWithIndex((j, value) {
          List<int> position = ZigZag[i * 8 + j];
          return block[position[0]][position[1]];
        }).toList()).toList());
  }

  /// 反量化:origin = input * qt;
  Block inverseQT(Block quantizationTable) {
    return this * quantizationTable;
  }

  /// 反离散余弦转换
  Block inverseDCT() {
    double c(int value) => value == 0 ? 1 / sqrt2 : 1;

    int d(int x, int y, Block origin) {
      int N = 8;
      double value = 0;
      for (int u = 0; u < N; u++) {
        for (int v = 0; v < N; v++) {
          value += c(u) *
              c(v) *
              origin.block[u][v] *
              cos((2 * x + 1) * u * pi / 16) *
              cos((2 * y + 1) * v * pi / 16);
        }
      }
      return (value / 4).round();
    }

    return Block(mapWithIndex((i, list) => list
        .mapWithIndex((j, value) => (d(i, j, this) + 128).clampUnsignedByte)
        .toList()).toList());
  }

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < block.length; i++) {
      buffer.write('[');
      block[i].forEach((element) {
        buffer.write('$element, ');
      });
      buffer.writeln(']');
    }
    return buffer.toString();
  }
}
