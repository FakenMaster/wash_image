import 'block.dart';
import 'haffman_table.dart';
import 'image_info.dart';

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

  int getDCValue(HaffmanTable table, int dcIndex) {
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

  List<int> getACValue(HaffmanTable table) {
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
          result.addAll(List.generate(63 - result.length, (_) => 0));
        } else {
          result.addAll(List.generate(run, (_) => 0));

          int value = size == 0 ? 0 : getValueByCode(readString(size));

          result.add(value);
        }
        offset += size;
        length = 1;
        if (result.length == 63) {
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
        /// 压缩数据最后如果不足一个字节，要补1
        print('错误:$e\n');
        break;
      }
    }
  }

  void generateMCUProgressive(ImageInfo imageInfo) {
    while (offset < dataString.length) {
      //这部分内容获取
      try {
        List<Block> luminance = List.generate(4, (index) {
          Block result = Block();

          /// DC值
          int dcValue = getDCValue(imageInfo.yHaffmanTable(true)!, 0);
          result.block[0][0] = dcValue;
          return result;
        });

        List<Block> chrominanceCb = List.generate(1, (index) {
          Block result = Block();

          // DC值
          int dcValue = getDCValue(imageInfo.cbHaffmanTable(true)!, 1);

          result.block[0][0] = dcValue;
          return result;
        });

        List<Block> chrominanceCr = List.generate(1, (index) {
          Block result = Block();

          /// DC值
          int dcValue = getDCValue(imageInfo.crHaffmanTable(true)!, 2);

          result.block[0][0] = dcValue;
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
}
