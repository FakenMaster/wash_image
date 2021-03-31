import 'dart:typed_data';

import 'package:wash_image/infrastructure/image_encode/pixel.dart';

class PPMEncoder {
  late ByteData bytes;
  List<String> infos = [];
  List<String> comments = [];
  late String type;
  late int width;
  late int height;
  late int colorMax;
  late int byteOffset;

  List<PixelRGB> rgbs = [];
  List<PixelYUV> yuvs = [];

  PPMEncoder(Uint8List? data) {
    bytes = data!.buffer.asByteData();
  }

  encode() {
    readFile();
    colorSpaceConversion();
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

    if (type == 'p3') {
      p3TypePixels();
    } else {
      p6TypePixels();
    }
  }

  p3TypePixels() {
    while (byteOffset < bytes.lengthInBytes) {
      // print('$byteOffset\n');
      List<int> rgb = [];
      List<int> datas = [];
      for (int i = 0; i < 3; i++) {
        int byte = bytes.getUint8(byteOffset++);

        while (byte != 0x0A) {
          datas.add(byte);
          byte = bytes.getUint8(byteOffset++);
        }
        rgb.add(int.parse(String.fromCharCodes(datas)));
        datas.clear();
      }
      rgbs.add(PixelRGB(rgb[0], rgb[1], rgb[2]));
      rgb.clear();
    }
  }

  p6TypePixels() {
    while (byteOffset < bytes.lengthInBytes) {
      print('${bytes.lengthInBytes}     $byteOffset\n');
      List<int> rgb = [];
      for (int i = 0; i < 3; i++) {
        rgb.add(bytes.getUint8(byteOffset++));
      }
      rgbs.add(PixelRGB(rgb[0], rgb[1], rgb[2]));
    }
  }

  colorSpaceConversion() {
    print('开始转换');
    rgbs.forEach((element) {
      yuvs.add(element.convert2YUV());
    });
    print('像素大小:${yuvs.length}');
  }

  chromaSubSampling() {}

  discreteCosineTransform() {}

  quantization() {}

  zigZagArrangement() {}

  runLengthEncoding() {}

  huffmanCoding() {}
}
