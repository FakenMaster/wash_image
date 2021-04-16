import 'dart:math';
import 'dart:typed_data';

import 'package:wash_image/infrastructure/image_encode/block.dart';
import 'package:wash_image/infrastructure/image_encode/component.dart';
import 'package:wash_image/infrastructure/image_encode/mcu.dart';
import 'package:wash_image/infrastructure/model/src/pixel.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg.dart';
import 'package:wash_image/infrastructure/util/src/int_extension.dart';
import 'package:collection/collection.dart';
class PPMEncoder {
  late ByteData bytes;
  List<String> infos = [];
  List<String> comments = [];
  late String type;
  late int width;
  late int height;
  late int colorMax;
  late int byteOffset;

  List<List<PixelRGB>> rgbs = [];
  List<List<PixelYUV>> yuvs = [];

  List<Block> yBlocks = [];
  List<Block> uBlocks = [];
  List<Block> vBlocks = [];

  List<McuDCT> dcts = [];
  List<McuQT> qts = [];
  List<McuStr> strs = [];
  int previousDC = 0;

  PPMEncoder(Uint8List? data) {
    bytes = data!.buffer.asByteData();
  }

  encode() {
    readFile();
    colorSpaceConversion();
    splitIntoBlocks();
    discreteCosineTransform();

    /// 量化
    qts = dcts
        .map((e) => McuQT(e.yDCTs.map((e) => quantization(e)).toList(),
            quantization(e.uDCTs, false), quantization(e.vDCTs, false)))
        .toList();

    /// 蛇形

    previousDC = 0;
    strs = qts
        .map((e) => McuStr(
            e.yQTs.map((qt) => zigZagArrangement(qt, true)).toList(),
            zigZagArrangement(e.uQTs, false),
            zigZagArrangement(e.vQTs, false)))
        .toList();

    print('\n');
    strs.mapIndexed((i, value) {
      print('MCU:${i + 1}');
      value.yStrs.mapIndexed((j, str) {
        print('Y${j + 1}:\n$str');
      }).toList();
      print('Cb:\n${value.uStr}');
      print('Cr:\n${value.vStr}');
    }).toList();

    convert2JPEG();
  }

  readFile() {
    int dataStart = 0;
    byteOffset = 0;

    while (dataStart < 3) {
      List<int> datas = [];
      int byte = bytes.getUint8(byteOffset++);
      while (byte != 0x0A) {
        datas.add(byte);
        byte = bytes.getUint8(byteOffset++);
      }
      if (datas[0] == 0x23) {
        //comments
        comments.add(String.fromCharCodes(datas));
      } else {
        infos.add(String.fromCharCodes(datas));
        dataStart++;
      }
    }

    type = infos[0];
    width = int.parse(infos[1].split(' ').first);
    height = int.parse(infos[1].split(' ').last);
    colorMax = int.parse(infos[2]);

    if (type.toUpperCase() == 'P3') {
      p3TypePixels();
    } else {
      p6TypePixels();
    }
  }

  p3TypePixels() {
    List<PixelRGB> pixels = [];
    while (byteOffset < bytes.lengthInBytes) {
      // print('$byteOffset\n');
      List<int> rgb = [];
      for (int i = 0; i < 3; i++) {
        List<int> datas = [];
        int byte = bytes.getUint8(byteOffset++);
        while (byte == 0x0A || byte == 0x20) {
          byte = bytes.getUint8(byteOffset++);
        }

        while (byte != 0x0A && byte != 0x20) {
          datas.add(byte);
          byte = bytes.getUint8(byteOffset++);
        }
        rgb.add(int.parse(String.fromCharCodes(datas)));
      }
      pixels.add(PixelRGB(rgb[0], rgb[1], rgb[2]));
    }

    /// height等于有多少行，width相当于有多少列
    for (int i = 0; i < height; i++) {
      List<PixelRGB> line = [];
      for (int j = 0; j < width; j++) {
        line.add(pixels[i * width + j]);
      }
      rgbs.add(line);
    }
  }

  p6TypePixels() {
    List<PixelRGB> pixels = [];

    while (byteOffset < bytes.lengthInBytes) {
      print('${bytes.lengthInBytes}     $byteOffset\n');
      List<int> rgb = [];
      for (int i = 0; i < 3; i++) {
        rgb.add(bytes.getUint8(byteOffset++));
      }
      pixels.add(PixelRGB(rgb[0], rgb[1], rgb[2]));
    }

    for (int i = 0; i < height; i++) {
      List<PixelRGB> line = [];
      for (int j = 0; j < width; j++) {
        line.add(pixels[i * width + j]);
      }
      rgbs.add(line);
    }
  }

  colorSpaceConversion() {
    print('开始转换');
    StringBuffer buffer = StringBuffer();

    rgbs.forEach((element) {
      yuvs.add(element.mapIndexed((index, value) {
        buffer.write('$value  ');
        return value.convert2YUV();
      }).toList());
      buffer.writeln();
    });
    print('像素大小:${yuvs.length * yuvs[0].length}');
    // print('RGB值:\n${buffer.toString()}');

    StringBuffer yuvBuffer = StringBuffer();
    yuvs.forEach((element) {
      element.forEach((value) {
        yuvBuffer.write('$value  ');
      });
      yuvBuffer.writeln();
    });
    // print('YUV值:\n${yuvBuffer.toString()}');
  }

  chromaSubSampling() {}

  splitIntoBlocks() {
    int position = 0;
    int rate = 2;

    final MCUPixel = rate * 8;
    int newWidth = (width / MCUPixel).ceil() * MCUPixel;
    int newHeight = (height / MCUPixel).ceil() * MCUPixel;

    for (int line = 0; line < newHeight; line += 8) {
      for (int col = 0; col < newWidth; col += 8) {
        /// 正常是8*8块
        List<List<int>> yPixels = [];

        for (int i = line; i < line + 8; i++) {
          List<int> lineYPixels = [];

          int newI = min(i, height - 1);
          for (int j = col; j < col + 8; j++) {
            int newJ = min(j, width - 1);
            lineYPixels.add(yuvs[newI][newJ].Y);
          }

          yPixels.add(lineYPixels);
        }
        int p = position++;
        yBlocks.add(Block(yPixels, p));
      }
    }

    position = 0;
    for (int line = 0; line < newHeight; line += MCUPixel) {
      for (int col = 0; col < newWidth; col += MCUPixel) {
        /// 正常是8*8块
        List<List<int>> uPixels = [];
        List<List<int>> vPixels = [];

        for (int i = line; i < line + MCUPixel; i++) {
          List<int> lineUPixels = [];
          List<int> lineVPixels = [];

          int newI = min(i, height - 1);
          for (int j = col; j < col + MCUPixel; j++) {
            int newJ = min(j, width - 1);
            lineUPixels.add(yuvs[newI][newJ].Cb);
            lineVPixels.add(yuvs[newI][newJ].Cr);
          }

          uPixels.add(lineUPixels);
          vPixels.add(lineVPixels);
        }
        int p = position++;
        uBlocks.add(Block(uPixels, p)..shrink());
        vBlocks.add(Block(vPixels, p)..shrink());
      }
    }
  }

  discreteCosineTransform() {
    // List<List<int>> test = [
    //   [52, 55, 61, 66, 70, 61, 64, 73],
    //   [63, 59, 55, 90, 109, 85, 69, 72],
    //   [62, 59, 68, 113, 144, 104, 66, 63],
    //   [63, 58, 71, 122, 154, 106, 70, 69],
    //   [67, 61, 68, 104, 126, 88, 68, 70],
    //   [79, 65, 60, 70, 77, 68, 58, 75],
    //   [85, 71, 64, 59, 55, 61, 65, 83],
    //   [87, 79, 69, 68, 65, 76, 78, 94],
    // ];
    // test = yBlocks.first.items;

    double c(int value) {
      return value == 0 ? 1 / sqrt2 : 1;
    }

    int d(int i, int j, List<List<int>> origin) {
      int N = 8;
      double value = 0;
      for (int x = 0; x < N; x++) {
        for (int y = 0; y < N; y++) {
          value += (origin[x][y] - 128) *
              cos((2 * x + 1) * i * pi / (2 * N)) *
              cos((2 * y + 1) * j * pi / (2 * N));
        }
      }
      return (c(i) * c(j) * value / 4).round();
    }

    List<List<int>> dct(List<List<int>> items) {
      return items
          .mapIndexed((i, lineItems) =>
              lineItems.mapIndexed((j, value) => d(i, j, items)).toList())
          .toList();
    }

    for (int i = 0; i < uBlocks.length; i++) {
      List<List<List<int>>> yDCTs = [];
      for (int j = 0; j < 4; j++) {
        yDCTs.add(dct(yBlocks[i * 4 + j].items));
      }
      List<List<int>> uDCTs = dct(uBlocks[i].items);
      List<List<int>> vDCTs = dct(vBlocks[i].items);
      dcts.add(McuDCT(yDCTs, uDCTs, vDCTs));
    }
  }

  List<List<int>> quantization(List<List<int>> items,
      [bool isLuminance = true]) {
    List<List<int>> luminanceQT = [
      [16, 11, 10, 16, 24, 40, 51, 61],
      [12, 12, 14, 19, 26, 58, 60, 55],
      [14, 13, 16, 24, 40, 57, 69, 56],
      [14, 17, 22, 29, 51, 87, 80, 62],
      [18, 22, 37, 56, 68, 109, 103, 77],
      [24, 35, 55, 64, 81, 104, 113, 92],
      [49, 64, 78, 87, 103, 121, 120, 101],
      [72, 92, 95, 98, 112, 100, 103, 99],
    ];

    List<List<int>> chrominanceQT = [
      [17, 18, 24, 47, 99, 99, 99, 99],
      [18, 21, 26, 66, 99, 99, 99, 99],
      [24, 26, 56, 99, 99, 99, 99, 99],
      [47, 66, 99, 99, 99, 99, 99, 99],
      [99, 99, 99, 99, 99, 99, 99, 99],
      [99, 99, 99, 99, 99, 99, 99, 99],
      [99, 99, 99, 99, 99, 99, 99, 99],
      [99, 99, 99, 99, 99, 99, 99, 99],
    ];

    final qt = isLuminance ? luminanceQT : chrominanceQT;

    List<List<int>> result = items
        .mapIndexed((i, _) => items[i]
            .mapIndexed((j, _) => (items[i][j] / qt[i][j]).round())
            .toList())
        .toList();

    return result;
  }

  final zigZag = [
    // [0,0],
    // [0,1],[1,0],
    // [2,0],[1,1],[0,2],
    // [0,3],[1,2],[2,1],[3,0],
    // [4,0],[3,1],[2,2],[1,3],[0,4],
    // [0,5],[1,4],[2,3],[3,2],[4,1],[5,0],
    // [6,0],[5,1],[4,2],[3,3],[2,4],[1,5],[0,6],
    // [0,7],[1,6],[2,5],[3,4],[4,3],[5,2],[6,1],[7,0],
    // [7,1],[6,2],[5,3],[4,4],[3,5],[2,6],[1,7],
    // [2,7],[3,6],[4,5],[5,4],[6,3],[7,2],
    // [7,3],[6,4],[5,5],[4,6],[3,7],
    // [4,7],[5,6],[6,5],[7,4],
    // [7,5],[6,6],[5,7],
    // [6,7],[7,6],
    // [7,7],
    [0, 0],
    [0, 1], [1, 0],
    [2, 0], [1, 1], [0, 2],
    [0, 3], [1, 2], [2, 1], [3, 0],
    [4, 0], [3, 1], [2, 2], [1, 3], [0, 4],
    [0, 5], [1, 4], [2, 3], [3, 2], [4, 1], [5, 0],
    [6, 0], [5, 1], [4, 2], [3, 3], [2, 4], [1, 5], [0, 6],
    [0, 7], [1, 6], [2, 5], [3, 4], [4, 3], [5, 2], [6, 1], [7, 0],
    [7, 1], [6, 2], [5, 3], [4, 4], [3, 5], [2, 6], [1, 7],
    [2, 7], [3, 6], [4, 5], [5, 4], [6, 3], [7, 2],
    [7, 3], [6, 4], [5, 5], [4, 6], [3, 7],
    [4, 7], [5, 6], [6, 5], [7, 4],
    [7, 5], [6, 6], [5, 7],
    [6, 7], [7, 6],
    [7, 7],
  ];

  String zigZagArrangement(List<List<int>> items, bool isLuminance) {
    int oldPreviousDc = previousDC;
    previousDC = items[0][0];
    return runLengthEncoding(items, oldPreviousDc);
  }

  String runLengthEncoding(List<List<int>> items, int previousDC) {
    DCSizeValueCode dc = DCSizeValueCode(items[0][0] - previousDC, true);
    StringBuffer buffer = StringBuffer();
    buffer
      ..write(dc.sizeCode)
      // ..write('--')
      ..write(dc.code);
    // ..writeln();
    int sum = 1;

    int prefixZero = 0;
    for (int index = 1; index < zigZag.length; index++) {
      // print('前置0: $index==>$prefixZero');
      List<int> element = zigZag[index];
      if (sum != (element.first + element.last)) {
        sum = element.first + element.last;
        // buffer.writeln();
      }
      int value = items[element.first][element.last];

      if (value == 0) {
        if (index == 63) {
          buffer.write('$EOB');
          prefixZero = 0;
          break;
        }
        prefixZero++;
      } else {
        //当前数非0
        while (prefixZero >= 16) {
          buffer.write('$ZRL');
          prefixZero -= 16;
        }
        int bit = DCSizeValueCode(value, false).size;

        buffer
              ..write(ACLuminanceTable[prefixZero][bit - 1])
              // ..write('--')
              ..write(DCSizeValueCode(value, false).code)
            // ..write(' ')
            ;
        prefixZero = 0;
      }
    }
    // print('蛇形huffman encoding:\n$buffer');
    return buffer.toString();
  }

  huffmanCoding() {}

  convert2JPEG() {
    StringBuffer jpeg = StringBuffer();

    /// start of image:soi
    jpeg.write('${JPEG_SOI.toRadixString(2).padLeft(8,'0')}');
    /// APP0
  }
}
