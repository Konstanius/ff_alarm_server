import 'dart:io';

import '../server/web_methods.dart';

abstract class WebInterface {
  static Future<void> ping(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    await callback(HttpStatus.ok, {});
  }
}
