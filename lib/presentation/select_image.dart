import 'dart:convert';
import 'dart:developer';
import 'dart:html';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wash_image/infrastructure/file_provider.dart';
import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/image_decoder.dart';
import 'package:wash_image/infrastructure/image_encode/ppm/ppm_encoder.dart';
import 'package:wash_image/presentation/image_info.dart';
import 'package:provider/provider.dart';

class SelectImagePage extends StatefulWidget {
  @override
  _SelectImagePageState createState() => _SelectImagePageState();
}

class _SelectImagePageState extends State<SelectImagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
              onPressed: () async {
                FilePickerResult? result =
                    await FilePicker.platform.pickFiles(type: FileType.any);

                if (result != null) {
                  final bytes = result.files.first.bytes!;

                  // StringBuffer str3 = StringBuffer();

                  // str3.write(ascii
                  //     .decode(bytes.sublist(0, 15), allowInvalid: true)
                  //     .replaceFirst('6', '3'));
                  // print(str3);
                  // int pre = 15;
                  // for (int i = 0; i < bytes.length - pre; i++) {
                  //   str3..write(bytes[i + pre])..write(' ');
                  //   if (i % 3 == 2) {
                  //     str3.writeln();
                  //   }
                  // }

                  // if (kIsWeb) {
                  //   var blob = Blob([str3.toString()], 'text/plain', 'native');

                  //   var anchorElement = AnchorElement(
                  //     href: Url.createObjectUrlFromBlob(blob).toString(),
                  //   )
                  //     ..setAttribute("download", "copy.ppm")
                  //     ..click();
                  // }

                  DecodeResult decodeResult = ImageDecoder.decode(bytes);
                  // PPMEncoder(bytes).encode();
                  context.read<FileProvider>().file(result.files.first.name,
                      result.files.first.size, decodeResult.debugMessage);
                } else {
                  print('图片数据为空');
                }
              },
              child: Container(
                margin: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image,
                      color: Colors.green,
                    ),
                    Text('选择图片'),
                  ],
                ),
              )),
          Text('${context.watch<FileProvider>().filePath}'),
          Expanded(child: ImageInfoPage()),
        ],
      ),
    );
  }
}
