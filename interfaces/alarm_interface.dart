import 'dart:io';

import '../models/alarm.dart';
import '../models/person.dart';
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

    List<Alarm> alarms = await Alarm.getAll();
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
    AlarmResponse response = AlarmResponse.fromJson(data);
    int alarmId = data["alarmId"];

    Alarm alarm = await Alarm.getById(alarmId);
    if (!await alarm.canSee(person)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Alarmierung zuzugreifen."});
      return;
    }

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

    alarm.responses[person.id] = response;
    await Alarm.update(alarm);

    await callback(HttpStatus.ok, alarm.toJson());
  }
}
