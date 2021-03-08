import 'dart:typed_data';

import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_jfif.dart';
import '../../util/int_extension.dart';

///
class JPEGDecoder {
  static DecodeResult decode(Uint8List? dataBytes) {
    if (dataBytes == null || dataBytes.isEmpty) {
      return DecodeResult.fail();
    }

    return _JPEGDecoderInternal(dataBytes.buffer.asByteData()).decode();
  }
}

class _JPEGDecoderInternal {
  final ByteData bytes;
  int offset = 0;
  DecodeResult? result;
  StringBuffer debugMessage;

  _JPEGDecoderInternal(this.bytes) : debugMessage = StringBuffer();

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

    return result ?? DecodeResult.fail();
  }

  /// check start of image
  bool checkSOI() {
    int soi = bytes.getUint16(offset);
    debugMessage..writeln('结果soi: ${soi.toRadix()}')..writeln();
    offset += 2;
    return soi == JPEG_SOI;
  }

  /// check segment
  bool checkSegment() {
    int segment = bytes.getUint16(offset);
    offset += 2;
    
    if (segment == JPEG_SOS) {
      /// start of scan, 获取到sos的compressed_data
      if (!getSOS()) {
        return false;
      }
    } else if (segment == JPEG_EOI) {
      /// end of image，文件解析结束，之后的字节可以用于放无关信息
      getEOI();
      return true;
    } else if (segment == JPEG_APP0) {
      /// APP0
      return getAPP0();
    } else {
      /// 其他marker
      return false;
    }

    return checkSegment();
  }

  bool getAPP0() {
    // int app0 = bytes.getUint16(offset);
    // debugMessage..writeln('结果app0: ${app0.toRadix()}')..writeln();
    // offset += 2;

    // if (app0 != JPEG_APP0) {
    //   return false;
    // }

    int remain = bytes.getUint16(offset) - 2;
    debugMessage..writeln('app0剩下字节数:$remain')..writeln();
    offset += 2;

    int identifier = bytes.getUint32(offset);
    int suffix = bytes.getUint8(offset + 4);
    offset += 5;
    remain -= 5;
    debugMessage..writeln('identifier: ${identifier.toRadix()}')..writeln();

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
    int version0 = bytes.getUint8(offset);
    int version1 = bytes.getUint8(offset + 1);
    offset += 2;
    remain -= 2;
    debugMessage
      ..writeln(
          'jfif版本:$version0.${version1.toRadix(padNum: 2, prefix: false)}')
      ..writeln();

    /// Units for the following pixel density fields
    Map<int, String> densityMessage = {
      00: ' No units; width:height pixel aspect ratio = Ydensity:Xdensity',
      01: 'Pixels per inch (2.54 cm)',
      02: 'Pixels per centimeter',
    };

    ///
    int density = bytes.getUint8(offset);
    offset += 1;
    remain -= 1;
    debugMessage
      ..writeln(
          'density:${density.toRadix(padNum: 2, prefix: false)}:${densityMessage[density]}');

    int xDensity = bytes.getUint16(offset);
    int yDensity = bytes.getUint16(offset + 2);
    offset += 4;
    remain -= 4;
    debugMessage..writeln('$xDensity * $yDensity')..writeln();

    int xThumbnail = bytes.getUint8(offset);
    int yThumbnail = bytes.getUint8(offset + 1);
    offset += 2;
    remain -= 2;
    debugMessage..writeln('thumbnail:$xThumbnail * $yThumbnail');

    /// thumbnail data :3*n 24bit RGB;with n = xThumbnail * yThumbnail
    offset += xThumbnail * yThumbnail;
    remain -= xThumbnail * yThumbnail;

    if (remain != 0) {
      return false;
    }
    debugMessage..writeln('JFIF解析成功')..writeln();
    return true;
  }

  /// check jfif extension (jfxx) app0 marker segment
  bool checkJFXXAPP0(int remain) {
    return false;
  }

  /// check start of scan
  bool getSOS() {
    // int sos = bytes.getUint16(offset);
    // offset += 2;
    debugMessage.writeln('sos');

    /// TODO: 解析压缩数据,这里返回false，待实现
    return true;
  }

  /// check end of image
  bool getEOI() {
    debugMessage.writeln('文件解析结束，剩下的内容作为无关信息');
    return true;
  }
}
