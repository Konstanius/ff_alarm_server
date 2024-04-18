import 'dart:io';

import '../models/person.dart';
import '../models/station.dart';

abstract class StationInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};

    var split = data["data"].split(",");
    for (var entry in split) {
      if (entry.isEmpty) continue;
      var splitDate = entry.split(":");
      updates[int.parse(splitDate[0])] = DateTime.fromMillisecondsSinceEpoch(int.parse(splitDate[1]));
    }

    List<Station> stations = await Station.getForPerson(person.id);
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {};

    for (Station station in stations) {
      canSee.add(station.id);
      if (updates.containsKey(station.id) && updates[station.id]!.millisecondsSinceEpoch == station.updated.millisecondsSinceEpoch) continue;
      response.add(station.toJson());
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

  static Future<void> getNotifyModes(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var stations = await Station.getForPerson(person.id);
    if (stations.isEmpty) {
      await callback(HttpStatus.ok, {});
      return;
    }

    var personIds = <int>{};
    for (var station in stations) {
      personIds.addAll(station.persons);
    }

    var persons = await Person.getByIds(personIds.toList());

    DateTime now = DateTime.now();
    int day = now.weekday;
    int dayMillis = now.hour * 3600000 + now.minute * 60000 + now.second * 1000 + now.millisecond;

    Map<String, dynamic> response = {};
    for (var person in persons) {
      for (var station in stations) {
        if (!station.persons.contains(person.id)) continue;
        if (!response.containsKey(station.id.toString())) {
          response[station.id.toString()] = {
            "y": {},
            "n": {},
            "u": {},
            "yT": 0,
            "nT": 0,
            "uT": 0,
          };
        }

        NotifyInformation notifyMode = person.response[station.id]?.getNotifyMode(person.id, now, dayMillis, day) ?? NotifyInformation.unknown;

        response[station.id.toString()]["${notifyMode.value}T"] = response[station.id.toString()]["${notifyMode.value}T"] + 1;

        for (var qualification in person.qualifications) {
          if (!response[station.id.toString()][notifyMode.value].containsKey(qualification.type)) {
            response[station.id.toString()][notifyMode.value][qualification.type] = 1;
          } else {
            response[station.id.toString()][notifyMode.value][qualification.type] = response[station.id.toString()][notifyMode.value][qualification.type] + 1;
          }
        }
      }
    }

    await callback(HttpStatus.ok, response);
  }
}
