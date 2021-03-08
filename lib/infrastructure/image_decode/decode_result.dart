import 'package:wash_image/infrastructure/image_decode/image_file.dart';

class DecodeResult {
  final bool success;
  final ImageFile? imageFile;
  final String? debugMessage;

  DecodeResult({required this.success, this.imageFile, this.debugMessage});
  factory DecodeResult.fail({String? debugMessage}) => DecodeResult(success: false,debugMessage: debugMessage);
}
