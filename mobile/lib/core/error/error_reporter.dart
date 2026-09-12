import 'package:flutter/foundation.dart';

import '../config/environment.dart';

class ErrorReporter {
  ErrorReporter._();

  static void report(Object error, StackTrace stackTrace, {String? context}) {
    if (Environment.isProduction) {
      return;
    }
    debugPrint('❌ [${context ?? 'unhandled'}] $error\n$stackTrace');
  }
}
