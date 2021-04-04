class Block {
  ///行列值相同
  late int blockSize;
  int position;
  late int stepss;
  List<List<int>> items;
  Block(this.items, this.position) {
    blockSize = items.length;
  }

  //取样
  shrink([int shrinkTimes = 4]) {
    int step = 2; //blockSize ~/ shrinkTimes;
    List<int> newItems = [];
    for (int line = 0; line < blockSize; line += step) {
      for (int col = 0; col < blockSize; col += step) {
        List<int> fullItems = [];
        for (int i = line; i < line + step; i++) {
          for (int j = col; j < col + step; j++) {
            fullItems.add(items[i][j]);
          }
        }

        newItems.add(fullItems.reduce((value, element) => value + element) ~/
            fullItems.length);
      }
    }

    items.clear();
    for (int i = 0; i < newItems.length; i += 8) {
      items.add(newItems.sublist(i, i + 8));
    }
    blockSize = (blockSize / 2).round();
  }
}
