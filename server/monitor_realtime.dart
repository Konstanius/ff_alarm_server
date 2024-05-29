import 'dart:convert';
import 'dart:io';

import '../models/backend/monitor.dart';
import '../utils/console.dart';

class MonitorRealtimeConnection {
  static final List<MonitorRealtimeConnection> connections = [];
  Monitor monitor;
  WebSocket socket;
  late Stream stream;
  late DateTime created;
  late DateTime lastActive;
  bool controller = false;

  MonitorRealtimeConnection(this.monitor, this.socket) {
    created = DateTime.now();
    lastActive = DateTime.now();
    stream = socket.asBroadcastStream();

    connections.add(this);
  }

  void close({bool timeout = false, bool replaced = false, bool kicked = false}) {
    socket.close();
  }

  void send(String event, Map<String, dynamic> data) {
    try {
      socket.addUtf8Text(utf8.encode((jsonEncode({'event': event, 'data': data}))));
    } catch (_) {
      close();
    }
  }

  void listen() {
    stream.listen((event) async {
      try {
        String eventString;
        if (event is String) {
          eventString = event;
        } else if (event is List<int>) {
          eventString = utf8.decode(event);
        } else {
          return;
        }

        lastActive = DateTime.now();
        if (monitor.updatedAt.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
          Monitor.refresh(monitor);
        }

        Map<String, dynamic> json = jsonDecode(eventString);
        String type = json['t'];

        // TODO
      } catch (e, s) {
        outln('Data: $event', Color.error);
        outln(e.toString(), Color.warn);
        outln(s.toString(), Color.warn);
      }
    });
  }

  bool check() {
    try {
      if (DateTime.now().difference(lastActive).inSeconds > 20) {
        close(timeout: true);
        return false;
      } else {
        try {
          socket.addUtf8Text(utf8.encode('{}'));
        } catch (e) {
          close();
          return false;
        }
      }

      return true;
    } catch (e) {
      close();
      outln('Error in Monitor-Realtime-Handler: $e', Color.error);
      return false;
    }
  }

  static Future<Never> startRealtimeWatchThread() async {
    while (true) {
      try {
        await Future.delayed(const Duration(seconds: 3));
        List<MonitorRealtimeConnection> removeList = [];
        for (int i = 0; i < connections.length; i++) {
          if (!connections[i].check()) {
            removeList.add(connections[i]);
          }
        }
        for (int i = 0; i < removeList.length; i++) {
          connections.remove(removeList[i]);
        }
      } catch (e) {
        outln('Error in Monitor-Realtime-Handler: $e', Color.error);
      }
    }
  }
}
