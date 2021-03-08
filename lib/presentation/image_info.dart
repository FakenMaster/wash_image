import 'package:flutter/material.dart';

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
          Text('图片大小:'),
        ],
      ),
    );
  }
}
