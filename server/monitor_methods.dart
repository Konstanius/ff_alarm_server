import '../models/backend/monitor.dart';

abstract class MonitorMethods {
  static const Map<String, Future<void> Function(Monitor monitor, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback)> authMethods = {
    // TODO
  };

  static const Map<String, Future<void> Function(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback)> guestMethods = {
    // TODO: login
  };
}
