import 'dart:convert';
import 'dart:io';

import '../firebase/fcm_service.dart';
import '../models/person.dart';
import '../models/station.dart';
import '../models/unit.dart';
import '../utils/config.dart';
import '../utils/console.dart';
import '../utils/generic.dart';

abstract class PersonInterface {
  static Future<void> getAll(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    Map<int, DateTime> updates = {};

    var split = data["data"].split(",");
    for (var entry in split) {
      if (entry.isEmpty) continue;
      var splitDate = entry.split(":");
      updates[int.parse(splitDate[0])] = DateTime.fromMillisecondsSinceEpoch(int.parse(splitDate[1]));
    }

    var userStations = await Station.getForPerson(person.id);
    Set<int> stationPersons = {};
    for (var station in userStations) {
      stationPersons.addAll(station.persons);
    }

    List<Person> persons = await Person.getByIds(stationPersons.toList());
    List<Map<String, dynamic>> response = [];
    Set<int> canSee = {person.id};

    for (Person person in persons) {
      canSee.add(person.id);
      if (updates.containsKey(person.id) && updates[person.id]!.millisecondsSinceEpoch == person.updated.millisecondsSinceEpoch) continue;
      response.add(person.toJson());
    }

    var deleted = <int>[];
    for (var entry in updates.entries) {
      if (!canSee.contains(entry.key)) {
        deleted.add(entry.key);
      }
    }

    if (response.isEmpty && deleted.isEmpty) {
      await callback(HttpStatus.ok, {});
      return;
    }

    await callback(HttpStatus.ok, {"updated": response, "deleted": deleted});
  }

  static Future<void> setResponse(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var responses = PersonStaticAlarmResponse.fromJsonMap(data);

    var allStations = await Station.getForPerson(person.id);
    Set<int> allStationIds = allStations.map((e) => e.id).toSet();
    responses.removeWhere((key, value) => !allStationIds.contains(key));

    // limit calendar, schedule and geofences to 100 entries
    for (var entry in responses.entries) {
      if (entry.value.calendar.length > 100) {
        entry.value.calendar = entry.value.calendar.sublist(0, 100);
      }
      if (entry.value.shiftPlan.length > 100) {
        entry.value.shiftPlan = entry.value.shiftPlan.sublist(0, 100);
      }
      if (entry.value.geofencing.length > 100) {
        entry.value.geofencing = entry.value.geofencing.sublist(0, 100);
      }
    }

    var personCopy = await Person.getById(person.id);
    personCopy!.response = responses;
    await Person.update(personCopy);

    await callback(HttpStatus.ok, {});
  }

  static Map<int, ({double lat, double lon, int time})> globalLocations = {};
  static const int locationTimeout = 1200000;

  static Future<void> setLocation(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    double lat = data["a"];
    double lon = data["o"];
    int time = data["t"];

    outln("Setting location for ${person.id} to $lat, $lon at $time", Color.verbose);

    var last = globalLocations[person.id];
    if (last != null && last.time > time) {
      callback(HttpStatus.ok, {});
      return;
    }

    globalLocations[person.id] = (lat: lat, lon: lon, time: time);

    callback(HttpStatus.ok, {});
  }

  static Future<void> create(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int stationId = data["stationId"];

    Station? station = await Station.getById(stationId);
    if (station == null) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    if (!station.adminPersons.contains(person.id)) {
      await callback(HttpStatus.forbidden, {"message": "Du bist nicht berechtigt, auf diese Wache zuzugreifen."});
      return;
    }

    String firstName = data["firstName"].trim();
    String lastName = data["lastName"].trim();
    DateTime birthday = DateTime.fromMillisecondsSinceEpoch(data["birthday"]);
    List<dynamic> allowedUnits = data["allowedUnits"];
    List<dynamic> qualifications = data["qualifications"];

    if (firstName.isEmpty || lastName.isEmpty) {
      await callback(HttpStatus.badRequest, {"message": "Vor- und Nachname dürfen nicht leer sein."});
      return;
    }

    // limit to 100 chars each
    if (firstName.length > 100 || lastName.length > 100) {
      await callback(HttpStatus.badRequest, {"message": "Vor- und Nachname dürfen nicht länger als je 100 Zeichen sein."});
      return;
    }

    if (birthday.isAfter(DateTime.now())) {
      await callback(HttpStatus.badRequest, {"message": "Geburtstag darf nicht in der Zukunft liegen."});
      return;
    }

    List<Qualification> qs = [];
    Set<String> qSet = {};
    for (String q in qualifications) {
      String withoutLeadingUnderscore = q.startsWith("_") ? q.substring(1) : q;
      if (qSet.contains(withoutLeadingUnderscore)) {
        await callback(HttpStatus.badRequest, {"message": "Qualifikationen dürfen nicht doppelt vorkommen."});
        return;
      }
      qs.add(Qualification.fromString(q));
      qSet.add(withoutLeadingUnderscore);
    }

    var stationUnits = await Unit.getByStationId(stationId);
    Set<int> stationUnitIds = {};
    for (var unit in stationUnits) {
      if (!allowedUnits.contains(unit.id)) continue;
      stationUnitIds.add(unit.id);
    }

    String key = HashUtils.generateRandomKey();
    String hash = await HashUtils.generateHash(key);

    DateTime now = DateTime.now();
    DateTime expires = now.add(const Duration(days: 1));

    Person newPerson = Person(
      id: 0,
      firstName: firstName,
      lastName: lastName,
      birthday: birthday,
      allowedUnits: stationUnitIds.toList(),
      qualifications: qs,
      fcmTokens: [],
      registrationKey: '$hash:${expires.millisecondsSinceEpoch}',
      response: {},
      updated: DateTime.now(),
    );

    await Person.insert(newPerson);

    station.persons.add(newPerson.id);
    await Station.update(station);

    Map<String, dynamic> keyData = {
      "d": Config.config["server"],
      "a": key,
      "p": person.id,
    };

    String jsonString = jsonEncode(keyData);
    final enCodedJson = utf8.encode(jsonString);
    final gZipJson = gzip.encode(enCodedJson);
    String base64String = base64.encode(gZipJson);

    await callback(HttpStatus.ok, {"key": base64String, "id": newPerson.id});
  }

  static Future<void> ping(Person person, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    String fcmToken = data["fcmToken"];
    String platform = data["platform"];
    bool isAndroid = platform == "A";

    await invokeSDK(
      false,
      'fcmTest',
      {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'server': Config.config['server'],
      },
      androidTokens: isAndroid ? {fcmToken} : {},
      iosTokens: isAndroid ? {} : {fcmToken},
    );

    await callback(HttpStatus.ok, {});
  }
}
