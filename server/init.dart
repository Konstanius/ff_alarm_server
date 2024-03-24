import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

import '../models/person.dart';
import '../utils/console.dart';
import '../utils/generic.dart';
import 'auth_method.dart';

Future<void> initServer() async {
  startRealtimeWatchThread();

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

      if (uri.pathSegments[0] != 'api' && uri.pathSegments[0] != 'realtime') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.flush();
        await request.response.close();
        return;
      }

      String keyword = uri.pathSegments[1];

      if (keyword == 'ping') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.flush();
        await request.response.close();
        return;
      }

      if (uri.pathSegments[0] == 'realtime') {
        await handleRealtime(request);
        return;
      }

      Future<void> callback(int statusCode, Map<String, dynamic> response) async {
        request.response.statusCode = statusCode;
        List<int> data = utf8.encode(json.encode(response));
        request.response.contentLength = data.length;
        request.response.add(data);
        await request.response.flush();
        await request.response.close();
      }

      if (request.headers.value('authorization') == null) {
        Map<String, dynamic>? data;
        try {
          String boundRequest = await utf8.decoder.bind(request).join();
          data = json.decode(boundRequest);
        } catch (e) {
          await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden"});
          return;
        }

        var method = AuthMethod.guestMethods[keyword];
        if (method == null) {
          await callback(HttpStatus.notFound, {"message": "Die angeforderte Resource wurde nicht gefunden"});
          return;
        }

        try {
          await method(data!, callback);
        } on RequestException catch (e) {
          callback(e.statusCode, {"message": e.message});
        } catch (e, s) {
          request.response.statusCode = HttpStatus.internalServerError;
          outln("Internal server error: $e\n$s", Color.error);
          request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten"})));
          await request.response.flush();
          await request.response.close();
        }
        return;
      }

      String rawAuth = request.headers.value('authorization')!;

      String decodedAuth = utf8.decode(gzip.decode(base64.decode(rawAuth)));
      if (!decodedAuth.contains(' ')) {
        await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden"});
        return;
      }

      List<String> authParts = decodedAuth.split(' ');
      if (authParts.first == "Basic") {
        // TODO implement API authentication from TETRA servers
        return;
      }

      int personId = int.parse(authParts[0]);
      String key = authParts[1];

      Person? person;
      try {
        person = await Person.getById(personId);
      } catch (e) {
        outln("Error: $e", Color.error);
        await callback(HttpStatus.unauthorized, {"message": "Kein Zugriff auf diese Resource"});
        return;
      }

      if (person.registrationKey != key) {
        await callback(HttpStatus.unauthorized, {"message": "Kein Zugriff auf diese Resource"});
        return;
      }

      var method = AuthMethod.authMethods[keyword];
      if (method == null) {
        await callback(HttpStatus.notFound, {"message": "Die angeforderte Resource wurde nicht gefunden"});
        return;
      }

      Map<String, dynamic>? data;
      try {
        String boundRequest = await utf8.decoder.bind(request).join();
        data = json.decode(boundRequest);
      } catch (e) {
        await callback(HttpStatus.badRequest, {"message": "Die Anfrage konnte nicht verarbeitet werden"});
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
        callback(e.statusCode, {"message": e.message});
      } catch (e, s) {
        request.response.statusCode = HttpStatus.internalServerError;
        outln("Internal server error: $e\n$s", Color.error);
        request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten"})));
        await request.response.flush();
        await request.response.close();
      }
    } catch (e, s) {
      request.response.statusCode = HttpStatus.internalServerError;
      outln("Internal server error: $e\n$s", Color.error);
      request.response.add(utf8.encode(json.encode({"message": "Ein interner Serverfehler ist aufgetreten"})));
      await request.response.flush();
      await request.response.close();
    }
  });
}

List<RealtimeConnection> realtimeConnections = [];

class RealtimeConnection {
  Person person;
  WebSocket socket;
  late Stream stream;
  late DateTime created;
  late DateTime lastActive;
  bool controller = false;

  RealtimeConnection(this.person, this.socket) {
    created = DateTime.now();
    lastActive = DateTime.now();
    stream = socket.asBroadcastStream();

    realtimeConnections.add(this);
  }

  void close({bool timeout = false, bool replaced = false, bool kicked = false}) {
    socket.close();
  }

  void send(String event, Map<String, dynamic> data) {
    try {
      socket.addUtf8Text(utf8.encode((jsonEncode({'event': event, 'data': data}))));
    } catch (e, s) {
      outln('Error in Realtime-Server: $e', Color.error);
      outln(s.toString(), Color.error);
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
      outln('Error in Realtime-Server: $e', Color.error);
      return false;
    }
  }
}

Future<Never> startRealtimeWatchThread() async {
  while (true) {
    try {
      await Future.delayed(const Duration(seconds: 3));
      List<RealtimeConnection> removeList = [];
      for (int i = 0; i < realtimeConnections.length; i++) {
        if (!realtimeConnections[i].check()) {
          removeList.add(realtimeConnections[i]);
        }
      }
      for (int i = 0; i < removeList.length; i++) {
        realtimeConnections.remove(removeList[i]);
      }
    } catch (e) {
      outln('Error in Realtime-Server: $e', Color.error);
    }
  }
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

    int personId = int.parse(authParts[0]);
    String key = authParts[1];

    Person? person;
    try {
      person = await Person.getById(personId);
    } catch (e) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.flush();
      await request.response.close();
      return;
    }

    if (person.registrationKey != key) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.flush();
      await request.response.close();
      return;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.bufferOutput = false;
      WebSocket webSocket = await WebSocketTransformer.upgrade(request);
      RealtimeConnection connection = RealtimeConnection(person, webSocket);
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
