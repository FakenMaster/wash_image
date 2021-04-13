import 'package:wash_image/infrastructure/model/model.dart';
import 'package:wash_image/infrastructure/model/src/quantization_table.dart';
import 'package:wash_image/infrastructure/model/src/multi_scan_data.dart';
import 'component_info.dart';
import 'package:collection/collection.dart';

const LastDCIndexY = 0;
const LastDCIndexCb = 1;
const LastDCIndexCr = 2;

class ImageInfo {
  bool progressive = false;
  int precision;
  int width;
  int height;

  int maxSamplingH;
  int maxSamplingV;

  List<QuantizationTable> quantizationTables;
  List<ComponentInfo> componentInfos;

  /// 最近一次ScanData的Huffman Table
  List<HuffmanTable> _huffmanTables;

  List<MultiScanHeader> multiScanDatas;
  late MultiScanHeader currentScanHeader;

  List<MCU> mcus = [];

  ImageInfo({
    this.precision = 0,
    this.width = 0,
    this.height = 0,
    this.maxSamplingH = 0,
    this.maxSamplingV = 0,
  })  : componentInfos = [],
        quantizationTables = [],
        _huffmanTables = [],
        multiScanDatas = [];

  /// MCU个数
  int get mcuNumber => columnMCU * lineMCU;

  /// MCU的列數
  int get columnMCU => (width / (maxSamplingH * 8)).ceil();

  /// MCU的行數
  int get lineMCU => (height / (maxSamplingV * 8)).ceil();

  void initMCU() {
    mcus = List.generate(
        lineMCU * columnMCU,
        (index) => MCU(
            Y: List.generate(4, (index) => Block()),
            Cb: List.generate(1, (index) => Block()),
            Cr: List.generate(1, (index) => Block())));
  }

  ComponentInfo componentInfo(int componentId) => componentInfos
      .firstWhere((element) => element.componentId == componentId);

  /// Y component
  ComponentInfo get yInfo =>
      componentInfos.firstWhere((element) => element.componentId == ComponentY);

  /// U component
  ComponentInfo get cbInfo => componentInfos
      .firstWhere((element) => element.componentId == ComponentCb);

  /// V component
  ComponentInfo get crInfo => componentInfos
      .firstWhere((element) => element.componentId == ComponentCr);

  QuantizationTable qt(int qtId) =>
      quantizationTables.firstWhere((element) => element.qtId == qtId);

  QuantizationTable get yQuantizationTable => qt(yInfo.qtId);
  QuantizationTable get cbQuantizationTable => qt(cbInfo.qtId);
  QuantizationTable get crQuantizationTable => qt(crInfo.qtId);

  HuffmanTable? _ht(int type, int id) => _huffmanTables
      .firstWhereOrNull((element) => element.type == type && element.id == id);

  HuffmanTable getHuffmanTable(int componentId, int tableType) {
    return currentScanHeader.getHuffmanTable(componentId, tableType)!;
  }

  void addHuffmanTable(HuffmanTable table) {
    /// remove if present
    _huffmanTables
      ..remove(table)
      // ..removeWhere(
      //     (element) => element.type == table.type && element.id == table.id)
      ..add(table);
  }

  void addScanData(List<List<int>> componentIds, List<int> progressiveParams) {
    currentScanHeader = MultiScanHeader(
      idTables: componentIds
          .map((e) => ComponentIDTable(
                id: e[0],
                dcTable: _ht(HuffmanTableDC, e[1]),
                acTable: _ht(HuffmanTableAC, e[2]),
              ))
          .toList()
            ..sort((a, b) => a.id - b.id),
      spectralStart: progressiveParams[0],
      spectralEnd: progressiveParams[1],
      succesiveHigh: progressiveParams[2],
      succesiveLow: progressiveParams[3],
    );
    print('新添扫描头:$currentScanHeader');
    multiScanDatas.add(currentScanHeader);
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
          .mapIndexed((number, block) => block
              .mapWithIndex(
                  (indexLine, list) => list.mapIndexed((indexColumn, value) {
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
              (indexLine, list) => list.mapIndexed((indexColumn, value) {
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
        .mapIndexed((i, list) => list.mapIndexed((j, y) {
              return PixelYUV(y, uPixels[i][j], vPixels[i][j]);
            }).toList())
        .toList();
  }
}
