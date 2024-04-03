import 'dart:io';

import '../models/backend/session.dart';
import '../models/person.dart';
import '../utils/generic.dart';

abstract class GuestInterface {
  static Future<void> login(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int personId = data["person"];
    String key = data["key"];
    String userAgent = data["userAgent"];

    Person? person = await Person.getById(personId);
    if (person == null) {
      await callback(HttpStatus.notFound, {"message": "Person nicht gefunden"});
      return;
    }

    List<String> keyInfo = person.registrationKey.split(":");
    if (keyInfo.length != 2) {
      await callback(HttpStatus.forbidden, {"message": "Ungültiger Registrierungsschlüssel"});
      return;
    }

    DateTime keyExpires = DateTime.fromMillisecondsSinceEpoch(int.parse(keyInfo[1]));
    if (keyExpires.isBefore(DateTime.now())) {
      await callback(HttpStatus.forbidden, {"message": "Registrierungsschlüssel abgelaufen"});
      return;
    }

    bool matches = await HashUtils.compareHash(key, keyInfo[0]);
    if (!matches) {
      await callback(HttpStatus.forbidden, {"message": "Ungültiger Registrierungsschlüssel"});
      return;
    }

    String token = HashUtils.generateRandomKey();

    Session session = Session(
      id: 0,
      personId: personId,
      tokenHash: HashUtils.lightHash(token),
      userAgent: userAgent,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 28)),
    );
    await Session.insert(session);

    person.registrationKey = "";
    await Person.update(person);

    await callback(HttpStatus.ok, {
      "token": token,
      "sessionId": session.id,
      "person": person.toJson(),
    });
  }
}
