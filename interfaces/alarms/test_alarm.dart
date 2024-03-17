import 'dart:io';

import '../../firebase/fcm_methods.dart';
import '../../models/person.dart';

Future<void> sendTestAlarms(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
  await FCMMethods.sendTestAlarm();
  await callback(HttpStatus.ok, {"message": "Test successful"});
}
