import 'dart:io';

import '../models/backend/monitor.dart';

abstract class MonitorInterface {
  static Future<void> register(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    String token = data["token"];

    Monitor? monitor = Monitor.preparedMonitors[token];
    if (monitor == null || monitor.id != 0) {
      await callback(HttpStatus.unauthorized, {"message": "Du bist nicht berechtigt, auf diesen Monitor zuzugreifen."});
      return;
    }

    await Monitor.insert(monitor);

    await callback(HttpStatus.ok, monitor.toJson());
  }

  static Future<void> ping(Monitor monitor, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    await callback(200, {});
  }
}
