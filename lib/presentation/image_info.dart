import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wash_image/infrastructure/file_provider.dart';
class ImageInfoPage extends StatefulWidget {
  @override
  _ImageInfoPageState createState() => _ImageInfoPageState();
}

class _ImageInfoPageState extends State<ImageInfoPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text('图片信息:\n${context.watch<FileProvider>().debugMessage}',
          style: TextStyle(
            fontSize: 30,
          ),),
        ],
      ),
    );
  }
}
