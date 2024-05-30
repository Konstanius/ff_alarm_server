import 'dart:io';

import '../models/backend/monitor.dart';
import '../models/person.dart';
import '../models/station.dart';
import '../models/unit.dart';
import '../utils/generic.dart';

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

    var persons = await Person.getByIds(personIds);

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

        for (var qualification in person.visibleQualificationsAt(now)) {
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

  static Future<void> removePerson(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int personId = data["personId"];
    int stationId = data["stationId"];

    var station = await Station.getById(stationId);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Die Wache wurde nicht gefunden."});
      return;
    }

    if (!station.adminPersons.contains(person.id)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    if (personId == person.id) {
      await callback(HttpStatus.forbidden, {"message": "Du kannst dich nicht selbst von der Wache entfernen."});
      return;
    }

    if (!station.persons.contains(personId)) {
      await callback(HttpStatus.notFound, {"message": "Die Person ist nicht auf dieser Wache."});
      return;
    }

    station.persons.remove(personId);
    station.adminPersons.remove(personId);
    await Station.update(station);

    var toRemove = await Person.getById(personId);
    if (toRemove != null) {
      var units = await Unit.getByStationId(stationId);
      for (var unit in units) {
        if (toRemove.allowedUnits.contains(unit.id)) {
          toRemove.allowedUnits.remove(unit.id);
        }
      }

      toRemove.response.remove(stationId);

      await Person.update(toRemove);
    }

    await callback(HttpStatus.ok, station.toJson());
  }

  static Future<void> addPerson(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int personId = data["personId"];
    int stationId = data["stationId"];

    var station = await Station.getById(stationId);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Die Wache wurde nicht gefunden."});
      return;
    }

    if (!station.adminPersons.contains(person.id)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    if (station.persons.contains(personId)) {
      await callback(HttpStatus.conflict, {"message": "Die Person ist bereits auf dieser Wache."});
      return;
    }

    station.persons.add(personId);
    await Station.update(station);

    var toAdd = await Person.getById(personId);
    if (toAdd != null) {
      var units = await Unit.getByStationId(stationId);
      for (var unit in units) {
        if (!toAdd.allowedUnits.contains(unit.id) && !toAdd.allowedUnits.contains(-unit.id)) {
          toAdd.allowedUnits.add(unit.id);
        }
      }

      await Person.update(toAdd);
    }

    await callback(HttpStatus.ok, station.toJson());
  }

  static Future<void> setAdmin(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int personId = data["personId"];
    bool toAdmin = data["toAdmin"];
    int stationId = data["stationId"];

    var station = await Station.getById(stationId);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Die Wache wurde nicht gefunden."});
      return;
    }

    if (!station.adminPersons.contains(person.id)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    if (personId == person.id) {
      await callback(HttpStatus.forbidden, {"message": "Du kannst deine eigenen Rechte nicht ändern."});
      return;
    }

    if (!station.persons.contains(personId)) {
      await callback(HttpStatus.notFound, {"message": "Die Person ist nicht auf dieser Wache."});
      return;
    }

    if (toAdmin) {
      station.adminPersons.add(personId);
    } else {
      station.adminPersons.remove(personId);
    }

    await Station.update(station);

    await callback(HttpStatus.ok, station.toJson());
  }

  static Future<void> generateMonitor(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int stationId = data["stationId"];
    List<int> units = data["units"].cast<int>().toSet().toList();
    String name = data["name"];

    var station = await Station.getById(stationId);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Die Wache wurde nicht gefunden."});
      return;
    }
    if (!station.adminPersons.contains(person.id)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    List<Unit> unitsList = await Unit.getByStationId(stationId);
    for (var unit in units) {
      if (!unitsList.any((element) => element.id == unit)) {
        await callback(HttpStatus.notFound, {"message": "Eine der ausgeählten Einheiten wurde nicht innerhalb der Wache gefunden."});
        return;
      }
    }

    String token;
    while (true) {
      token = HashUtils.generateRandomKey();
      if (!Monitor.preparedMonitors.containsKey(token)) break;
    }
    String hash = HashUtils.lightHash(token);

    Monitor monitor = Monitor(
      id: 0,
      name: name,
      stationId: stationId,
      units: units,
      tokenHash: hash,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 60)),
    );
    Monitor.preparedMonitors[token] = monitor;

    // remove from preparedMonitors where > 10m ago
    DateTime ago = DateTime.now().subtract(const Duration(minutes: 10));
    Monitor.preparedMonitors.removeWhere((key, value) => value.createdAt.isBefore(ago));

    await callback(HttpStatus.ok, {"token": token});
  }

  static Future<void> checkMonitor(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    String token = data["token"];

    Monitor? monitor = Monitor.preparedMonitors[token];
    if (monitor == null) {
      await callback(HttpStatus.ok, {"check": false});
      return;
    }

    await callback(HttpStatus.ok, {"check": monitor.id != 0});
  }

  static Future<void> listMonitors(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
  }

  static Future<void> updateMonitor(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
  }

  static Future<void> removeMonitor(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
  }
}
