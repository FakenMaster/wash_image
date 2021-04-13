import 'package:wash_image/infrastructure/model/src/multi_scan_data.dart';

import 'block.dart';
import 'component_info.dart';
import 'huffman_table.dart';
import 'image_info.dart';
import 'package:collection/collection.dart';

class MCU {
  /// luminance
  List<Block> Y;

  /// chrominance
  List<Block> Cb;
  List<Block> Cr;

  MCU({
    required this.Y,
    required this.Cb,
    required this.Cr,
  });

  int get YLength => Y.length;
  int get CbLength => Cb.length;
  int get CrLength => Cr.length;

  List<Block> getBlock(int componentId) {
    if (componentId == ComponentY) {
      return Y;
    } else if (componentId == ComponentCb) {
      return Cb;
    } else if (componentId == ComponentCr) {
      return Cr;
    }
    return [];
  }

  /// ZigZag还原数据
  MCU zigZag() {
    return MCU(
        Y: Y.map((e) => e.zigZag()).toList(),
        Cb: Cb.map((e) => e.zigZag()).toList(),
        Cr: Cr.map((e) => e.zigZag()).toList());
  }

  /// 左右移位
  MCU shiftLeft(List<int> shiftIndex, int shiftBit) {
    return MCU(
        Y: Y.map((e) => e.shiftLeft(shiftBit)).toList(),
        Cb: Cb.map((e) => e.shiftLeft(shiftBit)).toList(),
        Cr: Cr.map((e) => e.shiftLeft(shiftBit)).toList());
  }

  /// 反量化
  MCU inverseQT(Block yQuantizationTable, Block cbQuantizationTable,
      Block crQuantizationTable) {
    return MCU(
        Y: Y.map((e) => e.inverseQT(yQuantizationTable)).toList(),
        Cb: Cb.map((e) => e.inverseQT(cbQuantizationTable)).toList(),
        Cr: Cr.map((e) => e.inverseQT(crQuantizationTable)).toList());
  }

  /// 反离散余弦变换
  MCU inverseDCT() {
    return MCU(
        Y: Y.map((e) => e.inverseDCT()).toList(),
        Cb: Cb.map((e) => e.inverseDCT()).toList(),
        Cr: Cr.map((e) => e.inverseDCT()).toList());
  }
}

class MCUDataString {
  String dataString;

  /// Y、U、V各自有直流差分矫正变量，如果数据流中出现RSTn,那么三个颜色的矫正变量都要改变
  List<int> lastDC = [0, 0, 0];
  int offset = 0;
  MCUDataString(
    this.dataString,
  );

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

  String readString(int dcLength) {
    if (offset + dcLength > dataString.length) {
      throw ArgumentError('数据不够了,当前offset:$offset, 总共${dataString.length}位');
    }
    return dataString.substring(offset, offset + dcLength);
  }

  int getDCValue(HuffmanTable table, int dcIndex) {
    int length = 1;

    while (true) {
      String codeWord = readString(length);

      if (table.codeWord.contains(codeWord)) {
        offset += length;
        // 计算DC值
        int category = table.category[table.codeWord.indexOf(codeWord)];

        int dcValue = category == 0
            ? lastDC[dcIndex]
            : getValueByCode(readString(category)) + lastDC[dcIndex];
        lastDC[dcIndex] = dcValue;
        offset += category;
        return dcValue;
      } else {
        length++;
      }
    }
  }

  List<int> getACValues(HuffmanTable table, [int totalLength = 63]) {
    int length = 1;
    List<int> result = [];

    while (true) {
      String codeWord = readString(length);

      if (table.codeWord.contains(codeWord)) {
        offset += length;
        int category = table.category[table.codeWord.indexOf(codeWord)];

        /// run表示前面有几个值是0
        int run = category >> 4;

        /// 这表示后面取几个bit表示值
        int size = category & 0x0f;

        if (run == 0 && size == 0) {
          result.addAll(List.generate(totalLength - result.length, (_) => 0));
        } else {
          result.addAll(List.generate(run, (_) => 0));

          int value = size == 0 ? 0 : getValueByCode(readString(size));

          result.add(value);
        }
        offset += size;
        length = 1;
        if (result.length == totalLength) {
          break;
        }
      } else {
        length++;
      }
    }

    return result;
  }

  void generateMCU(ImageInfo imageInfo) {
    print('数据长度:${dataString.length}');
    while (offset < dataString.length) {
      try {
        List<Block> luminance = List.generate(4, (index) {
          Block result = Block();

          /// DC值
          int dcValue = getDCValue(
              imageInfo.getHuffmanTable(ComponentY, HuffmanTableDC),
              LastDCIndexY);

          /// AC值
          List<int> acValues = getACValues(
              imageInfo.getHuffmanTable(ComponentY, HuffmanTableAC));

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
          int dcValue = getDCValue(
              imageInfo.getHuffmanTable(ComponentCb, HuffmanTableDC),
              LastDCIndexCb);

          /// AC值
          List<int> acValues = getACValues(
              imageInfo.getHuffmanTable(ComponentCb, HuffmanTableAC));

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
          int dcValue = getDCValue(
              imageInfo.getHuffmanTable(ComponentCr, HuffmanTableDC),
              LastDCIndexCr);

          /// AC值
          List<int> acValues = getACValues(
              imageInfo.getHuffmanTable(ComponentCr, HuffmanTableAC));

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
        /// 压缩数据最后如果不足一个字节，要补1
        print('错误:$e\n');
        break;
      }
    }
  }

  void generateMCUProgressive(ImageInfo imageInfo) {
    /// 当前ScanLine的header数据
    MultiScanHeader currentHeader = imageInfo.currentScanHeader;

    final length = currentHeader.spectralEnd - currentHeader.spectralStart + 1;

    imageInfo.initMCU();
    imageInfo.mcus.forEach((mcu) {
      currentHeader.idTables.forEach((idTables) {
        int componentId = idTables.id;
        mcu.getBlock(componentId).forEach((block) {
          int startIndex = currentHeader.spectralStart;
          int size = length;
          if (startIndex == 0) {
            /// DC值
            block.block[startIndex ~/ 8][startIndex % 8] = getDCValue(
                currentHeader.getHuffmanTable(componentId, HuffmanTableDC)!,
                ComponentDCIndex[componentId]!);
            size -= 1;
            startIndex++;
          }

          if (size > 0) {
            getACValues(
                    currentHeader.getHuffmanTable(componentId, HuffmanTableAC)!,
                    size)
                .mapIndexed((index, value) {
              block.block[(startIndex + index) ~/ 8][(startIndex + index) % 8] =
                  value;
            }).toList();
          }
        });
      });
    });
    // while (offset < dataString.length) {
    //   try {
    //     List<Block> luminance = List.generate(4, (index) {
    //       Block result = Block();

    //       /// DC值
    //       int dcValue = getDCValue(
    //           imageInfo.getHuffmanTable(ComponentY, HuffmanTableDC),
    //           LastDCIndexY);
    //       result.block[0][0] = dcValue;
    //       return result;
    //     });

    //     List<Block> chrominanceCb = List.generate(1, (index) {
    //       Block result = Block();

    //       // DC值
    //       int dcValue = getDCValue(
    //           imageInfo.getHuffmanTable(ComponentCb, HuffmanTableDC),
    //           LastDCIndexCb);

    //       result.block[0][0] = dcValue;
    //       return result;
    //     });

    //     List<Block> chrominanceCr = List.generate(1, (index) {
    //       Block result = Block();

    //       /// DC值
    //       int dcValue = getDCValue(
    //           imageInfo.getHuffmanTable(ComponentCr, HuffmanTableDC),
    //           LastDCIndexCr);

    //       result.block[0][0] = dcValue;
    //       return result;
    //     });

    //     imageInfo.mcus
    //         .add(MCU(Y: luminance, Cb: chrominanceCb, Cr: chrominanceCr));
    //   } catch (e) {
    //     /// 压缩数据最后如果不足一个字节，要补1
    //     print('错误:$e\n');
    //     break;
    //   }
    // }
  }

  void generateMCUProgressive1(
      ImageInfo imageInfo, int spectralStart, int spectralEnd) {
    int totalLength = spectralEnd - spectralStart + 1;
    while (offset < dataString.length) {
      //这部分内容获取
      try {
        imageInfo.mcus.forEach((mcu) {
          mcu.Y.forEach((block) {
            List<int> result = getACValues(
                imageInfo.getHuffmanTable(ComponentY, HuffmanTableAC),
                totalLength);
            for (int i = 1; i <= 5; i++) {
              block.block[0][i] = result[i - 1];
            }
          });
        });
      } catch (e) {
        /// 压缩数据最后如果不足一个字节，要补1
        print('错误:$e\n');
        break;
      }
    }
  }
}

/// Progressive中多次扫描的数据
