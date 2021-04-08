import '../../util/util.dart';

class PixelRGB {
  int R;
  int G;
  int B;
  PixelRGB(
    this.R,
    this.G,
    this.B,
  );

  PixelYUV convert2YUV() {
    int Y = (0.299 * R + 0.587 * G + 0.114 * B).round();
    int Cb = (-0.1687 * R - 0.3313 * G + 0.5 * B + 128).round();
    int Cr = (0.5 * R - 0.4187 * G - 0.0813 * B + 128).round();
    return PixelYUV(Y, Cb, Cr);
  }

  @override
  String toString() {
    return "$R $G $B";
  }
}

/// Y,Cr,Cb的值在[0..255]范围
class PixelYUV {
  int Y;
  int Cb;
  int Cr;
  PixelYUV(
    this.Y,
    this.Cb,
    this.Cr,
  );

  PixelRGB convert2RGB() {
    int R = (Y + 1.402 * (Cr - 128)).round().clampUnsignedByte;
    int G = (Y - 0.34414 * (Cb - 128) - 0.71414 * (Cr - 128)).round().clampUnsignedByte;
    int B = (Y + 1.772 * (Cb - 128)).round().clampUnsignedByte;
    return PixelRGB(R, G, B);
  }

  @override
  String toString() {
    return "($Y, $Cb, $Cr)";
  }
}
