import 'dart:collection';

class HaffmanEncoder {
  static String encode(String input) {
    SplayTreeMap<String, int> mapSortedByKey = SplayTreeMap<String, int>();
    input.runes.forEach((element) {
      var char = String.fromCharCode(element);
      mapSortedByKey[char] = (mapSortedByKey[char] ?? 0) + 1;
    });
    StringBuffer buffer = StringBuffer();
    SplayTreeMap<String, int> mapSortedByValue = SplayTreeMap.from(
        mapSortedByKey,
        (a, b) => mapSortedByKey[a]! > mapSortedByKey[b]! ? 1 : -1);
    mapSortedByValue.forEach((key, value) {
      buffer.writeln('$key:$value');
    });

    Map<int, List<String>> map = {};
    mapSortedByValue.forEach((key, value) {
      (map[value] ??= []).add(key);
    });
    map.forEach((key, value) {
      buffer.writeln('值:$key:${value.toString()}');
    });
    return buffer.toString();
  }
}

class HaffmanNode {
  HaffmanNode({
    this.name,
    required this.weight,
  });
  String? name;
  int weight;
  HaffmanNode? left;
  HaffmanNode? right;
}
