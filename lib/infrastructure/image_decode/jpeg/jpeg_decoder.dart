import 'dart:html';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:stringx/stringx.dart';

import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_jfif.dart';
import 'package:wash_image/infrastructure/model/src/image_info.dart';
import 'package:wash_image/infrastructure/model/src/quantization_table.dart';

import '../../model/model.dart';
import '../../util/util.dart';

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

  List<List<int>> scanDatas = [];
  List<String> dataStrings = [];

  ImageInfo imageInfo;

  _JPEGDecoderInternal(this.bytes)
      : imageInfo = ImageInfo(),
        debugMessage = StringBuffer();

  DecodeResult fail() {
    result = DecodeResult.fail(debugMessage: debugMessage.toString());
    print(debugMessage.toString());
    return result!;
  }

  DecodeResult decode() {
    try {
      // start of image，必须有
      checkSOI();

      /// jfif app0 marker segment,必须有JFIF_APP0,JFXX_APP0有的话紧随其后，其他marker
      checkSegment();
    } catch (e) {
      result = fail();
      print('错误:$e');
    }

    return result ?? fail();
  }

  /// read 1 byte
  int readByte() => bytes.getUint8(offset++);

  /// read 2 byte
  int readWord() {
    int word = bytes.getUint16(offset);
    offset += 2;
    return word;
  }

  /// read 4 byte
  int readDWord() {
    int dWord = bytes.getUint32(offset);
    offset += 4;
    return dWord;
  }

  /// check start of image
  bool checkSOI() {
    int soi = readWord();
    print('SOI: ${soi.toRadix()}\n');
    return soi == JPEG_SOI;
  }

  /// check segment
  void checkSegment() {
    int segment = readWord();
    if (segment == JPEG_SOS) {
      getSOS();
      return;
    } else if (segment == JPEG_EOI) {
      getEOI();
      return;
    } else if (segment == JPEG_APP0) {
      getAPP0();
    } else if (segment == JPEG_DQT) {
      getDQT();
    } else if (segment == JPEG_DHT) {
      getDHT();
    } else if (segment >= JPEG_SOF0 && segment <= JPEG_SOFF) {
      imageInfo.progressive = segment == JPEG_SOF2;
      getSOF(segment);
    } else if (segment == JPEG_COM) {
      // 注释
      print('注释');
      return;
    } else {
      /// 其他marker
      print('segment:${segment.toRadix()}');
      return;
    }

    return checkSegment();
  }

  void getAPP0() {
    int remain = readWord() - 2;
    print('APP0剩下字节数:$remain');

    int identifier = readDWord();
    int suffix = readByte();
    remain -= 5;
    print('identifier: ${identifier.toRadix()}');

    if (suffix != NULL_BYTE) {
      return;
    }
    if (identifier == JPEG_IDENTIFIER_JFIF) {
      checkJFIFAPP0(remain);
    } else if (identifier == JPEG_IDENTIFIER_JFXX) {
      checkJFXXAPP0(remain);
    }
  }

  /// check jfif app0 marker segment
  bool checkJFIFAPP0(int remain) {
    /// jfif version
    int version0 = readByte();
    int version1 = readByte();
    remain -= 2;
    print('jfif版本:$version0.${version1.toRadix(padNum: 2, prefix: false)}');

    /// Units for the following pixel density fields
    Map<int, String> densityMessage = {
      00: ' No units; width:height pixel aspect ratio = Ydensity:Xdensity',
      01: 'Pixels per inch (2.54 cm)',
      02: 'Pixels per centimeter',
    };

    int density = readByte();
    remain -= 1;
    print(
        'density:${density.toRadix(padNum: 2, prefix: false)}:${densityMessage[density]}');

    int xDensity = readWord();
    int yDensity = readWord();
    remain -= 4;
    print('$xDensity * $yDensity');

    int xThumbnail = readByte();
    int yThumbnail = readByte();
    remain -= 2;
    print('thumbnail:$xThumbnail * $yThumbnail');

    /// thumbnail data :3*n 24bit RGB;with n = xThumbnail * yThumbnail
    offset += xThumbnail * yThumbnail;
    remain -= xThumbnail * yThumbnail;

    if (remain != 0) {
      return false;
    }
    print('JFIF解析成功\n');
    return true;
  }

  /// check jfif extension (jfxx) app0 marker segment
  bool checkJFXXAPP0(int remain) {
    return false;
  }

  /// define quantization table(s)
  getDQT() {
    int length = readWord() - 2;
    print('量化表：DQT:${JPEG_DQT.toRadix()}, 长度:$length');

    while (length > 0) {
      int sizeAndID = readByte();

      // precision of QT, 0 = 8 bit, otherwise 16 bit
      int precision = sizeAndID >> 4;

      int size = precision == 0 ? 1 : 2;
      int qtId = sizeAndID & 0x0f;

      Block block = Block();
      for (int i = 0; i < 64; i++) {
        int value = precision == 0 ? readByte() : readWord();

        block.block[i ~/ 8][i % 8] = value;
      }

      QuantizationTable table;
      imageInfo.quantizationTables.add(table =
          QuantizationTable(precision: precision, qtId: qtId, block: block));
      print('$table');

      length -= (1 + size * 64);
    }
  }

  /// define haffman table(s)
  getDHT() {
    int length = readWord() - 2;
    print('\nDHT:${JPEG_DHT.toRadix()}, 长度:$length');

    int information = readByte();
    int type = information >> 4;

    int number = information & 0x0f;

    List<int> codeLength = [];
    for (int i = 0; i < 16; i++) {
      int number = readByte();

      if (number != 0) {
        codeLength.addAll(List.generate(number, (_) => i + 1));
      }
    }

    int categoryNumber = codeLength.length;

    List<int> categoryList = [];
    List<String> codeWordList = [];
    for (int i = 0; i < categoryNumber; i++) {
      categoryList.add(readByte());
    }

    length -= 1 + 16 + categoryNumber;

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

    HaffmanTable table = HaffmanTable(
        type: type, id: number, category: categoryList, codeWord: codeWordList);
    print('$table');
    imageInfo.haffmanTables.add(table);
  }

  /// start of frame(baseline DCT)
  void getSOF(int soi) {
    int length = readWord() - 2;

    print('SOF${soi - 0xFFC0}:${soi.toRadix()} , 长度:$length');
    if (length != 15) {
      throw ArgumentError('SOF header length != 15');
    }
    int precision = readByte();
    int height = readWord();
    int width = readWord();

    int components = readByte(); // JFIF指定颜色空间为YCbCr，所以颜色分量数量固定为3

    print('图片精度:$precision, 宽度:$width, 高度:$height, 颜色分量:$components');

    int maxSamplingH = 1;
    int maxSamplingV = 1;

    /// https://github.com/MROS/jpeg_tutorial/blob/master/doc/%E8%B7%9F%E6%88%91%E5%AF%ABjpeg%E8%A7%A3%E7%A2%BC%E5%99%A8%EF%BC%88%E5%9B%9B%EF%BC%89%E8%AE%80%E5%8F%96%E5%A3%93%E7%B8%AE%E5%9C%96%E5%83%8F%E6%95%B8%E6%93%9A.md#%E8%AE%80%E5%8F%96-sof0-%E5%8D%80%E6%AE%B5
    for (int i = 0; i < components; i++) {
      int colorId = readByte();

      int subSample = readByte();
      int qtId = readByte();

      int horizontalSampling = subSample >> 4;
      int verticalSampling = subSample & 0x0f;

      maxSamplingH = max(maxSamplingH, horizontalSampling);
      maxSamplingV = max(maxSamplingV, verticalSampling);

      ComponentInfo info;
      imageInfo.componentInfos.add(info = ComponentInfo(
          componentId: colorId,
          horizontalSampling: horizontalSampling,
          verticalSampling: verticalSampling,
          qtId: qtId));

      /// 对应DQT中的量化表id
      print('$info');
    }

    imageInfo
      ..precision = precision
      ..width = width
      ..height = height
      ..maxSamplingH = maxSamplingH
      ..maxSamplingV = maxSamplingV;
    print("");
  }

  /// check start of scan
  void getSOS() {
    int length = readWord() - 2;

    int number = readByte();
    print(
        '#${scanDatas.length} SOS:${JPEG_SOS.toRadix()}, 长度:$length, component个数:$number');

    Map<int, String> componentMap = {1: 'Y', 2: 'Cb', 3: 'Cr', 4: 'I', 5: 'Q'};
    for (int i = 0; i < number; i++) {
      int componentId = readByte();
      int huffmanTable = readByte();
      int dc = huffmanTable >> 4;
      int ac = huffmanTable & 0x0f;
      print(
          'componentId:$componentId=>${(componentMap[componentId] ?? '').padRight(2)}, DC$dc ++ AC$ac');

      imageInfo.setComponentDCAC(componentId, dc, ac);
    }
    print("");

    /// start of spectral or predictor selector
    /// for sequential DCT,this shall be zero;
    /// 0-63
    int start = readByte();

    /// end of spectral selection
    /// 0-63,if start==0 then 0
    int end = readByte();
    if (start == 0) {
      end = 0;
    }

    /// successive approximation: Ah Al
    int sa = readByte();
    int ah = (sa >> 4) & 0x0F;
    int al = sa & 0x0F;

    print(
        'start spectral:$start, end spectral:$end, \nsuccesive approximation: high:$ah, low:$al');

    /// 紧随其后，就是压缩图像的数据了
    readCompressedData();
  }

  /// 读取压缩数据
  void readCompressedData() {
    int input = readByte();
    List<int> datas = [];
    bool newDHT = false;

    addData() {
      scanDatas.add(datas);
      datas = [];

      // 对于progressive模式，就应该开始解析这一段数据了。
      if (imageInfo.progressive && scanDatas.length == 1) {
        print('数据字节数:${scanDatas[0].length}');
        readMCUs();
      }
    }

    while (true) {
      if (input == 0xFF) {
        int marker = readByte();

        int segment = 0xFF00 + marker;

        if (segment == JPEG_EOI) {
          addData();
          getEOI();
          break;
        } else if (segment == JPEG_DRI) {
          print('DRI标记');
          return;
        } else if (segment >= JPEG_RST0 && segment <= JPEG_RST7) {
          //重置dc差值，还原成0
          addData();
        } else if (segment == JPEG_SOS) {
          /// progressive mode中，有多个SOS段
          //重置dc差值，还原成0
          if (!newDHT) {
            /// 本轮SOS没有新的DHT，所以上一个SOS的数据还没有保存
            addData();
          }
          newDHT = false;

          getSOS();
          return;
        } else if (segment == JPEG_DHT) {
          newDHT = true;
          addData();
          getDHT();
        } else if (marker == 0x00) {
          //过滤掉，并把0xFF作为数据插入
          datas.add(input);
        } else {
          datas.addAll([input, marker]);
        }
      } else {
        datas.add(input);
      }

      input = readByte();
    }

    if (scanDatas.isEmpty) {
      return;
    }

    print(
        '总共字节数:${scanDatas.map((e) => e.length).reduce((value, element) => value + element)}');
    if (!imageInfo.progressive) {
      readMCUs();
    }

    print('得到的MCU总共是:${imageInfo.mcus.length}, 理应是:${imageInfo.mcuNumber}\n');
    if (imageInfo.mcus.length == 0) {
      print('没有可解析的数据，是解析出错了吧\n');
      return;
    }

    /// 反量化 => 反ZigZag =>  反离散余弦转换
    imageInfo.mcus = imageInfo.mcus
        .map((e) => e
            .inverseQT(
                imageInfo.yQuantizationTable!.block,
                imageInfo.cbQuantizationTable!.block,
                imageInfo.crQuantizationTable!.block)
            .zigZag()
            .inverseDCT())
        .toList();

    /// 还原Y/U/V值
    List<List<PixelYUV>> yuvs = imageInfo.yuv();
    // printYUV(yuvs);

    printRGB(List<List<PixelRGB>> rgbs) {
      List<List<List<int>>> data = List.generate(
          3,
          (index) =>
              List.generate(8, (index) => List.generate(8, (index) => 0)));

      for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
          PixelRGB pixelRGB = rgbs[i][j];
          data[0][i][j] = pixelRGB.R;
          data[1][i][j] = pixelRGB.G;
          data[2][i][j] = pixelRGB.B;
        }
      }

      final titles = ['R', 'G', 'B'];
      for (int i = 0; i < 3; i++) {
        debugMessage.writeln('\n${titles[i]}:');
        for (int u = 0; u < 8; u++) {
          debugMessage.write('[');
          for (int v = 0; v < 8; v++) {
            debugMessage.write('${data[i][u][v]}, ');
          }
          debugMessage.writeln(']');
        }
      }
    }

    /// 还原RGB值
    List<List<PixelRGB>> rgbs =
        yuvs.map((list) => list.map((e) => e.convert2RGB()).toList()).toList();
    printRGB(rgbs);

    StringBuffer buffer = StringBuffer();
    buffer
      ..writeln('P3')
      ..writeln("${imageInfo.width} ${imageInfo.height}")
      ..writeln("255");

    for (int i = 0; i < imageInfo.height; i++) {
      for (int j = 0; j < imageInfo.width; j++) {
        buffer.writeln("${rgbs[i][j]}");
      }
    }

    if (kIsWeb) {
      var blob = Blob([buffer.toString()], 'text/plain', 'native');

      AnchorElement(href: Url.createObjectUrlFromBlob(blob).toString())
        ..setAttribute("download", "After__data.ppm")
        ..click();
    }
  }

  /// check end of image
  bool getEOI() {
    print('文件到头，解析结束，剩下的内容作为无关信息\n');
    return true;
  }

  readMCUs() {
    if (imageInfo.progressive) {
      /// Progressive解析MCU数据
      print(
          '解析Progressive, scanDatas长度:${scanDatas.length}, 第一个数据长度:${scanDatas[0].length}');

      MCUDataString(scanDatas[0].binaryString).generateMCUProgressive(imageInfo);
      return;
    }

    /// Baseline解析MCU数据
    scanDatas.forEach((element) {
      MCUDataString(element.binaryString).generateMCU(imageInfo);
    });
  }
}
