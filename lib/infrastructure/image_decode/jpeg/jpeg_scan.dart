import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg.dart';
import 'package:wash_image/infrastructure/model/src/jpeg_component.dart';
import 'package:wash_image/infrastructure/util/input_buffer.dart';

import '../../image_exception.dart';
import 'jpeg_frame.dart';

class JpegScan {
  InputBuffer input;
  JpegFrame frame;
  int? precision;
  int? samplesPerLine;
  int? scanLines;
  late int mcusPerLine;
  bool? progressive;
  int? maxH;
  int? maxV;
  List<JpegComponent> components;
  int? resetInterval;
  int spectralStart;
  int spectralEnd;
  int successivePrev;
  int successive;

  int bitsData = 0;
  int bitsCount = 0;
  int eobrun = 0;
  int successiveACState = 0;
  late int successiveACNextValue;

  JpegScan(
    this.input,
    this.frame,
    this.components,
    this.resetInterval,
    this.spectralStart,
    this.spectralEnd,
    this.successivePrev,
    this.successive,
  ) {
    precision = frame.precision;
    samplesPerLine = frame.samplesPerLine;
    scanLines = frame.scanLines;
    mcusPerLine = frame.mcusPerLine;
    progressive = frame.progressive;
    maxH = frame.maxHSamples;
    maxV = frame.maxVSamples;
  }

  void decode() {
    final componentsLength = components.length;
    JpegComponent? component;
    void Function(JpegComponent, List<int>) decodeFn;

    if (progressive!) {
      if (spectralStart == 0) {
        decodeFn = successivePrev == 0 ? _decodeDCFirst : _decodeDCSuccessive;
      } else {
        decodeFn = successivePrev == 0 ? _decodeACFirst : _decodeACSuccessive;
      }
    } else {
      decodeFn = _decodeBaseline;
    }
  }

  /// zz表示这个block的64位值
  void _decodeBaseline(JpegComponent component, List zz) {
    final t = _decodeHuffman(component.huffmanTableDC);
    final diff = t == 0 ? 0 : _receiveAndExtend(t);
    component.pred += diff;
    zz[0] = component.pred;

    var k = 1;
    while (k < 64) {
      final rs = _decodeHuffman(component.huffmanTableAC)!;
      var s = rs & 15;
      final r = rs >> 4;
      if (s == 0) {
        if (r < 15) {
          /// 如果后面还有非0值得话，这个就不会存在了，所以后面的全为0，所以和0/0一个意思，后续全为0
          break;
        }
        k += 16;
        continue;
      }

      k += r;

      s = _receiveAndExtend(s);

      final z = Jpeg.dctZigZag[k];
      zz[z] = s;
      k++;
    }
  }

  void _decodeDCFirst(JpegComponent component, List zz) {
    final t = _decodeHuffman(component.huffmanTableDC);

    /// 移位原来是最后一步吗？那这样和不移位的区别在哪里？是数变小了，所以压缩程度更高？
    /// 是的，标准文件这么说的
    final diff = (t == 0) ? 0 : (_receiveAndExtend(t) << successive);
    component.pred += diff;
    zz[0] = component.pred;
  }

  /// 后续都是一位一位操作的，而且不QT/不DCT
  void _decodeDCSuccessive(JpegComponent component, List<int> zz) {
    zz[0] = (zz[0] | (_readBit()! << successive));
  }

  void _decodeACFirst(JpegComponent component, List zz) {
    if (eobrun > 0) {
      eobrun--;
      return;
    }

    var k = spectralStart;
    final e = spectralEnd;
    while (k <= e) {
      final rs = _decodeHuffman(component.huffmanTableAC)!;
      final s = rs & 15;
      final r = rs >> 4;
      if (s == 0) {
        // 这是Progressive的规定，当 s==0时，
        // 如果r<15,则后续的r个位的值为count，
        // 表示了当前block剩下的值，以及后续的 count + (1<<r) - 1 个block的相关位置的值
        // 都为0
        if (r < 15) {
          eobrun = (_receive(r)! + (1 << r) - 1);
          break;
        }

        /// 如果r为15，则包括当前位置k以及接下来的15个值都为0
        k += 16;
        continue;
      }

      k += r;
      final z = Jpeg.dctZigZag[k];

      /// 为什么AC用乘法不用移位呢？DC是用移位的
      zz[z] = (_receiveAndExtend(s) * (1 << successive));
      k++;
    }
  }

  void _decodeACSuccessive(JpegComponent component, List<int> zz) {
    var k = spectralStart;
    final e = spectralEnd;
    var s = 0;
    var r = 0;
    while (k <= e) {
      final z = Jpeg.dctZigZag[k];
      switch(successiveACState){

      }
    }
  }

  int _receiveAndExtend(int? length) {
    if (length == 1) {
      return _readBit() == 1 ? 1 : -1;
    }

    final n = _receive(length!)!;

    /// 比如length=3，n为101，即5,而1<<2等于4，所以原为正数5
    if (n >= (1 << (length - 1))) {
      return n;
    }

    /// n官方表示为010,面值为2,小于1<<2的4，所以原为负数,2+(-8)+1 = 5
    return n + (-1 << length) + 1;
  }

  int? _receive(int length) {
    var n = 0;
    while (length > 0) {
      final bit = _readBit();
      if (bit == null) {
        return null;
      }
      n = ((n << 1) | bit);
      length--;
    }
    return n;
  }

  int? _decodeHuffman(List tree) {
    dynamic node = tree;
    int? bit;
    while ((bit = _readBit()) != null) {
      node = (node as List)[bit!];
      if (node is num) {
        return node.toInt();
      }
    }
    return null;
  }

  int? _readBit() {
    if (bitsCount > 0) {
      bitsCount--;
      return (bitsData >> bitsCount) & 1;
    }

    if (input.isEOS) {
      return null;
    }

    bitsData = input.readByte();
    if (bitsData == 0xff) {
      final nextByte = input.readByte();
      if (nextByte != 0) {
        throw ImageException(
            'unexpected marker: ${((bitsData << 8) | nextByte).toRadixString(16)}');
      }
    }
    bitsCount = 7;
    return (bitsData >> 7) & 1;
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
      if (imageInfo.progressive) {
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

    print('总共字节数:${scanDatas.map((e) => e.length).sum}');
    if (!imageInfo.progressive) {
      readMCUs();
    }

    /// 反量化 => 反ZigZag =>  反离散余弦转换
    imageInfo.mcus.forEach((e) => e
        .inverseQT(
            imageInfo.yQuantizationTable.block,
            imageInfo.cbQuantizationTable.block,
            imageInfo.crQuantizationTable.block)
        .zigZag()
        .inverseDCT());

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
}
