import 'dart:io';

import '../models/alarm.dart';
import '../models/person.dart';
import '../models/station.dart';
import '../models/unit.dart';

abstract class AlarmInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};

    var split = data["data"].split(",");
    for (var entry in split) {
      if (entry.isEmpty) continue;
      var splitDate = entry.split(":");
      updates[int.parse(splitDate[0])] = DateTime.fromMillisecondsSinceEpoch(int.parse(splitDate[1]));
    }

    List<Alarm> alarms = await Alarm.getAll(oldest: DateTime.now().subtract(const Duration(days: 90)));
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {};

    for (Alarm alarm in alarms) {
      canSee.add(alarm.id);
      if (updates.containsKey(alarm.id) && updates[alarm.id]!.millisecondsSinceEpoch == alarm.updated.millisecondsSinceEpoch) continue;
      response.add(alarm.toJson());
    }

    var deleted = <int>[];
    for (var entry in updates.entries) {
      if (!canSee.contains(entry.key)) {
        deleted.add(entry.key);
      }
    }

    if (response.isEmpty && deleted.isEmpty) {
      await callback(HttpStatus.ok, {});
      return;
    }

    await callback(HttpStatus.ok, {"updated": response, "deleted": deleted});
  }

  static Future<void> setResponse(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    AlarmResponse? response = AlarmResponse.fromJson(data);
    if (response == null) {
      await callback(HttpStatus.badRequest, {"message": "Ungültige Daten"});
      return;
    }
    int alarmId = data["alarmId"];

    Alarm alarm = await Alarm.getById(alarmId);
    if (!await alarm.canSee(person)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Alarmierung zuzugreifen."});
      return;
    }

    if (alarm.date.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
      await callback(HttpStatus.forbidden, {"message": "Die Antwortzeit ist abgelaufen."});
      return;
    }

    if (response.type == AlarmResponseType.notReady) {
      response.stationId = null;
    }

    // if response exists already and type and stattion is same, dont set time
    if (alarm.responses.containsKey(person.id) && alarm.responses[person.id]!.type == response.type && alarm.responses[person.id]!.stationId == response.stationId) {
      response.time = alarm.responses[person.id]!.time;
    } else {
      response.time = DateTime.now();
    }

    if (response.note != null) {
      response.note = response.note!.trim();
      response.note = response.note!.substring(0, response.note!.length > 200 ? 200 : response.note!.length);
      if (response.note!.isEmpty) {
        response.note = null;
      }
    }

    if (alarm.units.isNotEmpty) {
      int? station = response.stationId;
      if (station != null) {
        var units = await Unit.getByStationId(station);
        bool allowed = false;
        for (var unit in units) {
          if (!alarm.units.contains(unit.id)) continue;
          if (!person.allowedUnits.contains(unit.id)) continue;
          allowed = true;
        }

        if (!allowed) {
          await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Alarmierung zuzugreifen."});
          return;
        }
      }
    }

    alarm.responses[person.id] = response;
    await Alarm.update(alarm);

    await callback(HttpStatus.ok, alarm.toJson());
  }

  static Future<void> getDetails(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    String hasAlarm = data["alarm"];
    var split = hasAlarm.split(":");
    int alarmId = int.parse(split[0]);
    Alarm alarm = await Alarm.getById(alarmId);
    if (alarm.units.isEmpty) {
      await callback(HttpStatus.ok, {});
      return;
    }

    if (!await alarm.canSee(person)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Alarmierung zuzugreifen."});
      return;
    }

    List<String> hasUnits = data["units"].split(",");
    List<String> hasStations = data["stations"].split(",");
    List<String> hasPersons = data["persons"].split(",");

    // what has to be sent:
    // alarm itself
    // all units
    // stations of all units
    // all persons of response
    Map<String, dynamic> response = {};

    int version = int.parse(split[1]);
    if (alarm.updated.millisecondsSinceEpoch != version) {
      response["alarm"] = alarm.toJson();
    }

    var units = await alarm.getUnits();
    for (String unit in hasUnits) {
      try {
        var split = unit.split(":");
        int id = int.parse(split[0]);
        int version = int.parse(split[1]);

        for (var u in units) {
          if (u.id == id && u.updated.millisecondsSinceEpoch == version) {
            units.remove(u);
            break;
          }
        }
      } catch (_) {}
    }
    if (units.isNotEmpty) {
      if (alarm.date.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
        for (var unit in units) {
          if (person.allowedUnits.contains(unit.id)) continue;
          unit.status = -1;
        }
      }

      response["units"] = units.map((e) => e.toJson()).toList();
    }

    var stationIds = <int>{};
    for (var unit in units) {
      stationIds.add(unit.stationId);
    }
    var stations = await Station.getByIds(stationIds);
    for (String station in hasStations) {
      try {
        var split = station.split(":");
        int id = int.parse(split[0]);
        int version = int.parse(split[1]);

        for (var s in stations) {
          if (s.id == id && s.updated.millisecondsSinceEpoch == version) {
            stations.remove(s);
            break;
          }
        }
      } catch (_) {}
    }
    if (stations.isNotEmpty) {
      response["stations"] = stations.map((e) => e.toJson()).toList();
    }

    var personIds = alarm.responses.keys.toList();
    var persons = await Person.getByIds(personIds);
    for (String person in hasPersons) {
      try {
        var split = person.split(":");
        int id = int.parse(split[0]);
        int version = int.parse(split[1]);

        for (var p in persons) {
          if (p.id == id && p.updated.millisecondsSinceEpoch == version) {
            persons.remove(p);
            break;
          }
        }
      } catch (_) {}
    }
    if (persons.isNotEmpty) {
      response["persons"] = persons.map((e) => e.toJson()).toList();
    }

    await callback(HttpStatus.ok, response);
  }
}
