import 'dart:math';
import 'dart:typed_data';

import 'package:wash_image/infrastructure/image_encode/block.dart';
import 'package:wash_image/infrastructure/image_encode/component.dart';
import 'package:wash_image/infrastructure/image_encode/pixel.dart';
import 'package:stringx/stringx.dart';

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

  PPMEncoder(Uint8List? data) {
    bytes = data!.buffer.asByteData();
  }

  encode() {
    readFile();
    colorSpaceConversion();
    splitIntoBlocks();
    discreteCosineTransform();
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
      yuvs.add(element.mapWithIndex((index, value) {
        buffer.write('$value  ');
        return value.convert2YUV();
      }).toList());
      buffer.writeln();
    });
    print('像素大小:${yuvs.length * yuvs[0].length}');
    print('RGB值:\n${buffer.toString()}');

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
    for (int line = 0; line < height; line += 8) {
      for (int col = 0; col < width; col += 8) {
        /// 正常是8*8块
        List<List<int>> yPixels = [];
        List<List<int>> uPixels = [];
        List<List<int>> vPixels = [];

        for (int i = line; i < line + 8; i++) {
          List<int> lineYPixels = [];
          List<int> lineUPixels = [];
          List<int> lineVPixels = [];

          int newI = min(i, height - 1);
          for (int j = col; j < col + 8; j++) {
            int newJ = min(j, width - 1);
            lineYPixels.add(yuvs[newI][newJ].Y);
            lineUPixels.add(yuvs[newI][newJ].Cb);
            lineVPixels.add(yuvs[newI][newJ].Cr);
          }

          yPixels.add(lineYPixels);
          uPixels.add(lineUPixels);
          vPixels.add(lineVPixels);
        }
        int p = position++;
        yBlocks.add(Block(yPixels, p));
        uBlocks.add(Block(uPixels, p)..shrink());
        vBlocks.add(Block(vPixels, p)..shrink());
      }
    }
  }

  discreteCosineTransform() {
    List<List<int>> test = [
      [52, 55, 61, 66, 70, 61, 64, 73],
      [63, 59, 55, 90, 109, 85, 69, 72],
      [62, 59, 68, 113, 144, 104, 66, 63],
      [63, 58, 71, 122, 154, 106, 70, 69],
      [67, 61, 68, 104, 126, 88, 68, 70],
      [79, 65, 60, 70, 77, 68, 58, 75],
      [85, 71, 64, 59, 55, 61, 65, 83],
      [87, 79, 69, 68, 65, 76, 78, 94],
    ];
    // test = yBlocks.first.items;

    StringBuffer buffer = StringBuffer();
    StringBuffer buffer2 = StringBuffer();
    StringBuffer buffer3 = StringBuffer();

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

    List<List<int>> result = [];
    // yBlocks.mapWithIndex((blockIndex, block) {
    test.mapWithIndex((i, element) {
      List<int> what = [];
      element.mapWithIndex((j, value) {
        buffer.write('$value  ');
        buffer2.write('${value - 128}  ');
        what.add(d(i, j, test));
        buffer3.write('${d(i, j, test)} ');
      }).toList();
      buffer.writeln();
      buffer2.writeln();
      buffer3.writeln();
      result.add(what);
    }).toList();
    // }).toList();

    print('Y:\n${buffer.toString()}');
    print('Y处理之后:\n${buffer2.toString()}');
    print('DCT:\n${buffer3.toString()}');

    /// 量化
    quantization(result);
  }

  quantization(List<List<int>> items) {
    List<List<int>> quantizationTable = [
      [16, 11, 10, 16, 24, 40, 51, 61],
      [12, 12, 14, 19, 26, 58, 60, 55],
      [14, 13, 16, 24, 40, 57, 69, 56],
      [14, 17, 22, 29, 51, 87, 80, 62],
      [18, 22, 37, 56, 68, 109, 103, 77],
      [24, 35, 55, 64, 81, 104, 113, 92],
      [49, 64, 78, 87, 103, 121, 120, 101],
      [72, 92, 95, 98, 112, 100, 103, 99],
    ];

    List<List<int>> result = [];

    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      List<int> data = [];
      for (int j = 0; j < 8; j++) {
        data.add((items[i][j] / quantizationTable[i][j]).round());
        buffer.write('${data[j]} ');
      }
      buffer.writeln();
      result.add(data);
    }
    print('量化:\n${buffer.toString()}');

    /// 蛇形
    zigZagArrangement(result);
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

  zigZagArrangement(List<List<int>> items) {
    int getPosFromIndex(int i, int j) {
      for (int i = 0; i < zigZag.length; i++) {
        if (zigZag[i].first == i && zigZag[i].last == j) {
          return i;
        }
      }
      return -1;
    }

    List<int> getIndexFromPos(int pos) {
      return zigZag[pos];
    }

    StringBuffer buffer = StringBuffer();
    int sum = 0;

    zigZag.forEach((element) {
      if (sum != (element.first + element.last)) {
        sum = element.first + element.last;
        buffer.writeln();
      }
      buffer.write('${items[element.first][element.last]} ');
    });
    print('蛇形:\n$buffer');

    // print('${DCSizeValueCode(-8)}');

    runLengthEncoding(items, 0);
  }

  runLengthEncoding(List<List<int>> items, int previous) {
    DCSizeValueCode dc = DCSizeValueCode(items[0][0] - previous);
    StringBuffer buffer = StringBuffer();
    buffer
      ..write(dc.sizeCode)
      ..write('--')
      ..write(dc.code)
      ..writeln();
    int sum = 1;

    int prefixZero = 0;
    for (int index = 1; index < zigZag.length; index++) {
      List<int> element = zigZag[index];
      if (sum != (element.first + element.last)) {
        sum = element.first + element.last;
        buffer.writeln();
      }
      int value = items[element.first][element.last];
      if (index == 63 && prefixZero != 0) {
        buffer.write('$EOB ');
        break;
      }
      if (prefixZero < 15 && value == 0) {
        prefixZero++;
      } else {
        if (prefixZero == 15 && value == 0) {
          prefixZero = 0;
          buffer.write('$ZRL ');
          continue;
        }

        int bit = DCSizeValueCode(value).size;

        buffer
          ..write(ACRunSize[prefixZero][bit+1])
          ..write('--')
          ..write(DCSizeValueCode(value).code)
          ..write(' ');
      }
    }
    print('蛇形huffman encoding:\n$buffer');
  }

  huffmanCoding() {}
}
