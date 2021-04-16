import 'dart:typed_data';
/// 现在是Y/Cb/Cr三种
class JpegComponent {
  /// 水平取样
  int hSamples;

  /// 垂直取样
  int vSamples;

  /// 行 * 列 * 64个数据
  late List<List<List<int>>> blocks;

  final List<Int16List?> quantizationTableList;
  late int quantizationIndex;

  /// 一行多少个block
  late int blocksPerLine;

  /// 一列多少个block
  late int blocksPerColumn;

  late List huffmanTableDC;
  late List huffmanTableAC;

  /// 同一种component的上一个block的DC值
  late int pred;

  JpegComponent(this.hSamples, this.vSamples, this.quantizationTableList,
      this.quantizationIndex);

  Int16List? get quantizationTable => quantizationTableList[quantizationIndex];
}
