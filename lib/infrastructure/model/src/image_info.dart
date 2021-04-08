import 'package:wash_image/infrastructure/image_encode/block.dart';
import 'package:wash_image/infrastructure/model/model.dart';
import 'package:wash_image/infrastructure/model/src/quantization_table.dart';

class ImageInfo {
  Map<int, QuantizationTable> quantizationTables;

  int precision;
  int width;
  int height;

  int maxSamplingH;
  int maxSamplingV;

  Map<int, ComponentInfo> componentInfos;
  List<HaffmanTable> haffmanTables;

  ImageInfo({
    required this.precision,
    required this.width,
    required this.height,
    required this.maxSamplingH,
    required this.maxSamplingV,
  })   : componentInfos = {},
        quantizationTables = {},
        haffmanTables = [];

  /// MCU个数
  int get mcuNumber => horizontalMCU * verticalMCU;

  /// mcuColumn: 每个block是8*8，每个mcu中Y/U/V的大小为各自 sampling * block.size
  int get horizontalMCU => (width / (maxSamplingH * 8)).ceil();

  /// mcuVertical
  int get verticalMCU => (height / (maxSamplingV * 8)).ceil();

  /// Y component
  ComponentInfo? get YInfo => componentInfos[1];

  /// U component
  ComponentInfo? get UInfo => componentInfos[2];

  /// V component
  ComponentInfo? get VInfo => componentInfos[3];

  QuantizationTable? qt(int qtId) => quantizationTables[qtId];

  HaffmanTable? ht(int type, int id) => haffmanTables.firstWhere(
      (element) => element.type == type && element.id == id,
      orElse: null);
}

class ComponentInfo {
  /// 1 = Y, 2 = Cb, 3 = Cr, 4 = I, 5 = Q
  int componentId;

  /// 水平取样值
  int horizontalSampling;

  /// 垂直取样值
  int verticalSampling;

  /// 量化表id
  int qtId;

  static const ComponentName = {
    1: 'Y',
    2: 'Cb',
    3: 'Cr',
    4: 'I',
    5: 'Q',
  };

  ComponentInfo({
    required this.componentId,
    required this.horizontalSampling,
    required this.verticalSampling,
    required this.qtId,
  });

  int get sampling => horizontalSampling * verticalSampling;
  @override
  String toString() {
    return '颜色分量 id:$componentId=>${ComponentName[componentId]}, 水平采样率:$horizontalSampling, 垂直采样率:$verticalSampling, 量化表id:$qtId';
  }
}
