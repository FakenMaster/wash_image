import 'package:image/image.dart';

class InputBuffer {
  List<int> buffer;
  final int start;
  final int end;
  int offset;
  bool bigEndian;
  InputBuffer(this.buffer,
      {this.bigEndian = true, this.offset = 0, int? length})
      : start = offset,
        end = (length == null) ? buffer.length : offset + length;

  bool get isEOS => offset >= end;

  int get length => end - offset;

  int readByte() => buffer[offset++];

  int readUint16() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    if (bigEndian) {
      return (b1 << 8) | b2;
    }
    return (b2 << 8) | b1;
  }

  InputBuffer subset(int count, {int? position, int offset = 0}) {
    var pos = position != null ? start + position : this.offset;
    pos += offset;
    return InputBuffer(buffer,
        bigEndian: bigEndian, offset: pos, length: count);
  }

  InputBuffer readBytes(int count) {
    final bytes = subset(count);
    offset += bytes.length;
    return bytes;
  }

  int operator [](int index) => buffer[offset + index];
}
