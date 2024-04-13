import 'dart:io';

import '../models/person.dart';
import '../models/station.dart';

abstract class PersonInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};

    var split = data["data"].split(",");
    for (var entry in split) {
      if (entry.isEmpty) continue;
      var splitDate = entry.split(":");
      updates[int.parse(splitDate[0])] = DateTime.fromMillisecondsSinceEpoch(int.parse(splitDate[1]));
    }

    var userStations = await Station.getForPerson(person.id);
    Set<int> stationPersons = {};
    for (var station in userStations) {
      stationPersons.addAll(station.persons);
    }

    List<Person> persons = await Person.getByIds(stationPersons.toList());
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {person.id};

    for (Person person in persons) {
      canSee.add(person.id);
      if (updates.containsKey(person.id) && updates[person.id]!.millisecondsSinceEpoch == person.updated.millisecondsSinceEpoch) continue;
      response.add(person.toJson());
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
    var responses = PersonStaticAlarmResponse.fromJsonMap(data);

    var allStations = await Station.getForPerson(person.id);
    Set<int> allStationIds = allStations.map((e) => e.id).toSet();
    responses.removeWhere((key, value) => !allStationIds.contains(key));

    var personCopy = await Person.getById(person.id);
    personCopy!.response = responses;
    await Person.update(personCopy);

    await callback(HttpStatus.ok, {});
  }

  static Map<int, ({double lat, double lon, int time})> globalLocations = {};
  static const int locationTimeout = 600000;

  static Future<void> setLocation(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    double lat = data["a"];
    double lon = data["o"];
    int time = data["t"];

    var last = globalLocations[person.id];
    if (last != null && last.time > time) {
      callback(HttpStatus.ok, {});
      return;
    }

    globalLocations[person.id] = (lat: lat, lon: lon, time: time);

    callback(HttpStatus.ok, {});
  }
}
