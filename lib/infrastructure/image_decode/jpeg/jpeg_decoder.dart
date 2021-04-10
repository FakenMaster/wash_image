import 'dart:html';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_jfif.dart';
import 'package:wash_image/infrastructure/model/src/image_info.dart';
import 'package:wash_image/infrastructure/model/src/quantization_table.dart';

import '../../util/util.dart';
import '../../model/model.dart';
import 'package:stringx/stringx.dart';

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
  int soi = JPEG_SOF0;
  int offset = 0;
  DecodeResult? result;
  StringBuffer debugMessage;
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

  void skip(int size) {
    offset += size;
  }

  /// check start of image
  bool checkSOI() {
    int soi = readWord();
    print('SOI: ${soi.toRadix()}\n');
    return soi == JPEG_SOI;
  }

  /// check segment
  bool checkSegment() {
    int segment = readWord();

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
        getSOF();
        break;
      case JPEG_SOF2:
        soi = JPEG_SOF2;
        getSOF();
        break;
      case JPEG_DHT:
        getDHT();
        break;
      default:

        /// 其他marker
        print('segment:${segment.toRadix()}');
        return false;
    }

    return checkSegment();
  }

  bool getAPP0() {
    int remain = readWord() - 2;
    print('APP0剩下字节数:$remain');

    int identifier = readDWord();
    int suffix = readByte();
    remain -= 5;
    print('identifier: ${identifier.toRadix()}');

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

    ///
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
  bool getDQT() {
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

    return true;
  }

  /// define haffman table(s)
  bool getDHT() {
    int length = readWord() - 2;
    print('DHT:${JPEG_DHT.toRadix()}, 长度:$length');

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
    return true;
  }

  /// start of frame(baseline DCT)
  bool getSOF() {
    int length = readWord() - 2;
    final sof = {
      JPEG_SOF0.toRadix(): 'SOF0',
      JPEG_SOF2.toRadix(): 'SOF2',
    };
    String sofStr = soi.toRadix();

    print('${sof[sofStr]}:$sofStr , 长度:$length');
    if (length != 15) {
      return false;
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
    return true;
  }

  /// check start of scan
  bool getSOS() {
    int length = readWord() - 2;

    int number = readByte();
    print('SOS:${JPEG_SOS.toRadix()}, 长度:$length, component个数:$number');

    Map<int, String> componentMap = {1: 'Y', 2: 'Cb', 3: 'Cr', 4: 'I', 5: 'Q'};
    for (int i = 0; i < number; i++) {
      int componentId = readByte();
      int huffmanTable = readByte();
      int dc = huffmanTable >> 4;
      int ac = huffmanTable & 0x0f;
      print(
          '#$i componentId:$componentId=>${(componentMap[componentId] ?? '').padRight(2)}, AC$ac ++ DC$dc');

      imageInfo.setComponentDCAC(componentId, dc, ac);
    }
    print("");

    /// 三个无用字符
    skip(3);

    /// 紧随其后，就是压缩图像的数据了
    readCompressedData();

    // print('哈夫曼编码：${HaffmanEncoder.encode('go go gophers')}');
    return true;
  }

  /// 读取压缩数据
  void readCompressedData() {
    int input = readByte();
    List<List<int>> scanDatas = [];
    List<int> datas = [];
    while (true) {
      if (input == 0xFF) {
        int marker = readByte();

        if (marker == 0x00) {
          //过滤掉，并把input作为数据插入
          datas.add(input);
        } else if (marker == 0xD9) {
          //文件结束
          scanDatas.add(datas);
          getEOI();
          break;
        } else if (marker >= 0xD0 && marker <= 0xD7) {
          //重置dc差值，还原成0
          scanDatas.add(datas);
          datas = [];
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

    int dataBytes = 0;
    scanDatas.forEach((element) {
      dataBytes += element.length;
    });
    print('字节数:$dataBytes');

    dataStrings = scanDatas
        .map((datas) => datas
            .map((item) => item.binaryString)
            .reduce((value, element) => value + element))
        .toList();

    readMCUs();
    print('得到的MCU总共是:${imageInfo.mcus.length}, 理应是:${imageInfo.mcuNumber}\n');
    if (imageInfo.mcus.length == 0) {
      print('没有可解析的数据，是解析出错了吧\n');
      return;
    }
    printData(String title, [int index = 1999]) {
      if (imageInfo.mcus.length < index) {
        return;
      }
      MCU mcu = imageInfo.mcus[index];
      int yIndex = 0;
      debugMessage.writeln('\n$title $index:');
      mcu.Y.forEach((element) {
        debugMessage.writeln('Y${yIndex++}：');
        for (int i = 0; i < 8; i++) {
          debugMessage.write('[');
          for (int j = 0; j < 8; j++) {
            debugMessage.write('${element.block[i][j]}, ');
          }
          debugMessage.writeln(']');
        }
      });

      debugMessage.writeln('Cb：');
      for (int i = 0; i < 8; i++) {
        debugMessage.write('[');
        for (int j = 0; j < 8; j++) {
          debugMessage.write('${mcu.Cb[0].block[i][j]}, ');
        }
        debugMessage.writeln(']');
      }

      debugMessage.writeln('Cr：');
      for (int i = 0; i < 8; i++) {
        debugMessage.write('[');
        for (int j = 0; j < 8; j++) {
          debugMessage.write('${mcu.Cr[0].block[i][j]}, ');
        }
        debugMessage.writeln(']');
      }
    }

    // printData('第一次的数据', 4);
    printData('第一次的数据');

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

    // printData('反量化的数据');
    printData('反量化的数据');

    /// 还原Y/U/V值
    List<List<PixelYUV>> yuvs = imageInfo.yuv();

    /// 还原RGB值
    List<List<PixelRGB>> rgbs =
        yuvs.map((list) => list.map((e) => e.convert2RGB()).toList()).toList();

    StringBuffer buffer = StringBuffer();
    buffer
      ..writeln('P3')
      ..writeln("${imageInfo.width} ${imageInfo.height}")
      ..writeln("255");

    for (int i = 0; i < imageInfo.height; i++) {
      for (int j = 0; j < imageInfo.width; j++) {
        buffer
          ..write("${rgbs[i][j].R} ")
          ..write("${rgbs[i][j].G} ")
          ..writeln("${rgbs[i][j].B}");
      }
    }

    if (kIsWeb) {
      var blob = Blob([buffer.toString()], 'text/plain', 'native');

      var anchorElement = AnchorElement(
        href: Url.createObjectUrlFromBlob(blob).toString(),
      )
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
    print('${dataStrings.length}个重置DC值的MCU段:');
    dataStrings.mapWithIndex((index, element) {
      print('第$index个:');
      readMCU(element);
    }).toList();
  }

  readMCU(String dataString) {
    /// Y、U、V各自有直流差分矫正变量，如果数据流中出现RSTn,那么三个颜色的矫正变量都要改变
    List<int> lastDC = [0, 0, 0];
    int dataIndex = 0;

    /// 获取值的表：
    /// https://www.w3.org/Graphics/JPEG/itu-t81.pdf 139页的
    /// Table H.2 – Difference categories for lossless Huffman coding
    int getValueByCode(String inputValueCode) {
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

    String getStringData(int dcLength) {
      if (dataIndex + dcLength > dataString.length) {
        throw ArgumentError('数据不够了');
      }
      return dataString.substring(dataIndex, dataIndex + dcLength);
    }

    int getDCValue(HaffmanTable table, int dcIndex) {
      int dcLength = 1;

      //有可能这一段的dataString已经读取结束，剩下的几位bit是用于凑足字节而已
      while (true) {
        String codeWord = getStringData(dcLength);

        if (table.codeWord.contains(codeWord)) {
          dataIndex += dcLength;
          // 计算DC值
          int category = table.category[table.codeWord.indexOf(codeWord)];

          int dcValue = category == 0
              ? lastDC[dcIndex]
              : getValueByCode(getStringData(category)) + lastDC[dcIndex];
          lastDC[dcIndex] = dcValue;
          dataIndex += category;
          return dcValue;
        } else {
          dcLength++;
        }
      }
    }

    List<int> getACValue(HaffmanTable table) {
      int acLength = 1;
      List<int> result = [];

      while (true) {
        String codeWord = dataString.substring(dataIndex, dataIndex + acLength);

        if (table.codeWord.contains(codeWord)) {
          dataIndex += acLength;
          int category = table.category[table.codeWord.indexOf(codeWord)];

          /// run表示前面有几个值是0
          int run = category >> 4;

          /// 这表示后面取几个bit表示值
          int size = category & 0x0f;

          if (run == 0 && size == 0) {
            result.addAll(List.generate(63 - result.length, (_) => 0));
          } else {
            result.addAll(List.generate(run, (_) => 0));

            int value = size == 0
                ? 0
                : getValueByCode(
                    dataString.substring(dataIndex, dataIndex + size));

            result.add(value);
          }
          dataIndex += size;
          acLength = 1;
          if (result.length == 63) {
            break;
          }
        } else {
          acLength++;
        }
      }

      return result;
    }

    while (dataIndex < dataString.length) {
      try {
        List<Block> luminance = List.generate(4, (index) {
          Block result = Block();

          /// DC值
          int dcValue = getDCValue(imageInfo.yHaffmanTable(true)!, 0);

          /// AC值
          List<int> acValues = getACValue(imageInfo.yHaffmanTable(false)!);

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
          int dcValue = getDCValue(imageInfo.cbHaffmanTable(true)!, 1);

          /// AC值
          List<int> acValues = getACValue(imageInfo.cbHaffmanTable(false)!);

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
          int dcValue = getDCValue(imageInfo.crHaffmanTable(true)!, 2);

          /// AC值
          List<int> acValues = getACValue(imageInfo.crHaffmanTable(false)!);

          result.block[0][0] = dcValue;
          for (int j = 0; j < acValues.length; j++) {
            int line = (j + 1) ~/ 8;
            int column = (j + 1) % 8;
            result.block[line][column] = acValues[j];
          }
          return result;
        });

        imageInfo.mcus
            .add(MCU(Y: luminance, Cb: chrominanceCb, Cr: chrominanceCr));
      } catch (e) {
        print('错误:$e\n');
        break;
      }
    }
  }
}
