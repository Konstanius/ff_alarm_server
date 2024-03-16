import 'dart:io';

import '../models/person.dart';

abstract class PersonInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};
    for (var entry in data.entries) {
      updates[int.parse(entry.key)] = DateTime.fromMillisecondsSinceEpoch(entry.value);
    }

    List<Person> persons = await Person.getAll();
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {};

    for (Person person in persons) {
      canSee.add(person.id);
      if (updates.containsKey(person.id) && updates[person.id]!.isBefore(person.updated)) continue;
      response.add(person.toJson());
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
