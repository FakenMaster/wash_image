class ComponentInfo {
  /// 1 = Y, 2 = Cb, 3 = Cr, 4 = I, 5 = Q
  int componentId;

  /// 水平取样值
  int horizontalSampling;

  /// 垂直取样值
  int verticalSampling;

  /// dc表id
  late int dcId;

  /// ac表id
  late int acId;

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
