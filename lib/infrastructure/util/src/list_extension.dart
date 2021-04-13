import './int_extension.dart';

extension ListIntX on List<int> {
  String get binaryString =>
      map((e) => e.binaryString).reduce((value, element) => value + element);
}
