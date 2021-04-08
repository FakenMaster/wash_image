import 'block.dart';

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

  /// 反量化
  MCU inverseQT(List<Block> quantizationTables) {
    /// luminance quantization table: quantizationTables[0]
    /// chrominance quantization table: chrominanceTables[1]
    List<Block> resultY = [];
    List<Block> resultCb = [];
    List<Block> resultCr = [];

    Block luminanceTable = quantizationTables[0];
    Block chrominanceTable = quantizationTables[1];

    Y.forEach((inputY) {
      resultY.add(inputY.inverseQT(luminanceTable));
    });

    Cb.forEach((inputCb) {
      resultCb.add(inputCb.inverseQT(chrominanceTable));
    });

    Cr.forEach((inputCr) {
      resultCr.add(inputCr.inverseQT(chrominanceTable));
    });

    return MCU(Y: resultY, Cb: resultCb, Cr: resultCr);
  }

  /// 反离散余弦变换
  MCU inverseDCT() {
    List<Block> resultY = [];
    List<Block> resultCb = [];
    List<Block> resultCr = [];

    Y.forEach((inputY) {
      resultY.add(inputY.inverseDCT());
    });

    Cb.forEach((inputCb) {
      resultCb.add(inputCb.inverseDCT());
    });

    Cr.forEach((inputCr) {
      resultCr.add(inputCr.inverseDCT());
    });

    return MCU(Y: resultY, Cb: resultCb, Cr: resultCr);
  }
}
