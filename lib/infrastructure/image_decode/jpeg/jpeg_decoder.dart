import 'dart:typed_data';

import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_data.dart';

import '../decode_result.dart';

class JPEGDecoder {
  static DecodeResult decode(Uint8List? dataBytes) {
    if (dataBytes == null || dataBytes.isEmpty) {
      return DecodeResult.fail();
    }

    return JpegData().read(dataBytes);
  }
}
