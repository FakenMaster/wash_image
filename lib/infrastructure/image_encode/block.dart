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
    int step = blockSize ~/ shrinkTimes;
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
    for (int i = 0; i < newItems.length; i += shrinkTimes) {
      items.add(newItems.sublist(i, i + shrinkTimes));
    }
    blockSize = step * step;
  }
}
