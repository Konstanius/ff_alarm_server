import 'dart:io';

import '../interfaces/alarm_interface.dart';
import '../interfaces/alarms/test_alarm.dart';
import '../interfaces/person_interface.dart';
import '../interfaces/station_interface.dart';
import '../interfaces/unit_interface.dart';
import '../models/person.dart';

enum AuthMethod {
  stationGetAll,
  personGetAll,
  unitGetAll,
  alarmGetAll,

  none,
  test;

  static AuthMethod fromName(String name) {
    switch (name) {
      case "stationGetAll":
        return AuthMethod.stationGetAll;
      case "personGetAll":
        return AuthMethod.personGetAll;
      case "unitGetAll":
        return AuthMethod.unitGetAll;
      case "alarmGetAll":
        return AuthMethod.alarmGetAll;
      case "test":
        return AuthMethod.test;
      default:
        return AuthMethod.none;
    }
  }

  Future<void> handle(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    switch (this) {
      case AuthMethod.test:
        return await sendTestAlarms(data, callback);
      case AuthMethod.stationGetAll:
        return await StationInterface.getAll(person, data, callback);
      case AuthMethod.personGetAll:
        return await PersonInterface.getAll(person, data, callback);
      case AuthMethod.unitGetAll:
        return await UnitInterface.getAll(person, data, callback);
      case AuthMethod.alarmGetAll:
        return await AlarmInterface.getAll(person, data, callback);
      case AuthMethod.none:
        return await callback(HttpStatus.notFound, {"error": "not_found", "message": "Die angeforderte Resource wurde nicht gefunden"});
    }
  }
}
