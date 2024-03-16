import 'dart:io';

import '../models/person.dart';
import '../models/unit.dart';

abstract class UnitInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};
    for (var entry in data.entries) {
      updates[int.parse(entry.key)] = DateTime.fromMillisecondsSinceEpoch(entry.value);
    }

    List<Unit> units = await Unit.getAll();
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {};

    for (Unit unit in units) {
      canSee.add(unit.id);
      if (updates.containsKey(unit.id) && updates[unit.id]!.isBefore(unit.updated)) continue;
      response.add(unit.toJson());
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
