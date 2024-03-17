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

    List<Station> stations = await Station.getAll();
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
}
