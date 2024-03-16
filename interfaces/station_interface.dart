import 'dart:io';

import '../models/person.dart';
import '../models/station.dart';

abstract class StationInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};
    for (var entry in data.entries) {
      updates[int.parse(entry.key)] = DateTime.fromMillisecondsSinceEpoch(entry.value);
    }

    List<Station> stations = await Station.getAll();
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {};

    for (Station station in stations) {
      canSee.add(station.id);
      if (updates.containsKey(station.id) && updates[station.id]!.isBefore(station.updated)) continue;
      response.add(station.toJson());
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
