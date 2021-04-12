import 'package:wash_image/infrastructure/model/model.dart';
import 'package:wash_image/infrastructure/model/src/quantization_table.dart';
import 'package:stringx/stringx.dart';

class ImageInfo {
  bool progressive=false;
  int precision;
  int width;
  int height;

  int maxSamplingH;
  int maxSamplingV;

  List<QuantizationTable> quantizationTables;
  List<ComponentInfo> componentInfos;
  List<HaffmanTable> haffmanTables;

  List<MCU> mcus = [];

  ImageInfo({
    this.precision = 0,
    this.width = 0,
    this.height = 0,
    this.maxSamplingH = 0,
    this.maxSamplingV = 0,
  })  : componentInfos = [],
        quantizationTables = [],
        haffmanTables = [];

  /// MCU个数
  int get mcuNumber => columnMCU * lineMCU;

  /// MCU的列數
  int get columnMCU => (width / (maxSamplingH * 8)).ceil();

  /// MCU的行數
  int get lineMCU => (height / (maxSamplingV * 8)).ceil();

  /// 設置component的DC/AC的id值
  setComponentDCAC(int componentId, int dcId, int acId) {
    componentInfo(componentId)!
      ..dcId = dcId
      ..acId = acId;
  }

  ComponentInfo? componentInfo(int componentId) =>
      componentInfos.firstWhere((element) => element.componentId == componentId,
          orElse: null);

  /// Y component
  ComponentInfo? get yInfo => componentInfos
      .firstWhere((element) => element.componentId == 1, orElse: null);

  /// U component
  ComponentInfo? get cbInfo => componentInfos
      .firstWhere((element) => element.componentId == 2, orElse: null);

  /// V component
  ComponentInfo? get crInfo => componentInfos
      .firstWhere((element) => element.componentId == 3, orElse: null);

  QuantizationTable? qt(int qtId) => quantizationTables
      .firstWhere((element) => element.qtId == qtId, orElse: null);

  QuantizationTable? get yQuantizationTable => qt(yInfo!.qtId);
  QuantizationTable? get cbQuantizationTable => qt(cbInfo!.qtId);
  QuantizationTable? get crQuantizationTable => qt(crInfo!.qtId);

  HaffmanTable? ht(int type, int id) => haffmanTables.firstWhere(
      (element) => element.type == type && element.id == id,
      orElse: null);

  HaffmanTable? haffmanTable(int componentId, bool dc) {
    final info = componentInfo(componentId)!;
    return ht(dc ? 0 : 1, dc ? info.dcId : info.acId);
  }

  HaffmanTable? yHaffmanTable(bool dc) {
    final info = yInfo!;
    return ht(dc ? 0 : 1, dc ? info.dcId : info.acId);
  }

  HaffmanTable? cbHaffmanTable(bool dc) {
    final info = cbInfo!;
    return ht(dc ? 0 : 1, dc ? info.dcId : info.acId);
  }

  HaffmanTable? crHaffmanTable(bool dc) {
    final info = crInfo!;
    return ht(dc ? 0 : 1, dc ? info.dcId : info.acId);
  }

  yuv() {
    /// 还原Y/U/V值
    int mcuLinePixels = maxSamplingV * 8;
    int mcuColumnPixels = maxSamplingH * 8;

    print('MCU 行*列:$lineMCU * $columnMCU');

    List<List<int>> yPixels = List.generate(lineMCU * mcuLinePixels,
        (index) => List.generate(columnMCU * mcuColumnPixels, (index) => 0));
    List<List<int>> uPixels = List.generate(lineMCU * mcuLinePixels,
        (index) => List.generate(columnMCU * mcuColumnPixels, (index) => 0));
    List<List<int>> vPixels = List.generate(lineMCU * mcuLinePixels,
        (index) => List.generate(columnMCU * mcuColumnPixels, (index) => 0));

    luminace(List<Block> blockList, int pixelLine, int pixelColumn,
        List<List<int>> result) {
      blockList
          .mapWithIndex((number, block) => block
              .mapWithIndex(
                  (indexLine, list) => list.mapWithIndex((indexColumn, value) {
                        int nowLine = pixelLine + 8 * (number ~/ 2) + indexLine;
                        int nowColumn =
                            pixelColumn + 8 * (number % 2) + indexColumn;
                        yPixels[nowLine][nowColumn] = value;
                      }).toList())
              .toList())
          .toList();
    }

    chrominance(
        Block block, int pixelLine, int pixelColumn, List<List<int>> result) {
      block
          .mapWithIndex(
              (indexLine, list) => list.mapWithIndex((indexColumn, value) {
                    int nowLine = pixelLine + indexLine * 2;
                    int nowColumn = pixelColumn + indexColumn * 2;
                    result[nowLine][nowColumn] = result[nowLine + 1]
                        [nowColumn] = result[nowLine]
                            [nowColumn + 1] =
                        result[nowLine + 1][nowColumn + 1] = value;
                  }).toList())
          .toList();
    }

    for (int i = 0; i < lineMCU; i++) {
      for (int j = 0; j < columnMCU; j++) {
        MCU mcu = mcus[i * columnMCU + j];
        int pixelLine = i * 16;
        int pixelColumn = j * 16;

        luminace(mcu.Y, pixelLine, pixelColumn, yPixels);

        chrominance(mcu.Cb[0], pixelLine, pixelColumn, uPixels);
        chrominance(mcu.Cr[0], pixelLine, pixelColumn, vPixels);
      }
    }

    return yPixels
        .mapWithIndex((i, list) => list.mapWithIndex((j, y) {
              return PixelYUV(y, uPixels[i][j], vPixels[i][j]);
            }).toList())
        .toList();
  }
}
