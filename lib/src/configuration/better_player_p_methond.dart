// enum BetterPlayerPMethonds {
//   AUTO, //视频默认宽高比
//   FILL, //拉伸 将宽高拉伸至设置的宽高比
//   COVER, //填充 以最短边拉伸至设置的宽高比
// }

import 'package:flutter/cupertino.dart';

class BetterPlayerBoxFitWithText {
  final BoxFit type;
  final String text;

  const BetterPlayerBoxFitWithText(this.type, {this.text})
      : assert(type != null);
}
