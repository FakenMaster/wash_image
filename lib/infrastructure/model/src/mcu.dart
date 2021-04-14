import 'package:image/image.dart';
import 'package:logger/logger.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_decoder.dart';
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

  /// TODO: 理解了首次DC/AC扫描的方法，继续实现DC/AC后续解析的方法
  /// Progressive的 DC/AC解析是分开的
  void decodeACFirst(HuffmanTable table, ImageInfo imageInfo) {
    int length = 1;
    int eobrun = 0;

    int mcuIndex = 0;
    MultiScanHeader header = imageInfo.currentScanHeader;
    int successive = header.succesiveLow;
    // TODO：把readString替换直接读取int的位读取，提高效率，省去offset和length变量的麻烦
    // 这叫单一职责、封装，不要暴露太多东西
    try {
      while (mcuIndex < imageInfo.mcuNumber) {
        MCU mcu = imageInfo.mcus[mcuIndex++];
        if (header.idTables.length == 1) {
          mcu.getBlock(header.idTables[0].id).forEach((block) {
            if (eobrun > 0) {
              eobrun--;
              return;
            }

            int start = header.spectralStart;
            int end = header.spectralEnd;

            while (start <= end) {
              String codeWord = readString(length);

              if (table.codeWord.contains(codeWord)) {
                offset += length;
                int category = table.category[table.codeWord.indexOf(codeWord)];

                /// run表示前面有几个值是0
                int run = category >> 4;

                /// 这表示后面取几个bit表示值
                int size = category & 0x0f;

                /// 在Progressive中第一次解析AC值的时候
                /// [run, size]
                /// 1. 如果 size != 0 , 那么就和Baseline一样中间加run个0，然后添加size值
                /// 2. 如果 size == 0 , 那么计算0的方法就变了：
                /// 一是 length1 = 读出此后run个位
                /// 二是 length2 = 1<<run，
                /// 三再减去1（表示当前这个block的End-Of-Band)
                /// 也就是 count = read(run) + 1<<run -1
                /// count表示了在此之后的count个block在本次扫描行中值都为0
                /// i.e: size=0, run=0, 那么count= 0 + 1 - 1 = 0,所以之后block就有非零值了。
                /// 再i.e: size=0, run=2, 假设之后两个bit的值是 01,
                /// 那么 count=1 + 1<<2 - 1 = 4,也就是之后四个block在本次扫描中值都为0
                /// 这种方法叫 EOBn 计数(n是run的值), count = EOBn - 1
                /// 范围为EOBn = [1<<n + 0, 1<<n + 2^n -1 ]，也就是[2^n, 2^(n+1)-1]
                /// 如果size=0 && run=15,那么和Baseline的AC类似，也就是包括当前位置的16个本block的参数全为0，与下一个block无关

                // if (run == 0 && size == 0) {
                //   result.addAll(List.generate(totalLength - result.length, (_) => 0));
                // } else {
                //   result.addAll(List.generate(run, (_) => 0));

                //   int value = size == 0 ? 0 : getValueByCode(readString(size));

                //   result.add(value);
                // }

                if (size == 0) {
                  if (run < 15) {
                    // offset += size;
                    eobrun = run == 0
                        ? 0
                        : int.parse(readString(run), radix: 2) + 1 << run - 1;
                    offset += run;
                    length = 1;
                    return;
                  }
                  start += 16;
                  continue;
                }

                start += run;
                block.block[start ~/ 8][start % 8] =
                    (getValueByCode(readString(size))) * (1 << successive);
                offset += size;

                length = 1;
              } else {
                length++;
              }
            }
          });
        }
      }
    } catch (e, stacktrace) {
      Logger().e('错误', e, stacktrace);
    }
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
      } catch (e, stacktrace) {
        /// 压缩数据最后如果不足一个字节，要补1
        print('错误Top:$e, $stacktrace\n');
        break;
      }
    }
  }

  void generateMCUProgressive(ImageInfo imageInfo,int index) {
    /// 当前ScanLine的header数据
    MultiScanHeader currentHeader = imageInfo.currentScanHeader;

    final length = currentHeader.spectralEnd - currentHeader.spectralStart + 1;

    if (index==0) {
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
                      currentHeader.getHuffmanTable(
                          componentId, HuffmanTableAC)!,
                      size)
                  .mapIndexed((index, value) {
                block.block[(startIndex + index) ~/ 8]
                    [(startIndex + index) % 8] = value;
              }).toList();
            }
          });
        });
      });
    } else {
      decodeACFirst(currentHeader.getHuffmanTable(ComponentY, HuffmanTableAC)!,
          imageInfo);
    }
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
      } catch (e, stacktrace) {
        /// 压缩数据最后如果不足一个字节，要补1
        print('错误:$e, $stacktrace\n');
        break;
      }
    }
  }
}

/// Progressive中多次扫描的数据
