import 'package:flutter/foundation.dart';

abstract final class DominoGameConfig {
  // Short debug matches make round and match celebrations easier to verify.
  // Release builds always use the official 100-point target.
  static int get targetScore => kReleaseMode ? 100 : 30;
}
