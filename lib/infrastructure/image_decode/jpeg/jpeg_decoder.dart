import 'dart:html';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_jfif.dart';
import 'package:wash_image/infrastructure/util/src/haffman_encoder.dart';

import '../../util/src/int_extension.dart';
import 'package:stringx/stringx.dart';
import '../../model/model.dart';

class JPEGDecoder {
  static DecodeResult decode(Uint8List? dataBytes) {
    if (dataBytes == null || dataBytes.isEmpty) {
      return DecodeResult.fail();
    }

    return _JPEGDecoderInternal(dataBytes.buffer.asByteData()).decode();
  }
}

/// 1.读取各种Marker，方便后续数据解压
/// 2.读取压缩数据，根据采样比率，通常是Y Y Y Y Cb Cr，即4:2:0
/// 3.根据DHT恢复数据
/// 4.ZigZag还原数据顺序
/// 5.根据DQT反量化数据
/// 6.反DCT，还原YUV数据
////7.YUV还原成RGB
class _JPEGDecoderInternal {
  final ByteData bytes;
  int offset = 0;
  DecodeResult? result;
  StringBuffer debugMessage;
  late int widthPixel;
  late int heightPixel;
  String dataString = '';

  int mcuColumn = 0;
  int mcuLine = 0;

  List<MCU> mcus = [];

  late Map<int, List<List<int>>> colorSampling = {
    1: List.generate(3, (index) => List.generate(2, (index) => 0)),
    2: List.generate(3, (index) => List.generate(2, (index) => 0)),
    3: List.generate(3, (index) => List.generate(2, (index) => 0)),
  };
  late int maxHorizontalSampling;
  late int maxVerticalSampling;

  /// Quantization Tables
  List<Block> quantizationTables = List.generate(2, (index) => Block());

  ///[DC0 DC1]
  ///[AC0 AC1]
  List<HaffmanTable> haffmanTables =
      List.generate(4, (index) => HaffmanTable());

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
          debugMessage.write('$value ');
          if (i % 8 == 7) {
            debugMessage.write('\n');
          }
          quantizationTables[id].block[i ~/ 8][i % 8] = value;
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

    List<int> categoryList = [];
    List<String> codeWordList = [];
    debugMessage.writeln('\n叶子信号源:数量$categoryNumber');
    for (int i = 0; i < categoryNumber; i++) {
      categoryList.add(bytes.getUint8(offset + i));
      debugMessage.write('${categoryList[i].toRadix(padNum: 2)} ');
    }

    offset += categoryNumber;
    length -= 1 + 16 + categoryNumber;
    debugMessage.writeln('\n');

    String currentCodeWord = '';
    int lastLength = codeLength[0];
    for (int i = 0; i < codeLength[0]; i++) {
      currentCodeWord += '0';
    }
    codeWordList.add(currentCodeWord);

    int lastValue = 0;

    for (int i = 1; i < codeLength.length; i++) {
      int currentLength = codeLength[i];

      int nowValue = (lastValue + 1) << (currentLength - lastLength);

      currentCodeWord = nowValue.toRadixString(2).padLeft(currentLength, '0');
      codeWordList.add(currentCodeWord);

      lastLength = currentLength;
      lastValue = nowValue;
    }

    haffmanTables[haffmanTableIndex] = HaffmanTable(categoryList, codeWordList);

    String categoryLabel = dCOrAC == 0 ? 'Category' : 'Run/Size';
    debugMessage
      ..write('$categoryLabel'.padRight(20, ' '))
      ..write('Code Length'.padRight(20, ' '))
      ..write('Code Word'.padRight(20, ' '))
      ..writeln();

    for (int i = 0; i < categoryList.length; i++) {
      int category = categoryList[i];
      String codeWord = codeWordList[i];
      String categoryString = '$category';
      if (dCOrAC == 1) {
        int run = (category & 0xF0) >> 4;
        int size = (category & 0x0F);
        categoryString = '$run/$size';
      }

      debugMessage
        ..write('$categoryString'.padRight(30, ' '))
        ..write('${codeWord.length}'.padRight(30, ' '))
        ..write(codeWord.padRight(30, ' '))
        ..writeln();
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

    int byte = bytes.getUint8(offset++);
    List<int> scanDatas = [];
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
    dataString = scanDatas
        .map((e) => e.binaryString)
        .reduce((value, element) => value + element);

    readMCUs();

    print('width:$widthPixel, height:$heightPixel');
    mcuColumn = (widthPixel / 16).ceil();
    mcuLine = (heightPixel / 16).ceil();

    /// 反ZigZag => 反量化 => 反离散余弦转换
    mcus = mcus
        .map((e) => e.zigZag().inverseQT(quantizationTables).inverseDCT())
        .toList();

    debugMessage.writeln(
        'MCU个数:${mcus.length}: mcuColumn * mcuLine:$mcuColumn * $mcuLine');
    MCU mcu = mcus[0];
    debugMessage
      ..writeln('第一个Y')
      ..writeln('${mcu.Y}')
      ..writeln('第一个Cb')
      ..writeln('${mcu.Cb}')
      ..writeln()
      ..writeln('第一个Cr')
      ..writeln('${mcu.Cr}')
      ..writeln();

    List<List<int>> yPixels = List.generate(
        mcuLine * 16, (index) => List.generate(mcuColumn * 16, (index) => 0));

    List<List<int>> uPixels = List.generate(
        mcuLine * 16, (index) => List.generate(mcuColumn * 16, (index) => 0));

    List<List<int>> vPixels = List.generate(
        mcuLine * 16, (index) => List.generate(mcuColumn * 16, (index) => 0));

    List<List<int>> rPixels = List.generate(
        mcuLine * 16, (index) => List.generate(mcuColumn * 16, (index) => 0));

    List<List<int>> gPixels = List.generate(
        mcuLine * 16, (index) => List.generate(mcuColumn * 16, (index) => 0));

    List<List<int>> bPixels = List.generate(
        mcuLine * 16, (index) => List.generate(mcuColumn * 16, (index) => 0));

    /// 还原Y/U/V值
    for (int i = 0; i < mcus.length; i++) {
      /// 因为每个mcu有四个Y,1个Cb,一个Cr
      MCU mcu = mcus[i];
      int line = (i ~/ mcuColumn) * 16;
      int column = (i % mcuColumn) * 16;

      // debugMessage.writeln('$mcuColumn * $mcuLine [$i]坐标:$line * $column');

      for (int j = 0; j < mcu.YLength; j++) {
        for (int indexLine = 0; indexLine < mcu.Y[j].length; indexLine++) {
          List<int> pixels = mcu.Y[j][indexLine];
          for (int indexColumn = 0;
              indexColumn < pixels.length;
              indexColumn++) {
            int value = pixels[indexColumn];

            int nowLine = line + 8 * (j ~/ 2) + indexLine;
            int nowColumn = column + 8 * (j % 2) + indexColumn;
            yPixels[nowLine][nowColumn] = value;
          }
        }
      }

      for (int indexLine = 0; indexLine < mcu.Cb.length; indexLine++) {
        List<int> pixels = mcu.Cb[indexLine];
        for (int indexColumn = 0; indexColumn < pixels.length; indexColumn++) {
          int value = pixels[indexColumn];

          int nowLine = line + indexLine * 2;
          int nowColumn = column + indexColumn * 2;
          uPixels[nowLine][nowColumn] = uPixels[nowLine + 1][nowColumn] =
              uPixels[nowLine][nowColumn + 1] =
                  uPixels[nowLine + 1][nowColumn + 1] = value;
        }
      }
      for (int indexLine = 0; indexLine < mcu.Cr.length; indexLine++) {
        List<int> pixels = mcu.Cr[indexLine];
        for (int indexColumn = 0; indexColumn < pixels.length; indexColumn++) {
          int value = pixels[indexColumn];

          int nowLine = line + indexLine * 2;
          int nowColumn = column + indexColumn * 2;
          vPixels[nowLine][nowColumn] = vPixels[nowLine + 1][nowColumn] =
              vPixels[nowLine][nowColumn + 1] =
                  vPixels[nowLine + 1][nowColumn + 1] = value;
        }
      }
    }

    debugMessage.writeln('还原block第一个Cb');

    debugMessage.writeln("\n");
    for (int i = 0; i < 8; i++) {
      debugMessage.write('[');
      for (int j = 0; j < 8; j++) {
        debugMessage.write('${uPixels[i][j]} ');
      }
      debugMessage.writeln(']');
    }
    debugMessage.writeln();

    debugMessage.writeln('还原block第一个Cr');

    debugMessage.writeln("\n");
    for (int i = 0; i < 8; i++) {
      debugMessage.write('[');
      for (int j = 0; j < 8; j++) {
        debugMessage.write('${vPixels[i][j]} ');
      }
      debugMessage.writeln(']');
    }
    debugMessage.writeln();

    /// 还原RGB值
    // int R = (Y + 1.402 * (Cr - 128)).round();
    // int G = (Y - 0.34414 * (Cb - 128) - 0.71414 * (Cr - 128)).round();
    // int B = (Y + 1.772 * (Cb - 128)).round();
    int getR(int Y, int Cb, int Cr) {
      return (Y + 1.402 * (Cr - 128)).round().clampUnsignedByte;
    }

    int getG(int Y, int Cb, int Cr) {
      return (Y - 0.34414 * (Cb - 128) - 0.71414 * (Cr - 128))
          .round()
          .clampUnsignedByte;
    }

    int getB(int Y, int Cb, int Cr) {
      return (Y + 1.772 * (Cb - 128)).round().clampUnsignedByte;
    }

    debugMessage.writeln('前64个YUV值 ');

    for (int i = 0; i < yPixels.length; i++) {
      for (int j = 0; j < yPixels[0].length; j++) {
        int y = yPixels[i][j];
        int u = uPixels[i][j];
        int v = vPixels[i][j];

        if (i < 8 && j < 8) {
          debugMessage
              .writeln('${yPixels[i][j]} ${uPixels[i][j]} ${vPixels[i][j]}');
        }

        rPixels[i][j] = (getR(y, u, v));
        gPixels[i][j] = (getG(y, u, v));
        bPixels[i][j] = (getB(y, u, v));
      }
    }

    StringBuffer buffer = StringBuffer();
    buffer..writeln('P3')..writeln("$widthPixel $heightPixel")..writeln("255");

    debugMessage.writeln('前64个RGB值 ');

    for (int i = 0; i < heightPixel; i++) {
      for (int j = 0; j < widthPixel; j++) {
        buffer
          ..writeln("${rPixels[i][j]}")
          ..writeln("${gPixels[i][j]}")
          ..writeln("${bPixels[i][j]}");
        if (i < 8 && j < 8) {
          debugMessage
              .writeln('${rPixels[i][j]} ${gPixels[i][j]} ${bPixels[i][j]}');
        }
      }
    }
    debugMessage.writeln("\n");
    if (kIsWeb) {
      var blob = Blob([buffer.toString()], 'text/plain', 'native');

      var anchorElement = AnchorElement(
        href: Url.createObjectUrlFromBlob(blob).toString(),
      )
        ..setAttribute("download", "data.ppm")
        ..click();
    }
  }

  /// check end of image
  bool getEOI() {
    debugMessage.writeln('文件解析结束，剩下的内容作为无关信息');
    return true;
  }

  readMCUs() {
    /// Y、U、V各自有直流差分矫正变量，如果数据流中出现RSTn,那么三个颜色的矫正变量都要改变
    List<int> lastDC = [0, 0, 0];
    int dataIndex = 0;

    /// 获取值的表：
    /// https://www.w3.org/Graphics/JPEG/itu-t81.pdf 139页的
    /// Table H.2 – Difference categories for lossless Huffman coding
    int getValueByCategory(String inputValueCode) {
      int signal = 1;
      String valueCode = '';
      if (inputValueCode.startsWith('0')) {
        signal = -1;
        // 说明是负数，取反计算对应的正数值
        for (int j = 0; j < inputValueCode.length; j++) {
          valueCode += inputValueCode[j] == '0' ? '1' : '0';
        }
      } else {
        valueCode = inputValueCode;
      }

      return signal * int.parse(valueCode, radix: 2);
    }

    int getDCValue(HaffmanTable table, int dcIndex) {
      int index = 0;
      while (true) {
        String codeWord =
            dataString.substring(dataIndex, dataIndex + index + 1);
        if (table.codeWord.contains(codeWord)) {
          dataIndex += index + 1;
          // 计算DC值
          int category = table.category[table.codeWord.indexOf(codeWord)];

          int dcValue = category == 0
              ? 0
              : getValueByCategory(
                      dataString.substring(dataIndex, dataIndex + category)) +
                  lastDC[dcIndex];
          lastDC[dcIndex] = dcValue;
          dataIndex += category;
          return dcValue;
        } else {
          index++;
        }
      }
    }

    List<int> getACValue(HaffmanTable table) {
      int index = 0;
      List<int> result = [];
      while (true) {
        String codeWord =
            dataString.substring(dataIndex, dataIndex + index + 1);

        if (table.codeWord.contains(codeWord)) {
          dataIndex += index + 1;
          int category = table.category[table.codeWord.indexOf(codeWord)];

          /// run表示前面有几个值是0
          int run = (category & 0xf0) >> 4;

          /// 这表示后面取几个bit表示值
          int size = category & 0x0f;

          if (run == 0 && size == 0) {
            result.addAll(List.generate(63 - result.length, (_) => 0));
          } else {
            result.addAll(List.generate(run, (_) => 0));

            int value = size == 0
                ? 0
                : getValueByCategory(
                    dataString.substring(dataIndex, dataIndex + size));

            result.add(value);
          }
          dataIndex += size;
          index = 0;
          if (result.length == 63) {
            break;
          }
        } else {
          index++;
        }
      }

      return result;
    }

    int all = mcuColumn * mcuLine;
    int length = 1;

    while (dataIndex < dataString.length) {
      List<Block> luminance = List.generate(4, (index) {
        Block result = Block();

        /// DC值
        int dcValue = getDCValue(haffmanTables[0], 0);

        /// AC值
        List<int> acValues = getACValue(haffmanTables[2]);

        result.block[0][0] = dcValue;
        for (int j = 0; j < acValues.length; j++) {
          int line = (j + 1) ~/ 8;
          int column = (j + 1) % 8;
          result.block[line][column] = acValues[j];
        }
        return result;
      });

      List<Block> chrominanceCb = List.generate(1, (index) {
        Block result = Block();

        /// DC值
        int dcValue = getDCValue(haffmanTables[1], 1);

        /// AC值
        List<int> acValues = getACValue(haffmanTables[3]);

        result.block[0][0] = dcValue;
        for (int j = 0; j < acValues.length; j++) {
          int line = (j + 1) ~/ 8;
          int column = (j + 1) % 8;
          result.block[line][column] = acValues[j];
        }
        return result;
      });
      List<Block> chrominanceCr = List.generate(1, (index) {
        Block result = Block();

        /// DC值
        int dcValue = getDCValue(haffmanTables[1], 2);

        /// AC值
        List<int> acValues = getACValue(haffmanTables[3]);

        result.block[0][0] = dcValue;
        for (int j = 0; j < acValues.length; j++) {
          int line = (j + 1) ~/ 8;
          int column = (j + 1) % 8;
          result.block[line][column] = acValues[j];
        }
        return result;
      });

      mcus.add(MCU(Y: luminance, Cb: chrominanceCb, Cr: chrominanceCr));

      if ((length++) == all) {
        //解析结束，剩下的都是多余填充的0，不作数
        print('$dataIndex === ${dataString.length}');
        break;
      }
    }
  }
}
