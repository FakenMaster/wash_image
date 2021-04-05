import 'dart:math';
import 'dart:typed_data';

import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_jfif.dart';
import 'package:wash_image/infrastructure/util/haffman_encoder.dart';

import '../../util/int_extension.dart';

class JPEGDecoder {
  static DecodeResult decode(Uint8List? dataBytes) {
    if (dataBytes == null || dataBytes.isEmpty) {
      return DecodeResult.fail();
    }

    return _JPEGDecoderInternal(dataBytes.buffer.asByteData()).decode();
  }
}

class _JPEGDecoderInternal {
  final ByteData bytes;
  int offset = 0;
  DecodeResult? result;
  StringBuffer debugMessage;
  late int widthPixel;
  late int heightPixel;
  List<int> scanDatas = [];
  late Map<int, List<List<int>>> colorSampling = {
    1: List.generate(3, (index) => List.generate(2, (index) => 0)),
    2: List.generate(3, (index) => List.generate(2, (index) => 0)),
    3: List.generate(3, (index) => List.generate(2, (index) => 0)),
  };
  late int maxHorizontalSampling;
  late int maxVerticalSampling;

  ///[DC0 DC1]
  ///[AC0 AC1]
  List<List<HaffmanTable>> haffmanTables = List.generate(4, (index) => []);

  _JPEGDecoderInternal(this.bytes) : debugMessage = StringBuffer();

  DecodeResult fail() {
    result = DecodeResult.fail(debugMessage: debugMessage.toString());
    print(debugMessage.toString());
    return result!;
  }

  DecodeResult decode() {
    // start of image，必须有
    if (!checkSOI()) {
      return fail();
    }

    /// jfif app0 marker segment,必须有JFIF_APP0,JFXX_APP0有的话紧随其后，其他marker
    if (!checkSegment()) {
      return fail();
    }

    return result ?? fail();
  }

  /// check start of image
  bool checkSOI() {
    int soi = bytes.getUint16(offset);
    debugMessage..writeln('结果soi: ${soi.toRadix()}')..writeln();
    offset += 2;
    return soi == JPEG_SOI;
  }

  /// check segment
  bool checkSegment() {
    int segment = bytes.getUint16(offset);
    offset += 2;

    switch (segment) {
      case JPEG_SOS:
        return getSOS();
      case JPEG_EOI:
        getEOI();
        return true;
      case JPEG_APP0:
        if (!getAPP0()) {
          return false;
        }
        break;
      case JPEG_DQT:
        if (!getDQT()) {
          return false;
        }
        break;
      case JPEG_SOF0:
        if (!getSOF0()) {
          return false;
        }
        break;
      case JPEG_DHT:
        getDHT();
        break;
      default:

        /// 其他marker
        debugMessage.writeln('segment:${segment.toRadix()}');
        return false;
    }

    return checkSegment();
  }

  bool getAPP0() {
    // int app0 = bytes.getUint16(offset);
    // debugMessage..writeln('结果app0: ${app0.toRadix()}')..writeln();
    // offset += 2;

    // if (app0 != JPEG_APP0) {
    //   return false;
    // }

    int remain = bytes.getUint16(offset) - 2;
    debugMessage..writeln('app0剩下字节数:$remain')..writeln();
    offset += 2;

    int identifier = bytes.getUint32(offset);
    int suffix = bytes.getUint8(offset + 4);
    offset += 5;
    remain -= 5;
    debugMessage..writeln('identifier: ${identifier.toRadix()}')..writeln();

    if (suffix != NULL_BYTE) {
      return false;
    }
    if (identifier == JPEG_IDENTIFIER_JFIF) {
      return checkJFIFAPP0(remain);
    } else if (identifier == JPEG_IDENTIFIER_JFXX) {
      return checkJFXXAPP0(remain);
    }
    return false;
  }

  /// check jfif app0 marker segment
  bool checkJFIFAPP0(int remain) {
    /// jfif version
    int version0 = bytes.getUint8(offset);
    int version1 = bytes.getUint8(offset + 1);
    offset += 2;
    remain -= 2;
    debugMessage
      ..writeln(
          'jfif版本:$version0.${version1.toRadix(padNum: 2, prefix: false)}')
      ..writeln();

    /// Units for the following pixel density fields
    Map<int, String> densityMessage = {
      00: ' No units; width:height pixel aspect ratio = Ydensity:Xdensity',
      01: 'Pixels per inch (2.54 cm)',
      02: 'Pixels per centimeter',
    };

    ///
    int density = bytes.getUint8(offset);
    offset += 1;
    remain -= 1;
    debugMessage
      ..writeln(
          'density:${density.toRadix(padNum: 2, prefix: false)}:${densityMessage[density]}');

    int xDensity = bytes.getUint16(offset);
    int yDensity = bytes.getUint16(offset + 2);
    offset += 4;
    remain -= 4;
    debugMessage..writeln('$xDensity * $yDensity')..writeln();

    int xThumbnail = bytes.getUint8(offset);
    int yThumbnail = bytes.getUint8(offset + 1);
    offset += 2;
    remain -= 2;
    debugMessage..writeln('thumbnail:$xThumbnail * $yThumbnail');

    /// thumbnail data :3*n 24bit RGB;with n = xThumbnail * yThumbnail
    offset += xThumbnail * yThumbnail;
    remain -= xThumbnail * yThumbnail;

    if (remain != 0) {
      return false;
    }
    debugMessage..writeln('JFIF解析成功')..writeln();
    return true;
  }

  /// check jfif extension (jfxx) app0 marker segment
  bool checkJFXXAPP0(int remain) {
    return false;
  }

  /// define quantization table(s)
  bool getDQT() {
    int length = bytes.getUint16(offset) - 2;
    offset += 2;
    debugMessage.writeln('DQT:${JPEG_DHT.toRadix()}, 长度:$length');
    while (length > 0) {
      int sizeAndID = bytes.getUint8(offset);
      int size = sizeAndID & 0x10 == 0x00 ? 1 : 2;
      int id = sizeAndID & 0x0f;
      debugMessage.writeln('size:$size, id:$id');
      for (int i = 0; i < 64; i++) {
        for (int j = 0; j < size; j++) {
          int value = bytes.getUint8(offset + 1 + i * size + j);
          debugMessage.write('${value.toRadix(padNum: 2)} ');
        }
      }

      offset += 1 + size * 64;
      length -= (1 + size * 64);
    }
    debugMessage.writeln('\n');

    if (length != 0) {
      return false;
    }
    return true;
  }

  /// define haffman table(s)
  bool getDHT() {
    int length = bytes.getUint16(offset) - 2;
    offset += 2;
    debugMessage.writeln('DHT:${JPEG_DHT.toRadix()}, 长度:$length');

    Map<int, String> DC_AC = {
      0: 'DC',
      1: 'AC',
    };

    int information = bytes.getUint8(offset);
    int dCOrAC = information >> 4;

    int number = information & 0x0f;

    int haffmanTableIndex = dCOrAC * 2 + number;

    offset += 1;
    debugMessage.writeln('type:${DC_AC[dCOrAC]}$number');

    List<int> codeLength = [];
    for (int i = 0; i < 16; i++) {
      int number = bytes.getUint8(offset + i);
      debugMessage.write('${i + 1}位:${number.toRadix(padNum: 2)} ');

      if (number != 0) {
        codeLength.addAll(List.generate(number, (_) => i + 1));
      }
    }

    offset += 16;
    int categoryNumber = codeLength.length;

    List<int> category = [];
    debugMessage.writeln('\n叶子信号源:');
    for (int i = 0; i < categoryNumber; i++) {
      category.add(bytes.getUint8(offset + i));
      debugMessage.write('${category[i].toRadix(padNum: 2)} ');
    }
    offset += categoryNumber;
    length -= 1 + 16 + categoryNumber;
    debugMessage.writeln('\n');

    List<HaffmanTable> tables = [];
    String currentCodeWord = '';
    int lastLength = codeLength[0];
    for (int i = 0; i < codeLength[0]; i++) {
      currentCodeWord += '0';
    }
    int lastValue = 0;

    addHaffmanTable(int category, String codeWord) {
      tables.add(HaffmanTable(category: category, codeWord: codeWord));
    }

    addHaffmanTable(category[0], currentCodeWord);

    for (int i = 1; i < codeLength.length; i++) {
      int currentLength = codeLength[i];

      int nowValue = (lastValue + 1) << (currentLength - lastLength);

      currentCodeWord = nowValue.toRadixString(2).padLeft(currentLength, '0');

      addHaffmanTable(category[i], currentCodeWord);

      lastLength = currentLength;
      lastValue = nowValue;
    }

    haffmanTables[haffmanTableIndex] = tables;

    String categoryLabel = dCOrAC == 0 ? 'Category' : 'Run/Size';
    debugMessage
      ..write('$categoryLabel'.padRight(20, ' '))
      ..write('Code Length'.padRight(20, ' '))
      ..write('Code Word'.padRight(20, ' '))
      ..writeln();

    for (HaffmanTable table in tables) {
      String categoryString = '${table.category}';
      if (dCOrAC == 1) {
        int run = (table.category & 0xF0) >> 4;
        int size = (table.category & 0x0F);
        categoryString = '$run/$size';
      }

      debugMessage
        ..write('$categoryString'.padRight(30, ' '))
        ..write('${table.codeWord.length}'.padRight(30, ' '))
        ..write(table.codeWord.padRight(30, ' '))
        ..writeln();
    }

    if (length != 0) {
      return false;
    }
    return true;
  }

  /// start of frame(baseline DCT)
  bool getSOF0() {
    int length = bytes.getUint16(offset) - 2;
    offset += 2;
    debugMessage.writeln('SOF:${JPEG_SOF0.toRadix()}, 长度:$length');
    if (length != 15) {
      return false;
    }
    int precision = bytes.getUint8(offset);
    offset += 1;
    heightPixel = bytes.getUint16(offset);
    offset += 2;
    widthPixel = bytes.getUint16(offset);
    offset += 2;

    int components = bytes.getUint8(offset); // JFIF指定颜色空间为YCbCr，所以颜色分量数量固定为3
    offset += 1;

    debugMessage.writeln(
        '图片精度:$precision, 宽度:$widthPixel, 高度:$heightPixel, 颜色分量:$components');

    Map<int, String> colorIdMap = {
      1: 'Y',
      2: 'Cb',
      3: 'Cr',
    };

    /// https://github.com/MROS/jpeg_tutorial/blob/master/doc/%E8%B7%9F%E6%88%91%E5%AF%ABjpeg%E8%A7%A3%E7%A2%BC%E5%99%A8%EF%BC%88%E5%9B%9B%EF%BC%89%E8%AE%80%E5%8F%96%E5%A3%93%E7%B8%AE%E5%9C%96%E5%83%8F%E6%95%B8%E6%93%9A.md#%E8%AE%80%E5%8F%96-sof0-%E5%8D%80%E6%AE%B5
    int maxHSampling = 0;
    int maxVSampling = 0;
    for (int i = 0; i < 3; i++) {
      List<String> RGB = ['R', 'G', 'B'];
      for (int j = 0; j < 3; j++) {
        int colorId = bytes.getUint8(offset);

        /// 采样率，可以是1，2，3，4
        int subSample = bytes.getUint8(offset + 1);
        int horizontalSampling = subSample >> 4;
        int verticalSampling = subSample & 0x0f;
        maxHSampling = max(maxHSampling, horizontalSampling);
        maxVSampling = max(maxVSampling, verticalSampling);
        colorSampling[colorId]?[j][0] = horizontalSampling;
        colorSampling[colorId]?[j][1] = verticalSampling;

        /// 对应DQT中的量化表id
        int quantizationId = bytes.getUint8(offset + 2);

        debugMessage.writeln(
            '颜色分量id:$colorId=>${colorIdMap[colorId]}.${RGB[j]}, 水平采样率:$horizontalSampling, 垂直采样率:$verticalSampling, 量化表id:$quantizationId');
      }
      offset += 3;
    }
    maxHorizontalSampling = 8 * maxHSampling;
    maxVerticalSampling = 8 * maxVSampling;
    debugMessage.writeln('\n');

    return true;
  }

  /// check start of scan
  bool getSOS() {
    // int sos = bytes.getUint16(offset);
    // offset += 2;
    int length = bytes.getUint16(offset) - 2;
    offset += 2;

    int number = bytes.getUint8(offset);
    debugMessage
        .writeln('SOS:${JPEG_SOS.toRadix()}, 长度:$length, component个数:$number');
    offset += 1;
    length -= 1 + number * 2;

    Map<int, String> componentMap = {1: 'Y', 2: 'Cb', 3: 'Cr', 4: 'I', 5: 'Q'};
    for (int i = 0; i < number; i++) {
      int componentId = bytes.getUint8(offset);
      int huffmanTable = bytes.getUint8(offset + 1);
      int dc = huffmanTable >> 4;
      int ac = huffmanTable & 0x0f;
      offset += 2;
      debugMessage.writeln(
          '#$i huffman: componentId:$componentId=>${(componentMap[componentId] ?? '').padRight(2)}, AC$ac ++ DC$dc');
    }

    offset += 3;
    length -= 3;
    if (length != 0) {
      return false;
    }

    /// 紧随其后，就是压缩图像的数据了
    readCompressedData();

    // debugMessage.writeln('哈夫曼编码：${HaffmanEncoder.encode('go go gophers')}');
    return true;
  }

  /// 读取压缩数据
  void readCompressedData() {
    int horizontalMCU = (widthPixel / maxHorizontalSampling).ceil();
    int verticalMCU = (heightPixel / maxVerticalSampling).ceil();
    debugMessage.writeln('水平MCU:$horizontalMCU, 垂直MCU:$verticalMCU');

    void readDataValue() {}

    void readBlock() {
      for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
          readDataValue();
        }
      }
    }

    void readMCU() {
      colorSampling.forEach((key, value) {
        for (int i = 0; i < value[0][1]; i++) {
          for (int j = 0; j < value[0][0]; j++) {
            readBlock();
          }
        }
      });
    }

    // for (int i = 0; i < verticalMCU; i++) {
    //   for (int j = 0; j < horizontalMCU; j++) {
    //     readMCU();
    //   }
    // }
    int byte = bytes.getUint8(offset++);

    while (true) {
      if (byte == 0xFF) {
        int prevByte = byte;
        byte = bytes.getUint8(offset++);

        if (byte == 0xD9) {
          //文件结束
          debugMessage.write('\n');
          getEOI();
          break;
        }
        scanDatas.add(prevByte);
      }
      scanDatas.add(byte);

      byte = bytes.getUint8(offset++);
    }

    if (scanDatas.isEmpty) {
      return;
    }

    List<int?> newScanData = List.from(scanDatas);
    for (int i = 0; i < scanDatas.length; i++) {
      int byte = scanDatas[i];
      if (byte == 0xFF) {
        if (i + 1 < scanDatas.length - 1) {
          int nextByte = scanDatas[i + 1];
          if (nextByte == 0x00) {
            newScanData[i + 1] = null;
          }
        }
      }
    }

    scanDatas.clear();
    newScanData.forEach((element) {
      if (element != null) {
        scanDatas.add(element);
      }
    });

    debugMessage.writeln('原压缩数据:${scanDatas.length}');

    /// 因为得知下采样比例是4:2:0,所以排列是YYYYCbCr值，也就是4个Luminance，2个Chrominance
    /// 又由解析可知，Luminance的哈夫曼表是DC0+AC0,Chrominance的哈夫曼表是DC1+AC1
    String firstData = scanDatas[0].toRadixString(2).padLeft(8, '0');
    String secondData = scanDatas[1].toRadixString(2).padLeft(8, '0');
    // for (var byte in scanDatas) {
    //   debugMessage.write('${byte.toRadix(padNum: 2)} ');
    // }
    print('first:$firstData');
    print('second:$secondData');
  }

  /// check end of image
  bool getEOI() {
    debugMessage.writeln('文件解析结束，剩下的内容作为无关信息');
    return true;
  }
}

class HaffmanTable {
  /// DC:category, AC: Run/Size
  int category;
  String codeWord;
  HaffmanTable({
    required this.category,
    required this.codeWord,
  });
}
