List<String> DCCodeFromSize = [
  '00',
  '010',
  '011',
  '100',
  '101',
  '110',
  '1110',
  '11110',
  '111110',
  '1111110',
  '11111110',
  '111111110',
];

class DCSizeValueCode {
  late int size;
  int value;
  late String code;
  late String sizeCode; // from DCCodeFromSize below.
  DCSizeValueCode(this.value) {
    operate(value);
  }

  operate(int value) {
    size = 0;
    code = '';
    if (value == 0) {
      return;
    }
    int absValue = value.abs();
    code = absValue.toRadixString(2);
    if (value < 0) {
      String newCode = '';
      for (int i = 0; i < code.length; i++) {
        newCode += (code[i] == '0' ? '1' : '0');
      }
      code = newCode;
    }
    size = code.length;
    sizeCode = DCCodeFromSize[size];
  }

  @override
  String toString() {
    return "size:$size, value:$value, code:$code, sizeCode:$sizeCode ===> $sizeCode$code";
  }
}

class ACRunSizeCode {}

// 0/0 (EOB) 4 1010
String EOB = '1010';
List<List<String>> ACRunSize = [
  ACRunSize0,
  ACRunSize1,
  ACRunSize2,
  ACRunSize3,
  ACRunSize4,
  ACRunSize5,
  ACRunSize6,
  ACRunSize7,
  ACRunSize8,
  ACRunSize9,
  ACRunSizeA,
  ACRunSizeB,
  ACRunSizeC,
  ACRunSizeD,
  ACRunSizeE,
  ACRunSizeF,
];
List<String> ACRunSize0 = [
// 0/1 2 00
  '00',
// 0/2 2 01
  '01',
// 0/3 3 100
  '100',
// 0/4 4 1011
  '1011',
// 0/5 5 11010
  '11010',
// 0/6 7 1111000
  '1111000',
// 0/7 8 11111000
  '11111000',
// 0/8 0 1111110110
  '1111110110',
// 0/9 6 1111111110000010
  '1111111110000010',
// 0/A 6 1111111110000011
  '1111111110000011',
];

List<String> ACRunSize1 = [
// 1/1 4 1100
  '1100',
// 1/2 5 11011
  '11011',
// 1/3 7 1111001
  '1111001',
// 1/4 9 111110110
  '111110110',
// 1/5 11 11111110110
  '11111110110',
// 1/6 16 1111111110000100
  '1111111110000100',
// 1/7 16 1111111110000101
  '1111111110000101',
// 1/8 16 1111111110000110
  '1111111110000110',
// 1/9 16 1111111110000111
  '1111111110000111',
// 1/A 16 1111111110001000
  '1111111110001000',
];

List<String> ACRunSize2 = [
// 2/1 5 11100
  '11100',
// 2/2 8 11111001
  '11111001',
// 2/3 10 1111110111
  '1111110111',
// 2/4 12 111111110100
  '111111110100',
// 2/5 16 1111111110001001
  '1111111110001001',
// 2/6 16 1111111110001010
  '1111111110001010',
// 2/7 16 1111111110001011
  '1111111110001011',
// 2/8 16 1111111110001100
  '1111111110001100',
// 2/9 16 1111111110001101
  '1111111110001101',
// 2/A 16 1111111110001110
  '1111111110001110',
];

List<String> ACRunSize3 = [
// 3/1 6 111010
  '111010',
// 3/2 9 111110111
  '111110111',
// 3/3 12 111111110101
  '111111110101',
// 3/4 16 1111111110001111
  '1111111110001111',
// 3/5 16 1111111110010000
  '1111111110010000',
// 3/6 16 1111111110010001
  '1111111110010001',
// 3/7 16 1111111110010010
  '1111111110010010',
// 3/8 16 1111111110010011
  '1111111110010011',
// 3/9 16 1111111110010100
  '1111111110010100',
// 3/A 16 1111111110010101
  '1111111110010101',
];

List<String> ACRunSize4 = [
// 4/1 6 111011
  '111011',
// 4/2 10 1111111000
  '1111111000',
// 4/3 16 1111111110010110
  '1111111110010110',
// 4/4 16 1111111110010111
  '1111111110010111',
// 4/5 16 1111111110011000
  '1111111110011000',
// 4/6 16 1111111110011001
  '1111111110011001',
// 4/7 16 1111111110011010
  '1111111110011010',
// 4/8 16 1111111110011011
  '1111111110011011',
// 4/9 16 1111111110011100
  '1111111110011100',
// 4/A 16 1111111110011101
  '1111111110011101',
];

List<String> ACRunSize5 = [
// 5/1 7 1111010
  '1111010',
// 5/2 11 11111110111
  '11111110111',
// 5/3 16 1111111110011110
  '1111111110011110',
// 5/4 16 1111111110011111
  '1111111110011111',
// 5/5 16 1111111110100000
  '1111111110100000',
// 5/6 16 1111111110100001
  '1111111110100001',
// 5/7 16 1111111110100010
  '1111111110100010',
// 5/8 16 1111111110100011
  '1111111110100011',
// 5/9 16 1111111110100100
  '1111111110100100',
// 5/A 16 1111111110100101
  '1111111110100101',
];

List<String> ACRunSize6 = [
// 6/1 7 1111011
  '1111011',
// 6/2 12 111111110110
  '111111110110',
// 6/3 16 1111111110100110
  '1111111110100110',
// 6/4 16 1111111110100111
  '1111111110100111',
// 6/5 16 1111111110101000
  '1111111110101000',
// 6/6 16 1111111110101001
  '1111111110101001',
// 6/7 16 1111111110101010
  '1111111110101010',
// 6/8 16 1111111110101011
  '1111111110101011',
// 6/9 16 1111111110101100
  '1111111110101100',
// 6/A 16 1111111110101101
  '1111111110101101',
];

List<String> ACRunSize7 = [
// 7/1 8 11111010
  '11111010',
// 7/2 12 111111110111
  '111111110111',
// 7/3 16 1111111110101110
  '1111111110101110',
// 7/4 16 1111111110101111
  '1111111110101111',
// 7/5 16 1111111110110000
  '1111111110110000',
// 7/6 16 1111111110110001
  '1111111110110001',
// 7/7 16 1111111110110010
  '1111111110110010',
// 7/8 16 1111111110110011
  '1111111110110011',
// 7/9 16 1111111110110100
  '1111111110110100',
// 7/A 16 1111111110110101
  '1111111110110101',
];

List<String> ACRunSize8 = [
// 8/1 9 111111000
  '111111000',
// 8/2 15 111111111000000
  '111111111000000',
// 8/3 16 1111111110110110
  '1111111110110110',
// 8/4 16 1111111110110111
  '1111111110110111',
// 8/5 16 1111111110111000
  '1111111110111000',
// 8/6 16 1111111110111001
  '1111111110111001',
// 8/7 16 1111111110111010
  '1111111110111010',
// 8/8 16 1111111110111011
  '1111111110111011',
// 8/9 16 1111111110111100
  '1111111110111100',
// 8/A 16 1111111110111101
  '1111111110111101',
];

List<String> ACRunSize9 = [
// 9/1 9 111111001
  '111111001',
// 9/2 16 1111111110111110
  '1111111110111110',
// 9/3 16 1111111110111111
  '1111111110111111',
// 9/4 16 1111111111000000
  '1111111111000000',
// 9/5 16 1111111111000001
  '1111111111000001',
// 9/6 16 1111111111000010
  '1111111111000010',
// 9/7 16 1111111111000011
  '1111111111000011',
// 9/8 16 1111111111000100
  '1111111111000100',
// 9/9 16 1111111111000101
  '1111111111000101',
// 9/A 16 1111111111000110
  '1111111111000110',
];

List<String> ACRunSizeA = [
// A/1 9 111111010
  '111111010',
// A/2 16 1111111111000111
  '1111111111000111',
// A/3 16 1111111111001000
  '1111111111001000',
// A/4 16 1111111111001001
  '1111111111001001',
// A/5 16 1111111111001010
  '1111111111001010',
// A/6 16 1111111111001011
  '1111111111001011',
// A/7 16 1111111111001100
  '1111111111001100',
// A/8 16 1111111111001101
  '1111111111001101',
// A/9 16 1111111111001110
  '1111111111001110',
// A/A 16 1111111111001111
  '1111111111001111',
];

List<String> ACRunSizeB = [
// B/1 10 1111111001
  '1111111001',
// B/2 16 1111111111010000
  '1111111111010000',
// B/3 16 1111111111010001
  '1111111111010001',
// B/4 16 1111111111010010
  '1111111111010010',
// B/5 16 1111111111010011
  '1111111111010011',
// B/6 16 1111111111010100
  '1111111111010100',
// B/7 16 1111111111010101
  '1111111111010101',
// B/8 16 1111111111010110
  '1111111111010110',
// B/9 16 1111111111010111
  '1111111111010111',
// B/A 16 1111111111011000
  '1111111111011000',
];

List<String> ACRunSizeC = [
// C/1 10 1111111010
  '1111111010',
// C/2 16 1111111111011001
  '1111111111011001',
// C/3 16 1111111111011010
  '1111111111011010',
// C/4 16 1111111111011011
  '1111111111011011',
// C/5 16 1111111111011100
  '1111111111011100',
// C/6 16 1111111111011101
  '1111111111011101',
// C/7 16 1111111111011110
  '1111111111011110',
// C/8 16 1111111111011111
  '1111111111011111',
// C/9 16 1111111111100000
  '1111111111100000',
// C/A 16 1111111111100001
  '1111111111100001',
];

List<String> ACRunSizeD = [
// D/1 11 11111111000
  '11111111000',
// D/2 16 1111111111100010
  '1111111111100010',
// D/3 16 1111111111100011
  '1111111111100011',
// D/4 16 1111111111100100
  '1111111111100100',
// D/5 16 1111111111100101
  '1111111111100101',
// D/6 16 1111111111100110
  '1111111111100110',
// D/7 16 1111111111100111
  '1111111111100111',
// D/8 16 1111111111101000
  '1111111111101000',
// D/9 16 1111111111101001
  '1111111111101001',
// D/A 16 1111111111101010
  '1111111111101010',
];

List<String> ACRunSizeE = [
// E/1 16 1111111111101011
  '1111111111101011',
// E/2 16 1111111111101100
  '1111111111101100',
// E/3 16 1111111111101101
  '1111111111101101',
// E/4 16 1111111111101110
  '1111111111101110',
// E/5 16 1111111111101111
  '1111111111101111',
// E/6 16 1111111111110000
  '1111111111110000',
// E/7 16 1111111111110001
  '1111111111110001',
// E/8 16 1111111111110010
  '1111111111110010',
// E/9 16 1111111111110011
  '1111111111110011',
// E/A 16 1111111111110100
  '1111111111110100',
];

List<String> ACRunSizeF = [
// F/1 15 111111111000011
  '111111111000011',
// F/2 16 1111111111110110
  '1111111111110110',
// F/3 16 1111111111110111
  '1111111111110111',
// F/4 16 1111111111111000
  '1111111111111000',
// F/5 16 1111111111111001
  '1111111111111001',
// F/6 16 1111111111111010
  '1111111111111010',
// F/7 16 1111111111111011
  '1111111111111011',
// F/8 16 1111111111111100
  '1111111111111100',
// F/9 16 1111111111111101
  '1111111111111101',
// F/A 16 1111111111111110
  '1111111111111110',
];

// F/0 (ZRL) 10 1111111010
String ZRL = '1111111010';