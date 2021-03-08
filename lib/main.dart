import 'package:flutter/material.dart';
import 'package:wash_image/presentation/select_image.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '洗图片',
      theme: ThemeData(
        
        primarySwatch: Colors.blue,
      ),
      home: SelectImagePage(),
    );
  }
}
