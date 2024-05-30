import '../interfaces/monitor_interface.dart';
import '../models/backend/monitor.dart';

abstract class MonitorMethods {
  static const Map<String, Future<void> Function(Monitor monitor, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback)> authMethods = {
    "ping": MonitorInterface.ping,
  };
}
