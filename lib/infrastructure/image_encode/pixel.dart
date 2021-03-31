class PixelRGB {
  int R;
  int G;
  int B;
  PixelRGB(
    this.R,
    this.G,
    this.B,
  );

  PixelYUV? convert2YUV() {
    return null;
  }
}

class PixelYUV {
  int Y;
  int Cb;
  int Cr;
  PixelYUV(
    this.Y,
    this.Cb,
    this.Cr,
  );

  PixelRGB? convert2RGB() {
    return null;
  }
}
