import 'dart:io';

import '../models/alarm.dart';
import '../models/person.dart';
import '../models/station.dart';
import '../models/unit.dart';
import '../server/web_methods.dart';

abstract class WebInterface {
  static Future<void> ping(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    await callback(HttpStatus.ok, {});
  }

  static Future<void> adminManage(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> systemDiagnostics(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> logsList(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> logsGet(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> auditLogsGet(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> unitList(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var units = await Unit.getAll();
    await callback(HttpStatus.ok, {"units": units.map((e) => e.toJson()).toList()});
  }

  static Future<void> unitGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var unit = await Unit.getById(id);
    if (unit == null) {
      await callback(HttpStatus.notFound, {"message": "Einheit nicht gefunden."});
      return;
    }

    var station = await Station.getById(unit.stationId);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Zugehörige Station nicht gefunden."});
      return;
    }

    var persons = await Person.getByUnitId(unit.id);

    await callback(HttpStatus.ok, {
      "station": station.toJson(),
      "persons": persons.map((e) => e.toJson()).toList(),
    });
  }

  static Future<void> unitCreate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> unitUpdate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> unitDelete(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> stationList(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var stations = await Station.getAll();
    await callback(HttpStatus.ok, {"stations": stations.map((e) => e.toJson()).toList()});
  }

  static Future<void> stationGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var station = await Station.getById(id);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Station nicht gefunden."});
      return;
    }

    var persons = await Person.getByStationId(station.id);

    var units = await Unit.getByStationId(station.id);

    await callback(HttpStatus.ok, {
      "persons": persons.map((e) => e.toJson()).toList(),
      "units": units.map((e) => e.toJson()).toList(),
    });
  }

  static Future<void> stationCreate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> stationUpdate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> stationDelete(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> personList(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var persons = await Person.getAll();
    await callback(HttpStatus.ok, {"persons": persons.map((e) => e.toJson()).toList()});
  }

  static Future<void> personGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var person = await Person.getById(id);
    if (person == null) {
      await callback(HttpStatus.notFound, {"message": "Person nicht gefunden."});
      return;
    }

    var units = await Unit.getForPerson(person);

    var stations = await Station.getForPerson(person.id);

    await callback(HttpStatus.ok, {
      "units": units.map((e) => e.toJson()).toList(),
      "stations": stations.map((e) => e.toJson()).toList(),
    });
  }

  static Future<void> personCreate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> personUpdate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> personDelete(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> alarmList(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var alarms = await Alarm.getAll();
    await callback(HttpStatus.ok, {"alarms": alarms.map((e) => e.toJson()).toList()});
  }

  static Future<void> alarmGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var alarm = await Alarm.getById(id);
    if (alarm == null) {
      await callback(HttpStatus.notFound, {"message": "Alarm nicht gefunden."});
      return;
    }

    var personIds = await alarm.getInvolvedPersonIds();
    var persons = await Person.getByIds(personIds);

    var units = await Unit.getByIds(alarm.units);

    var stations = await Station.getByIds(units.map((e) => e.stationId));

    await callback(HttpStatus.ok, {
      "persons": persons.map((e) => e.toJson()).toList(),
      "units": units.map((e) => e.toJson()).toList(),
      "stations": stations.map((e) => e.toJson()).toList(),
    });
  }

  static Future<void> alarmCreate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> alarmUpdate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }

  static Future<void> alarmDelete(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    // TODO
    await callback(HttpStatus.ok, {});
  }
}
