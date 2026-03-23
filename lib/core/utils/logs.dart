import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

void logcat(String tag, String message) {
  if (kDebugMode) {
    debugPrint("$tag :- $message");
  }
}
