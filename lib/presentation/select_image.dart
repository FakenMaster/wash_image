import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:wash_image/infrastructure/file_provider.dart';
import 'package:wash_image/infrastructure/image_decode/decode_result.dart';
import 'package:wash_image/infrastructure/image_decode/image_decoder.dart';
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
                    await FilePicker.platform.pickFiles(type: FileType.image);

                if (result != null) {
                  inspect(result);
                  final bytes = result.files.first.bytes;
                  DecodeResult decodeResult = ImageDecoder.decode(bytes);
                  context.read<FileProvider>().file(result.files.first.path,
                      result.files.first.bytes?.length,decodeResult.debugMessage);

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
          ImageInfoPage(),
        ],
      ),
    );
  }
}
