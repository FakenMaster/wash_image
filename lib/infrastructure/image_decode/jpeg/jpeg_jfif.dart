/// jpeg/jfif
/// jpeg文件格式 https://en.wikipedia.org/wiki/JPEG#Syntax_and_structure

/// start of image
const int JPEG_SOI = 0xFFD8;

/// start of frame(baseline DCT)
const int JPEG_SOF0 = 0xFFC0;

/// start of frame(progressive DCT)
const int JPEG_SOF2 = 0xFFC2;

/// define huffman table(s)
const int JPEG_DHT = 0xFFC4;

/// define quantization table(s)
const int JPEG_DQT = 0xffDB;

/// define restart interval
const int JPEG_DRI = 0xFFDD;

/// start of scan
const int JPEG_SOS = 0xFFDA;

/// restart: RSTn 0xFF, 0xDn(n=0..7)

/// application-specific: APPn 0xFF,0xEn , such as app0 below:
/// APP0 marker
const int JPEG_APP0 = 0xFFE0;

/// comment
const int JPEG_COM = 0xFFFE;

/// end of image
const int JPEG_EOI = 0xFFD9;

/// identifier: JFIF
const int JPEG_IDENTIFIER_JFIF = 0x4A464946;

/// null byte
const int NULL_BYTE = 0x00;

/// identifier:  JFIF extension (JFXX)
const int JPEG_IDENTIFIER_JFXX = 0x4A465858;
