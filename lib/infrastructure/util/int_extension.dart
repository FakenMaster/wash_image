extension IntX on int {
  String toRadix(
      {bool padLeft = true,
      int padNum = 4,
      bool upper = true,
      bool prefix = true,
      String prefixStr = '0x'}) {
    String radixString = this.toRadixString(16);
    if (padLeft) {
      radixString = radixString.padLeft(padNum, '0');
    }
    if (upper) {
      radixString = radixString.toUpperCase();
    }
    return '${prefix ? prefixStr : ''}$radixString';
  }
}
