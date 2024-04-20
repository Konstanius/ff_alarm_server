import 'dart:io';

import '../../firebase/fcm_methods.dart';
import '../../models/person.dart';

Future<void> sendTestAlarms(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
  await FCMMethods.sendTestAlarm(fcms: person.fcmTokens);
  await callback(HttpStatus.ok, {"message": "Test successful."});
}
