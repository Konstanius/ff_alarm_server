import 'dart:convert';
import 'dart:io';

import '../models/person.dart';
import '../utils/console.dart';
import 'auth_method.dart';

Future<void> initServer() async {
  HttpServer server = await HttpServer.bind('0.0.0.0', 3000);

  server.listen((HttpRequest request) async {
    try {
      Uri uri = request.uri;
      if (uri.pathSegments.length < 2) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.flush();
        await request.response.close();
        return;
      }

      if (uri.pathSegments[0] != 'api') {
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

      Future<void> callback(int statusCode, Map<String, dynamic> response) async {
        request.response.statusCode = statusCode;
        List<int> data = utf8.encode(json.encode(response));
        request.response.contentLength = data.length;
        request.response.add(data);
        await request.response.flush();
        await request.response.close();
      }

      if (request.headers.value('authorization') == null) {
        // TODO allow guest keywords here

        Map<String, dynamic>? data;
        try {
          String boundRequest = await utf8.decoder.bind(request).join();
          data = json.decode(boundRequest);
        } catch (e) {
          await callback(HttpStatus.badRequest, {"error": "bad_request", "message": "Die Anfrage konnte nicht verarbeitet werden"});
          return;
        }

        await callback(HttpStatus.unauthorized, {"error": "unauthorized", "message": "Kein Zugriff auf diese Resource"});
        print('No authorization header');
        return;
      }

      String? rawAuth = request.headers.value('authorization');
      if (rawAuth == null) {
        await callback(HttpStatus.unauthorized, {"error": "unauthorized", "message": "Kein Zugriff auf diese Resource"});
        print('No rawAuth');
        return;
      }

      String decodedAuth = utf8.decode(gzip.decode(base64.decode(rawAuth)));
      if (!decodedAuth.contains(':')) {
        await callback(HttpStatus.unauthorized, {"error": "unauthorized", "message": "Kein Zugriff auf diese Resource"});
        print('No colon in decodedAuth: $decodedAuth');
        return;
      }

      List<String> authParts = decodedAuth.split(':');
      int personId = int.parse(authParts[0]);
      String key = authParts[1];

      Person? person;
      try {
        person = await Person.getById(personId);
      } catch (e) {
        await callback(HttpStatus.internalServerError, {"error": "unauthorized", "message": "Kein Zugriff auf diese Resource"});
        print('Error getting person by ID: $e');
        return;
      }

      if (person.registrationKey != key) {
        await callback(HttpStatus.unauthorized, {"error": "unauthorized", "message": "Kein Zugriff auf diese Resource"});
        print('Registration key does not match');
        return;
      }

      AuthMethod authMethod = AuthMethod.fromName(keyword);
      if (authMethod == AuthMethod.none) {
        await callback(HttpStatus.notFound, {"error": "not_found", "message": "Die angeforderte Resource wurde nicht gefunden"});
        print('No auth method found for keyword: $keyword');
        return;
      }

      Map<String, dynamic>? data;
      try {
        String boundRequest = await utf8.decoder.bind(request).join();
        data = json.decode(boundRequest);
      } catch (e) {
        await callback(HttpStatus.badRequest, {"error": "bad_request", "message": "Die Anfrage konnte nicht verarbeitet werden"});
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

      await authMethod.handle(person, data!, callback);
    } catch (e, s) {
      request.response.statusCode = HttpStatus.internalServerError;
      outln("Internal server error: $e\n$s", Color.error);
      request.response.add(utf8.encode(json.encode({"error": "internal_server_error", "message": "Ein interner Serverfehler ist aufgetreten"})));
      await request.response.flush();
      await request.response.close();
    }
  });
}
