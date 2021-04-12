import 'block.dart';
import 'quantization_table.dart';

class MCU {
  /// luminance
  List<Block> Y;

  /// chrominance
  List<Block> Cb;
  List<Block> Cr;

  MCU({
    required this.Y,
    required this.Cb,
    required this.Cr,
  });

  int get YLength => Y.length;
  int get CbLength => Cb.length;
  int get CrLength => Cr.length;

  /// ZigZag还原数据
  MCU zigZag() {
    return MCU(
        Y: Y.map((e) => e.zigZag()).toList(),
        Cb: Cb.map((e) => e.zigZag()).toList(),
        Cr: Cr.map((e) => e.zigZag()).toList());
  }

  /// 左右移位
  MCU shiftLeft(List<int> shiftIndex, int shiftBit) {
    return MCU(
        Y: Y.map((e) => e.shiftLeft(shiftBit)).toList(),
        Cb: Cb.map((e) => e.shiftLeft(shiftBit)).toList(),
        Cr: Cr.map((e) => e.shiftLeft(shiftBit)).toList());
  }

  /// 反量化
  MCU inverseQT(Block yQuantizationTable, Block cbQuantizationTable,
      Block crQuantizationTable) {
    return MCU(
        Y: Y.map((e) => e.inverseQT(yQuantizationTable)).toList(),
        Cb: Cb.map((e) => e.inverseQT(cbQuantizationTable)).toList(),
        Cr: Cr.map((e) => e.inverseQT(crQuantizationTable)).toList());
  }

  /// 反离散余弦变换
  MCU inverseDCT() {
    return MCU(
        Y: Y.map((e) => e.inverseDCT()).toList(),
        Cb: Cb.map((e) => e.inverseDCT()).toList(),
        Cr: Cr.map((e) => e.inverseDCT()).toList());
  }
}
