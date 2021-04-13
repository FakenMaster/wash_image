import 'package:wash_image/infrastructure/model/model.dart';

/// 在一张图片中，这个信息是唯一的，和单个还是多个扫描行无关
const ComponentY = 1;
const ComponentCb = 2;
const ComponentCr = 3;
const ComponentI = 4;
const ComponentQ = 5;

const ComponentName = {
  ComponentY: 'Y',
  ComponentCb: 'Cb',
  ComponentCr: 'Cr',
  ComponentI: 'I',
  ComponentQ: 'Q',
};

const ComponentDCIndex = {
  ComponentY: 0,
  ComponentCb: 1,
  ComponentCr: 2,
};

class ComponentIDTable {
  int id;
  HuffmanTable? dcTable;
  HuffmanTable? acTable;

  ComponentIDTable({
    required this.id,
    this.dcTable,
    this.acTable,
  });

  @override
  String toString() {
    return "ComponentID:${ComponentName[id]} ===> DC:${dcTable?.id}, AC:${acTable?.id}";
  }
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
