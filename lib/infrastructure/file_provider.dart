import 'package:flutter/material.dart';

class FileProvider extends ChangeNotifier {
  int? _length;
  String? _filePath;
  String? _debugMessage;

  String? get debugMessage => _debugMessage;
  String? get filePath => _filePath;
  int? get length => _length;

  void file(
    String? path,
    int? length,
    String? debugMessage,
  ) {
    _filePath = path;
    _length = length;
    _debugMessage = debugMessage;
    notifyListeners();
  }
}
