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
