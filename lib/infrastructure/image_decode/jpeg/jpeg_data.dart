import 'dart:typed_data';

import 'dart:html';
import 'dart:math';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg.dart';
import 'package:wash_image/infrastructure/image_exception.dart';
import 'package:wash_image/infrastructure/model/src/image_info.dart';
import 'package:wash_image/infrastructure/model/src/jpeg_component.dart';
import 'package:wash_image/infrastructure/model/src/multi_scan_data.dart';
import 'package:wash_image/infrastructure/model/src/quantization_table.dart';
import 'package:wash_image/infrastructure/util/input_buffer.dart';

import '../../model/model.dart';
import '../../util/util.dart';
import 'jpeg_frame.dart';
import 'jpeg_jiff.dart';
import 'jpeg_scan.dart';

/// 1.读取各种Marker，方便后续数据解压
/// 2.读取压缩数据，根据采样比率，通常是Y Y Y Y Cb Cr，即4:2:0
/// 3.根据DHT恢复数据(DQT位置反ZigZag化)
/// 4.读取ScanData数据，每个数据反ZigZag化
/// 5.根据DQT反量化数据
/// 6.反DCT，还原YUV数据
////7.YUV还原成RGB
class JpegData {
  late InputBuffer input;
  late JpegJfif jfif;
  JpegFrame? frame;

  /// 读取了此值得MCU后重置DC的diff差值为0
  int? resetInterval;

  final quantizationTables = List<Int16List?>.filled(4, null);
  final frames = <JpegFrame?>[];
  final huffmanTablesDC = <List?>[];
  final huffmanTablesAC = <List?>[];

  int offset = 0;
  DecodeResult? result;
  StringBuffer debugMessage;

  List<List<int>> scanDatas = [];
  List<String> dataStrings = [];

  ImageInfo imageInfo;

  JpegData()
      : imageInfo = ImageInfo(),
        debugMessage = StringBuffer();

  DecodeResult fail() {
    result = DecodeResult.fail(debugMessage: debugMessage.toString());
    print(debugMessage.toString());
    return result!;
  }

  DecodeResult read(List<int> bytes) {
    try {
      input = InputBuffer(bytes, bigEndian: true);
      _read();

      /// TODO:后续操作
    } catch (e, stacktrace) {
      result = fail();
      Logger().e('错误Top:$e, $stacktrace');
    }

    return result ?? fail();
  }

  InputBuffer _readBlock() {
    final length = input.readUint16();
    if (length < 2) {
      throw ImageException('Invalid Block');
    }
    return input.readBytes(length - 2);
  }

  _nextMarker() {
    /// 先读取到0xff,接下来就是marker了

    var c = 0;
    if (input.isEOS) {
      return c;
    }
    do {
      do {
        c = input.readByte();
      } while (c != 0xff && !input.isEOS);

      if (input.isEOS) {
        return c;
      }

      do {
        c = input.readByte();
      } while (c == 0xff && !input.isEOS);
    } while (c == 0 && !input.isEOS);
    return c;
  }

  /// check segment
  void _read() {
    var marker = _nextMarker();
    if (marker != Jpeg.M_SOI) {
      // SOI (Start of Image)
      throw Exception('Start Of Image marker not found.');
    }
    marker = _nextMarker();
    while (marker != Jpeg.M_EOI && !input.isEOS) {
      final block = _readBlock();
      switch (marker) {
        case Jpeg.M_APP0:
        case Jpeg.M_APP1:
        case Jpeg.M_APP2:
        case Jpeg.M_APP3:
        case Jpeg.M_APP4:
        case Jpeg.M_APP5:
        case Jpeg.M_APP6:
        case Jpeg.M_APP7:
        case Jpeg.M_APP8:
        case Jpeg.M_APP9:
        case Jpeg.M_APP10:
        case Jpeg.M_APP11:
        case Jpeg.M_APP12:
        case Jpeg.M_APP13:
        case Jpeg.M_APP14:
        case Jpeg.M_APP15:
        case Jpeg.M_COM:
          _readAppData(marker, block);
          break;
        case Jpeg.M_DQT:
          _readDQT(block);
          break;
        case Jpeg.M_SOF0:
        case Jpeg.M_SOF1:
        case Jpeg.M_SOF2:
          _readFrame(marker, block);
          break;
        case Jpeg.M_SOF3:
        case Jpeg.M_SOF5:
        case Jpeg.M_SOF6:
        case Jpeg.M_SOF7:
        case Jpeg.M_JPG:
        case Jpeg.M_SOF9:
        case Jpeg.M_SOF10:
        case Jpeg.M_SOF11:
        case Jpeg.M_SOF13:
        case Jpeg.M_SOF14:
        case Jpeg.M_SOF15:
          throw ImageException(
              'Unhandled frame type ${marker.toRadixString(16)}');

        case Jpeg.M_DHT:
          _readDHT(block);
          break;
        case Jpeg.M_DRI:
          _readDRI(block);
          break;

        case Jpeg.M_SOS:
          _readSOS(block);

          break;

        case 0xff: // Fill bytes
          if (input[0] != 0xff) {
            input.offset--;
          }
          break;

        default:
          if (input[-3] == 0xff && input[-2] >= 0xc0 && input[-2] <= 0xfe) {
            // could be incorrect encoding -- last 0xFF byte of the previous
            // block was eaten by the encoder
            input.offset -= 3;
            break;
          }

          if (marker != 0) {
            throw ImageException(
                'Unknown JPEG marker ${marker.toRadixString(16)}');
          }
          break;
      }
    }
  }

  void _readDRI(InputBuffer block) {
    resetInterval = block.readUint16();
  }

  void _readAppData(int marker, InputBuffer block) {
    final appData = block;
    if (marker == Jpeg.M_APP0) {
      // 'JFIF\0'
      if (appData[0] == 0x4A &&
          appData[1] == 0x46 &&
          appData[2] == 0x49 &&
          appData[3] == 0x46 &&
          appData[4] == 0) {
        jfif = JpegJfif();
        jfif.majorVersion = appData[5];
        jfif.minorVersion = appData[6];
        jfif.densityUnits = appData[7];
        jfif.xDensity = (appData[8] << 8) | appData[9];
        jfif.yDensity = (appData[10] << 8) | appData[11];
        jfif.thumbWidth = appData[12];
        jfif.thumbHeight = appData[13];
        final thumbSize = 3 * jfif.thumbWidth * jfif.thumbHeight;
        jfif.thumbData = appData.subset(14 + thumbSize, offset: 14);
      }
    }

    /// TODO:其他APP数据
  }

  /// define quantization table(s)
  _readDQT(InputBuffer block) {
    while (!block.isEOS) {
      var n = block.readByte();
      final precision = n >> 4;
      n &= 0x0F;

      if (quantizationTables[n] == null) {
        quantizationTables[n] = Int16List(64);
      }

      final tableData = quantizationTables[n];
      for (int i = 0; i < 64; i++) {
        tableData![Jpeg.dctZigZag[i]] =
            precision == 0 ? block.readByte() : block.readUint16();
      }
    }

    if (!block.isEOS) {
      throw ImageException('Bad length for DQT block');
    }
  }

  _readDHT(InputBuffer block) {
    while (!block.isEOS) {
      var index = block.readByte();
      final bits = Uint8List(16);

      /// 总共存在多个个有效数
      var count = 0;
      for (var j = 0; j < 16; j++) {
        /// 1-16位的哈夫曼编码各自有多少个
        bits[j] = block.readByte();
        count += bits[j];
      }

      final huffmanValues = Uint8List(count);
      for (var j = 0; j < count; j++) {
        huffmanValues[j] = block.readByte();
      }

      List ht;
      if (index & 0x10 != 0) {
        // AC table
        index -= 0x10;
        ht = huffmanTablesAC;
      } else {
        ht = huffmanTablesDC;
      }

      if (ht.length <= index) {
        ht.length = index + 1;
      }

      ht[index] = _buildHuffmanTable(bits, huffmanValues);
    }
  }

  /// TODO:这个实现方法先不研究，反正我自己实现了一遍了，知道怎么获取
  List? _buildHuffmanTable(Uint8List codeLengths, Uint8List values) {
    var k = 0;
    final code = <_JpegHuffman>[];
    var length = 16;

    while (length > 0 && (codeLengths[length - 1] == 0)) {
      length--;
    }

    code.add(_JpegHuffman());

    var p = code[0];
    _JpegHuffman q;

    /// 最开始的有效位数
    var firstBitLength = 1 + codeLengths.indexWhere((length) => length != 0);

    for (int i = firstBitLength - 1; i < codeLengths.length; i++) {
      int bitLength = i + 1;
      int count = codeLengths[i];
    }

    codeLengths.forEachIndexed((index, length) {});

    for (var i = 0; i < length; i++) {
      for (var j = 0; j < codeLengths[i]; j++) {
        p = code.removeLast();
        if (p.children.length <= p.index) {
          p.children.length = p.index + 1;
        }
        p.children[p.index] = values[k];
        while (p.index > 0) {
          p = code.removeLast();
        }
        p.index++;
        code.add(p);
        while (code.length <= i) {
          q = _JpegHuffman();
          code.add(q);
          if (p.children.length <= p.index) {
            p.children.length = p.index + 1;
          }
          p.children[p.index] = q.children;
          p = q;
        }
        k++;
      }

      if ((i + 1) < length) {
        // p here points to last code
        q = _JpegHuffman();
        code.add(q);
        if (p.children.length <= p.index) {
          p.children.length = p.index + 1;
        }
        p.children[p.index] = q.children;
        p = q;
      }
    }

    return code[0].children;
  }

  /// define haffman table(s)
  // getDHT() {
  //   int information = readByte();
  //   int type = information >> 4;

  //   int number = information & 0x0f;

  //   List<int> codeLength = [];
  //   for (int i = 0; i < 16; i++) {
  //     int number = readByte();

  //     if (number != 0) {
  //       codeLength.addAll(List.generate(number, (_) => i + 1));
  //     }
  //   }

  //   int categoryNumber = codeLength.length;

  //   List<int> categoryList = [];
  //   List<String> codeWordList = [];
  //   for (int i = 0; i < categoryNumber; i++) {
  //     categoryList.add(readByte());
  //   }

  //   length -= 1 + 16 + categoryNumber;

  //   String currentCodeWord = '';
  //   int lastLength = codeLength[0];
  //   for (int i = 0; i < codeLength[0]; i++) {
  //     currentCodeWord += '0';
  //   }
  //   codeWordList.add(currentCodeWord);

  //   int lastValue = 0;

  //   for (int i = 1; i < codeLength.length; i++) {
  //     int currentLength = codeLength[i];

  //     int nowValue = (lastValue + 1) << (currentLength - lastLength);

  //     currentCodeWord = nowValue.toRadixString(2).padLeft(currentLength, '0');
  //     codeWordList.add(currentCodeWord);

  //     lastLength = currentLength;
  //     lastValue = nowValue;
  //   }

  //   HuffmanTable table = HuffmanTable(
  //       type: type, id: number, category: categoryList, codeWord: codeWordList);
  //   print('$table');
  //   // 这个应该存储在单独的ScanData中
  //   imageInfo.addHuffmanTable(table);
  // }

  void _readFrame(int marker, InputBuffer block) {
    if (frame != null) {
      throw ImageException('Duplicate JPG frame data found.');
    }

    frame = JpegFrame();
    frame!.extended = (marker == Jpeg.M_SOF1);
    frame!.progressive = (marker == Jpeg.M_SOF2);
    frame!.precision = block.readByte();
    frame!.scanLines = block.readUint16();
    frame!.samplesPerLine = block.readUint16();

    final numComponents = block.readByte();

    for (var i = 0; i < numComponents; i++) {
      final componentId = block.readByte();
      final x = block.readByte();
      final h = (x >> 4) & 15;
      final v = x & 15;
      final qId = block.readByte();
      frame!.componentsOrder.add(componentId);
      frame!.components[componentId] =
          JpegComponent(h, v, quantizationTables, qId);
    }

    frame!.prepare();
    frames.add(frame);
  }

  void _readSOS(InputBuffer block) {
    final n = block.readByte();
    if (n < 1 || n > Jpeg.MAX_COMPS_IN_SCAN) {
      throw ImageException('Invalid SOS block');
    }

    final components = List<JpegComponent>.generate(n, (index) {
      final id = block.readByte();
      final c = block.readByte();

      if (!frame!.components.containsKey(id)) {
        throw ImageException('Invalid Component in SOS block');
      }

      final component = frame!.components[id]!;

      final dc_tbl_no = (c >> 4) & 15;
      final ac_tbl_no = c & 15;

      if (dc_tbl_no < huffmanTablesDC.length) {
        component.huffmanTableDC = huffmanTablesDC[dc_tbl_no]!;
      }
      if (ac_tbl_no < huffmanTablesAC.length) {
        component.huffmanTableAC = huffmanTablesAC[ac_tbl_no]!;
      }

      return component;
    });

    final spectralStart = block.readByte();
    final spectralEnd = block.readByte();
    final successiveApproximation = block.readByte();

    final Ah = (successiveApproximation >> 4) & 15;
    final Al = successiveApproximation & 15;

    JpegScan(input, frame!, components, resetInterval, spectralStart,
            spectralEnd, Ah, Al)
        .decode();
  }
}

class _JpegHuffman {
  final children = <dynamic>[];
  int index = 0;
}
