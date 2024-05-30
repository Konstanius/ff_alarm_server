import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

import '../models/backend/monitor.dart';
import '../models/backend/session.dart';
import '../models/person.dart';
import '../utils/console.dart';
import '../utils/generic.dart';
import 'app_methods.dart';
import 'app_realtime.dart';
import 'monitor_methods.dart';
import 'monitor_realtime.dart';
import 'web_methods.dart';

Future<void> initServer() async {
  AppRealtimeConnection.startRealtimeWatchThread();
  MonitorRealtimeConnection.startRealtimeWatchThread();

  String oldLog = "";
  if (File('logs/latest.log').existsSync()) {
    String date = File('logs/latest.log').readAsLinesSync()[0].replaceAll('\n', '');
    File('logs/latest.log').renameSync('logs/$date.log');
    oldLog = 'logs/$date.log';

    // compress the old log
    Process.runSync('gzip', [oldLog]);

    // Delete any logs older than 1 year
    Directory('logs').listSync().forEach((element) {
      if (element.path.endsWith('.log') && element.path != 'logs/latest.log') {
        DateTime date = DateTime.parse(element.path.substring(5, element.path.length - 4));
        if (date.isBefore(DateTime.now().subtract(Duration(days: 365)))) {
          element.deleteSync();
        }
      }
    });
  }
  logFile = File('logs/latest.log');
  if (!logFile!.existsSync()) {
    logFile!.createSync(recursive: true);
  }
  DateTime now = DateTime.now();
  logFile!.writeAsStringSync('${DateFormat("yyyy-MM-dd_HH-mm-ss").format(now)}\n', mode: FileMode.append);

  HttpServer server = await HttpServer.bind('0.0.0.0', 3000);
  server.listen((HttpRequest request) async {
    try {
      Uri uri = request.uri;
      if (uri.pathSegments.length < 2 && uri.pathSegments.lastOrNull != 'realtime') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.flush();
        await request.response.close();
        return;
      }

      if (uri.pathSegments[0] == 'realtime') {
        await handleRealtime(request);
        return;
      }

      if (uri.pathSegments[0] != 'api') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.flush();
        await request.response.close();
        return;
      }

      String keyword = uri.pathSegments[1];

      Future<void> callback(int statusCode, Map<String, dynamic> response) async {
        request.response.statusCode = statusCode;
        List<int> data = utf8.encode(json.encode(response));
        request.response.contentLength = data.length;
        request.response.add(data);
        await request.response.flush();
        await request.response.close();

        if (statusCode != HttpStatus.ok) {
          outln('Request failed with status code $statusCode: $response', Color.warn);
          outln('Request: ${request.uri}, stacktrace:', Color.warn);
          outln(StackTrace.current.toString().split('\n')[2], Color.warn);
        }
      }

      if (request.headers.value('authorization') == null) {
        Map<String, dynamic>? data;
        try {
          String boundRequest = await utf8.decoder.bind(request).join();
          data = json.decode(boundRequest);
        } catch (e) {
          await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
          return;
        }

        var method = AppMethods.guestMethods[keyword];
        if (method == null) {
          await callback(HttpStatus.notFound, {"message": "Die angeforderte Resource wurde nicht gefunden."});
          return;
        }

        try {
          await method(data!, callback);
        } on RequestException catch (e) {
          await callback(e.statusCode, {"message": e.message});
        } catch (e, s) {
          request.response.statusCode = HttpStatus.internalServerError;
          outln("Internal server error: $e\n$s", Color.error);
          request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten."})));
          await request.response.flush();
          await request.response.close();
        }
        return;
      }

      String rawAuth = request.headers.value('authorization')!;

      String decodedAuth = utf8.decode(gzip.decode(base64.decode(rawAuth)));
      if (!decodedAuth.contains(' ')) {
        await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
        return;
      }

      List<String> authParts = decodedAuth.split(' ');
      if (authParts.length != 2) {
        await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
        return;
      }

      if (authParts.first == "tetra") {
        /// TODO implement API authentication from TETRA servers
        /// Interfaces that are required:
        /// - unitSetStatus
        /// - unitChangeStation
        /// - alarmSend
        /// - alarmTest
        /// - alarmUpdate
        /// - ? alarmCancel
        return;
      }

      if (authParts.first == "admin") {
        String info = authParts[1];
        if (info.contains(':')) {
          List<String> infoParts = info.split(':');
          if (infoParts.length != 3) {
            await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
            return;
          }

          String username = utf8.decode(base64.decode(infoParts[0]));
          String password = utf8.decode(base64.decode(infoParts[1]));
          String otpCode = utf8.decode(base64.decode(infoParts[2]));

          WebSession? session = await WebSession.createSession(username: username, password: password, otpCode: otpCode);
          if (session == null) {
            await callback(HttpStatus.unauthorized, {"message": "Ungültige Zugangsdaten."});
            return;
          }

          await callback(HttpStatus.ok, {"token": session.token});
          return;
        } else {
          WebSession? session = WebSession.getSession(authParts[1]);
          if (session == null) {
            await callback(HttpStatus.unauthorized, {"message": "Kein Zugriff auf diese Resource."});
            return;
          }

          var method = WebMethods.methods[keyword];
          if (method == null) {
            await callback(HttpStatus.notFound, {"message": "Die angeforderte Resource wurde nicht gefunden."});
            return;
          }

          Map<String, dynamic>? data;
          try {
            String boundRequest = await utf8.decoder.bind(request).join();
            data = json.decode(boundRequest);
          } catch (e) {
            await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
            return;
          }

          try {
            await method(session, data!, callback);
          } on RequestException catch (e) {
            await callback(e.statusCode, {"message": e.message});
          } catch (e, s) {
            request.response.statusCode = HttpStatus.internalServerError;
            outln("Internal server error: $e\n$s", Color.error);
            request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten."})));
            await request.response.flush();
            await request.response.close();
          }
        }
        return;
      }

      int? sessionId = int.tryParse(authParts[0]);
      if (sessionId == null) {
        await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
        return;
      }
      String key = authParts[1];

      if (sessionId < 0) {
        /// Interfaces that are required:
        /// - alarmGetActive
        /// - alarmGetDetails
        /// - stationGetStats
        /// - unitGetAll
        int properId = -sessionId;
        Monitor? monitor = await Monitor.getById(properId);
        if (monitor == null) {
          await callback(HttpStatus.unauthorized, {"message": "Kein Zugriff auf diese Resource."});
          return;
        }

        bool valid = await monitor.validate(key);
        if (!valid) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.flush();
          await request.response.close();
          return;
        }

        var method = MonitorMethods.authMethods[keyword];
        if (method == null) {
          await callback(HttpStatus.notFound, {"message": "Die angeforderte Resource wurde nicht gefunden."});
          return;
        }

        Map<String, dynamic>? data;
        try {
          String boundRequest = await utf8.decoder.bind(request).join();
          data = json.decode(boundRequest);
        } catch (e) {
          await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
          return;
        }

        try {
          await method(monitor, data!, callback);
        } on RequestException catch (e) {
          await callback(e.statusCode, {"message": e.message});
        } catch (e, s) {
          request.response.statusCode = HttpStatus.internalServerError;
          outln("Internal server error: $e\n$s", Color.error);
          request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten."})));
          await request.response.flush();
          await request.response.close();
        }
        return;
      }

      Session? session = await Session.getById(sessionId);
      if (session == null) {
        await callback(HttpStatus.unauthorized, {"message": "Kein Zugriff auf diese Resource."});
        return;
      }

      bool valid = await session.validate(key);
      if (!valid) {
        await callback(HttpStatus.unauthorized, {"message": "Kein Zugriff auf diese Resource."});
        return;
      }

      Person? person = await Person.getById(session.personId);
      if (person == null) {
        await callback(HttpStatus.unauthorized, {"message": "Kein Zugriff auf diese Resource."});
        return;
      }

      var method = AppMethods.authMethods[keyword];
      if (method == null) {
        await callback(HttpStatus.notFound, {"message": "Die angeforderte Resource wurde nicht gefunden."});
        return;
      }

      Map<String, dynamic>? data;
      try {
        String boundRequest = await utf8.decoder.bind(request).join();
        data = json.decode(boundRequest);
      } catch (e) {
        await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden."});
        return;
      }

      String? rawFCMToken = request.headers.value('fcmToken');
      String? fcmToken;
      if (rawFCMToken != null) {
        fcmToken = utf8.decode(gzip.decode(base64.decode(rawFCMToken)));
      }

      if (fcmToken != null && fcmToken.isNotEmpty && !person.fcmTokens.contains(fcmToken)) {
        person.fcmTokens.add(fcmToken);
        await Person.update(person);
      }

      try {
        await method(person, data!, callback);
      } on RequestException catch (e) {
        await callback(e.statusCode, {"message": e.message});
      } catch (e, s) {
        request.response.statusCode = HttpStatus.internalServerError;
        outln("Internal server error: $e\n$s", Color.error);
        request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten."})));
        await request.response.flush();
        await request.response.close();
      }
    } catch (e, s) {
      request.response.statusCode = HttpStatus.internalServerError;
      outln("Internal server error: $e\n$s", Color.error);
      request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten."})));
      await request.response.flush();
      await request.response.close();
    }
  });
}

Future<void> handleRealtime(HttpRequest request) async {
  try {
    String? rawAuth = request.headers.value('authorization');
    if (rawAuth == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.flush();
      await request.response.close();
      return;
    }

    String decodedAuth = utf8.decode(gzip.decode(base64.decode(rawAuth)));
    if (!decodedAuth.contains(' ')) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.flush();
      await request.response.close();
      return;
    }

    List<String> authParts = decodedAuth.split(' ');
    if (authParts.first == "Basic") {
      request.response.statusCode = HttpStatus.notImplemented;
      await request.response.flush();
      await request.response.close();
      return;
    }

    int? sessionId = int.tryParse(authParts[0]);
    if (sessionId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.flush();
      await request.response.close();
      return;
    }
    String key = authParts[1];

    if (sessionId < 0) {
      int properId = -sessionId;
      Monitor? monitor = await Monitor.getById(properId);
      if (monitor == null) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.flush();
        await request.response.close();
        return;
      }

      bool valid = await monitor.validate(key);
      if (!valid) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.flush();
        await request.response.close();
        return;
      }

      if (WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.bufferOutput = false;
        WebSocket webSocket = await WebSocketTransformer.upgrade(request);
        MonitorRealtimeConnection connection = MonitorRealtimeConnection(monitor, webSocket);
        connection.listen();
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.flush();
        await request.response.close();
      }
      return;
    }

    Session? session = await Session.getById(sessionId);
    if (session == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.flush();
      await request.response.close();
      return;
    }

    bool valid = await session.validate(key);
    if (!valid) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.flush();
      await request.response.close();
      return;
    }

    Person? person = await Person.getById(session.personId);
    if (person == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.flush();
      await request.response.close();
      return;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.bufferOutput = false;
      WebSocket webSocket = await WebSocketTransformer.upgrade(request);
      AppRealtimeConnection connection = AppRealtimeConnection(session, person, webSocket);
      connection.listen();
    } else {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.flush();
      await request.response.close();
    }
  } catch (e) {
    request.response.statusCode = HttpStatus.badRequest;
    await request.response.flush();
    await request.response.close();
  }
}
