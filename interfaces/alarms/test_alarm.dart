import 'dart:io';

import '../../firebase/fcm_methods.dart';

Future<void> sendTestAlarms(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
  await FCMMethods.sendTestAlarm();
  await callback(HttpStatus.ok, {"message": "Test successful"});
}
