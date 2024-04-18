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
    "stationGetNotifyModes": StationInterface.getNotifyModes,
    "personGetAll": PersonInterface.getAll,
    "personSetResponse": PersonInterface.setResponse,
    "personSetLocation": PersonInterface.setLocation,
    "personCreate": PersonInterface.create,
    "unitGetAll": UnitInterface.getAll,
    "unitGetForStation": UnitInterface.getForStationAsAdmin,
    "alarmGetAll": AlarmInterface.getAll,
    "alarmGet": AlarmInterface.fetchSingle,
    "alarmSetResponse": AlarmInterface.setResponse,
    "alarmGetDetails": AlarmInterface.getDetails,
    "alarmSendExample": AlarmInterface.sendExample,
    "test": sendTestAlarms,
  };

  static const Map<String, Future<void> Function(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback)> guestMethods = {
    "login": GuestInterface.login,
    "logout": GuestInterface.logout,
  };
}
