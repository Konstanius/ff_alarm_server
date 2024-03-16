import 'dart:io';

import '../models/alarm.dart';
import '../models/person.dart';
import '../models/station.dart';

abstract class AlarmInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};
    for (var entry in data.entries) {
      updates[int.parse(entry.key)] = DateTime.fromMillisecondsSinceEpoch(entry.value);
    }

    List<Alarm> alarms = await Alarm.getAll();
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {};

    for (Alarm alarm in alarms) {
      canSee.add(alarm.id);
      if (updates.containsKey(alarm.id) && updates[alarm.id]!.isBefore(alarm.updated)) continue;
      response.add(alarm.toJson());
    }

    var deleted = <int>[];
    for (var entry in data.entries) {
      if (!canSee.contains(int.parse(entry.key))) {
        deleted.add(int.parse(entry.key));
      }
    }

    if (response.isEmpty && deleted.isEmpty) {
      await callback(HttpStatus.ok, {});
      return;
    }

    await callback(HttpStatus.ok, {"updated": response, "deleted": deleted});
  }
}
