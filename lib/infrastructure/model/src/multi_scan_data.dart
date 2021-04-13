import 'package:wash_image/infrastructure/model/model.dart';
import 'package:collection/collection.dart';

class MultiScanData {
  /// 本轮扫描的数据参数
  MultiScanData({
    this.idTables = const [],
    this.spectralStart = 0,
    this.spectralEnd = 0,
    this.succesiveHigh = 0,
    this.succesiveLow = 0,
  });

  /// 需要处理的component
  List<ComponentIDTable> idTables;

  /// 64个数的开始位置
  int spectralStart;

  /// 64个数的结束为止（包括)
  int spectralEnd;

  /// 8位的高4位，不为0表示这个数的某些位已经被访问过了
  int succesiveHigh;

  /// 8位的低四位，如果succesiveHigh==0, 则本轮扫描7-succesiveLow的所有位数据
  /// 如果succesiveHigh!=0,则本轮扫描只扫描succesiveLow位数据
  int succesiveLow;

  HuffmanTable? getHuffmanTable(int componentId, int tableType) {
    ComponentIDTable? table =
        idTables.firstWhereOrNull((element) => element.id == componentId);

    if (table != null) {
      return tableType == HuffmanTableDC ? table.dcTable : table.acTable;
    }
    return null;
  }
}
