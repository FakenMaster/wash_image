import 'dart:collection';
import 'package:dartx/dartx.dart';

class HaffmanEncoder {
  static String encode(String input) {
    Map<String, int> map = Map<String, int>();
    input.runes.forEach((element) {
      var char = String.fromCharCode(element);
      map[char] = (map[char] ?? 0) + 1;
    });
    StringBuffer buffer = StringBuffer();

    int compare(HaffmanNode a, HaffmanNode other) {
      if (a.weight == other.weight) {
        return a.name == null || other.name == null
            ? -1
            : a.name!.compareTo(other.name!);
      }
      return a.weight > other.weight ? 1 : -1;
    }

    List<HaffmanNode> nodes = List.from(SplayTreeSet<HaffmanNode>.from(
        map.entries
            .map((entry) => HaffmanNode(name: entry.key, weight: entry.value))
            .toList(),
        compare));

    while (nodes.length > 1) {
      HaffmanNode left = nodes.first;
      HaffmanNode right = nodes.second!;
      HaffmanNode newNode = HaffmanNode.createParent(left: left, right: right);
      nodes
        ..removeRange(0, 2)
        ..add(newNode)
        ..sort(compare);
    }

    SplayTreeSet<HaffmanNode> result =
        SplayTreeSet((a, b) => a.name!.compareTo(b.name!));
    nodes.first.code = '';
    while (nodes.isNotEmpty) {
      HaffmanNode first = nodes.first;
      nodes.removeAt(0);
      if (first.name != null) {
        result.add(first);
      } else {
        HaffmanNode left = first.left!;
        HaffmanNode right = first.right!;
        left.code = '${first.code}0';
        right.code = '${first.code}1';
        nodes.addAll([left, right]);
      }
    }

    buffer.writeln('\n');
    result.forEach((element) {
      buffer.writeln('${element.name}:${element.weight}==>${element.code}');
    });

    return buffer.toString();
  }
}

class HaffmanNode {
  HaffmanNode({
    this.name,
    required this.weight,
    this.left,
    this.right,
  });

  HaffmanNode.createParent({
    this.left,
    this.right,
  }) : weight = left!.weight + right!.weight;

  String? name;
  int weight;
  late String code;
  HaffmanNode? left;
  HaffmanNode? right;

}
