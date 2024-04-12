import '../interfaces/alarm_interface.dart';
import '../interfaces/alarms/test_alarm.dart';
import '../interfaces/guest_interface.dart';
import '../interfaces/person_interface.dart';
import '../interfaces/station_interface.dart';
import '../interfaces/unit_interface.dart';
import '../models/person.dart';

abstract class AuthMethod {
  static const Map<String, Future<void> Function(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback)> authMethods = {
    "stationGetAll": StationInterface.getAll,
    "personGetAll": PersonInterface.getAll,
    "personSetResponse": PersonInterface.setResponse,
    "unitGetAll": UnitInterface.getAll,
    "alarmGetAll": AlarmInterface.getAll,
    "alarmFetchSingle": AlarmInterface.fetchSingle,
    "alarmSetResponse": AlarmInterface.setResponse,
    "alarmGetDetails": AlarmInterface.getDetails,
    "test": sendTestAlarms,
  };

  static const Map<String, Future<void> Function(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback)> guestMethods = {
    "login": GuestInterface.login,
    "logout": GuestInterface.logout,
  };
}
