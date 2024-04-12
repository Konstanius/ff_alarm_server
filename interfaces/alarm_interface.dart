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

  static Future<void> fetchSingle(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int alarmId = data["alarmId"];
    Alarm? alarm = await Alarm.getById(alarmId);
    if (alarm == null) {
      await callback(HttpStatus.notFound, {"message": "Alarmierung nicht gefunden"});
      return;
    }

    if (!await alarm.canSee(person)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Alarmierung zuzugreifen."});
      return;
    }

    await callback(HttpStatus.ok, alarm.toJson());
  }

  static Future<void> setResponse(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int alarmId = data["alarmId"];
    AlarmResponseType responseType = AlarmResponseType.values[data["responseType"]];
    int? stationId = data["stationId"];
    String note = data["note"];

    if (stationId == null && responseType != AlarmResponseType.notReady) {
      await callback(HttpStatus.badRequest, {"message": "Du musst eine Station angeben, wenn du eine Antwort gibst."});
      return;
    }

    Alarm? alarm = await Alarm.getById(alarmId);
    if (alarm == null) {
      await callback(HttpStatus.notFound, {"message": "Alarmierung nicht gefunden"});
      return;
    }

    if (!await alarm.canSee(person)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Alarmierung zuzugreifen."});
      return;
    }

    if (alarm.date.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
      await callback(HttpStatus.forbidden, {"message": "Die Antwortzeit ist abgelaufen."});
      return;
    }

    var time = DateTime.now();

    note = note.trim();
    note = note.substring(0, note.length > 200 ? 200 : note.length);

    Map<int, AlarmResponseType> responses = {};

    if (alarm.units.isNotEmpty) {
      Set<int> alarmUnitsForPerson = {};
      for (var unit in alarm.units) {
        if (person.allowedUnits.contains(unit)) {
          alarmUnitsForPerson.add(unit);
        }
      }

      if (alarmUnitsForPerson.isEmpty) {
        await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Alarmierung zuzugreifen."});
        return;
      }

      var units = await Unit.getByIds(alarmUnitsForPerson);
      var stations = await Station.getByIds(units.map((e) => e.stationId).toSet());
      stations.removeWhere((element) => !element.persons.contains(person.id));

      for (var station in stations) {
        if (station.id == stationId) {
          responses[stationId!] = responseType;
        } else {
          responses[station.id] = AlarmResponseType.notReady;
        }
      }
    } else {
      var stations = await Station.getForPerson(person.id);
      for (var station in stations) {
        if (station.id == stationId) {
          responses[stationId!] = responseType;
        } else {
          responses[station.id] = AlarmResponseType.notReady;
        }
      }
    }

    alarm.responses[person.id] = AlarmResponse(note: note, time: time, responses: responses);
    await Alarm.update(alarm);

    await callback(HttpStatus.ok, alarm.toJson());
  }

  static Future<void> getDetails(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    String hasAlarm = data["alarm"];
    var split = hasAlarm.split(":");
    int alarmId = int.parse(split[0]);
    Alarm? alarm = await Alarm.getById(alarmId);
    if (alarm == null) {
      await callback(HttpStatus.notFound, {"message": "Alarmierung nicht gefunden"});
      return;
    }

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
