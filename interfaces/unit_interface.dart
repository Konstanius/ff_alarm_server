import 'dart:io';

import '../models/person.dart';
import '../models/station.dart';
import '../models/unit.dart';

abstract class UnitInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};

    var split = data["data"].split(",");
    for (var entry in split) {
      if (entry.isEmpty) continue;
      var splitDate = entry.split(":");
      updates[int.parse(splitDate[0])] = DateTime.fromMillisecondsSinceEpoch(int.parse(splitDate[1]));
    }

    List<Unit> units = await Unit.getForPerson(person);
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {};

    for (Unit unit in units) {
      canSee.add(unit.id);
      if (updates.containsKey(unit.id) && updates[unit.id]!.millisecondsSinceEpoch == unit.updated.millisecondsSinceEpoch) continue;
      response.add(unit.toJson());
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

  static Future<void> getForStationAsAdmin(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int stationId = data["stationId"];

    Station? station = await Station.getById(stationId);
    if (station == null) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    if (!station.adminPersons.contains(person.id)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    List<Unit> units = await Unit.getByStationId(stationId);

    await callback(HttpStatus.ok, {"units": units.map((e) => e.toJson()).toList()});
  }
}
