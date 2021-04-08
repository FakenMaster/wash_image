class HaffmanTable {
  /// 0 = DC table, 1 = AC table
  int type;

  /// number of HT (0..3, otherwise error)
  int id;

  late List<int> category;
  late List<String> codeWord;

  HaffmanTable({
    required this.type,
    required this.id,
    List<int> category = const [],
    List<String> codeWord = const [],
  })  : this.category = category,
        this.codeWord = codeWord;

  
}
