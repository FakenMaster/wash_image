class McuDCT {
  List<List<List<int>>> yDCTs;
  List<List<int>> uDCTs;
  List<List<int>> vDCTs;
  McuDCT(
    this.yDCTs,
    this.uDCTs,
    this.vDCTs,
  );
}

class McuQT {
  List<List<List<int>>> yQTs;
  List<List<int>> uQTs;
  List<List<int>> vQTs;
  McuQT(
    this.yQTs,
    this.uQTs,
    this.vQTs,
  );
}

class McuStr {
  List<String> yStrs;
  String uStr;
  String vStr;
  McuStr(
    this.yStrs,
    this.uStr,
    this.vStr,
  );
}
