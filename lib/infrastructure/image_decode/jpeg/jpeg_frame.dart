import 'dart:math';
import 'dart:typed_data';

import 'package:wash_image/infrastructure/model/src/jpeg_component.dart';

class JpegFrame {
  bool? extended;
  bool? progressive;
  int? precision;

  /// height
  int? scanLines;

  /// width
  int? samplesPerLine;
  int maxHSamples = 0;
  int maxVSamples = 0;
  late int mcusPerLine;
  late int mcusPerColumn;
  final components = <int, JpegComponent>{};
  final List<int> componentsOrder = <int>[];

  void prepare() {
    for (var componentId in components.keys) {
      final component = components[componentId]!;
      maxHSamples = max(maxHSamples, component.hSamples);
      maxVSamples = max(maxVSamples, component.vSamples);
    }

    /// 对于2*2取样率，宽*高是24*24来说

    /// 2
    mcusPerLine = (samplesPerLine! / 8 / maxHSamples).ceil();

    /// 2
    mcusPerColumn = (scanLines! / 8 / maxVSamples).ceil();

    for (var componentId in components.keys) {
      final component = components[componentId]!;

      /// 3
      final blocksPerLine =
          ((samplesPerLine! / 8).ceil() * component.hSamples / maxHSamples)
              .ceil();

      /// 3
      final blocksPerColumn =
          ((scanLines! / 8).ceil() * component.vSamples / maxVSamples).ceil();

      /// 4
      final blocksPerLineForMcu = mcusPerLine * component.hSamples;

      /// 4
      final blocksPerColumnForMcu = mcusPerColumn * component.vSamples;

      /// 这个blocks不是实际的数据，通常比实际的blocks多
      final blocks = List.generate(
          blocksPerColumnForMcu,
          (_) => List<Int32List>.generate(
              blocksPerLineForMcu, (_) => Int32List(64),
              growable: false),
          growable: false);

      component.blocksPerLine = blocksPerLine;
      component.blocksPerColumn = blocksPerColumn;
      component.blocks = blocks;
    }
  }
}
