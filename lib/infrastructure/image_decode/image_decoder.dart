import 'dart:typed_data';

import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/jpeg/jpeg_decoder.dart';

class ImageDecoder {
  static DecodeResult decode(Uint8List? dataBytes) {
    return JPEGDecoder.decode(dataBytes);
  }
}
