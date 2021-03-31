import 'dart:typed_data';

// class PPMEncoder {
//   late ByteData bytes;
//   List<List<int>> infos = [];
//   List<List<int>> comments = [];

//   PPMEncoder(Uint8List? data) {
//     bytes = data!.buffer.asByteData();
//   }

//   readFile() {
//     int dataStart = 0;
//     int byteOffset = 0;
//     while (dataStart < 4) {
//       List<int> datas = [];
//       int byte = bytes.getUint8(byteOffset++);
//       while (byte != 0x0A) {
//         datas.add(byte);
//       }
//       if (datas[0] == 0x23) {
//         //comments
//         comments.add(datas);
//         print('数据：${datas[0]} --- ${datas[0].toString()}');
//       } else {
//         infos.add(datas);
//         dataStart++;
//       }
//     }
//   }

//   colorSpaceConversion() {}

//   chromaSubSampling() {}

//   discreteCosineTransform() {}

//   quantization() {}

//   zigZagArrangement() {}

//   runLengthEncoding() {}

//   huffmanCoding() {}
// }
