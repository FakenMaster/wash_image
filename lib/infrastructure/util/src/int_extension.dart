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

  String get binaryString {
    return this.toRadixString(2).padLeft(8, '0');
  }

  /// 无符号1个字节范围：0..255
  int get clampUnsignedByte {
    return this.clamp(0, 255);
  }

  /// start and end are all inclusive.
  bool between(int start, int end) {
    return this >= start && this <= end;
  }
}
