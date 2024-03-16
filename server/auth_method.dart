import 'dart:io';

import '../interfaces/alarms/test_alarm.dart';

enum AuthMethod {
  none,
  test;

  static AuthMethod fromName(String name) {
    switch (name) {
      case "test":
        return AuthMethod.test;
      default:
        return AuthMethod.none;
    }
  }

  Future<void> handle(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    switch (this) {
      case AuthMethod.test:
        await sendTestAlarms(data, callback);
        return;
      case AuthMethod.none:
        await callback(HttpStatus.notFound, {"error": "not_found", "message": "Die angeforderte Resource wurde nicht gefunden"});
        return;
    }
  }
}
