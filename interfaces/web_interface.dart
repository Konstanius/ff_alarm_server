import 'dart:io';

import 'package:dio/dio.dart';

import '../models/alarm.dart';
import '../models/person.dart';
import '../models/station.dart';
import '../models/unit.dart';
import '../server/web_methods.dart';
import '../utils/console.dart';
import 'person_interface.dart';

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

  static Future<void> unitGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var unit = await Unit.getById(id);
    if (unit == null) {
      await callback(HttpStatus.notFound, {"message": "Einheit nicht gefunden."});
      return;
    }

    var station = await Station.getById(unit.stationId);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Zugehörige Station nicht gefunden."});
      return;
    }

    var persons = await Person.getByUnitId(unit.id);

    await callback(HttpStatus.ok, {
      "station": station.toJson(),
      "persons": persons.map((e) => e.toJson()).toList(),
    });
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

  static Future<void> stationGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var station = await Station.getById(id);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Wache nicht gefunden."});
      return;
    }

    var persons = await Person.getByStationId(station.id);

    var units = await Unit.getByStationId(station.id);

    await callback(HttpStatus.ok, {
      "persons": persons.map((e) => e.toJson()).toList(),
      "units": units.map((e) => e.toJson()).toList(),
    });
  }

  static Future<void> stationCreate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    String name = data["name"];
    if (name.isEmpty || name.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Der Name muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    String area = data["area"];
    if (area.isEmpty || area.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Das Gebiet muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    String prefix = data["prefix"];
    if (prefix.isEmpty || prefix.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Der Präfix muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    int stationNumber = data["stationnumber"];

    String address = data["address"];
    if (address.isEmpty || address.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Die Adresse muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    String coordinates = data["coordinates"];
    if (coordinates.isNotEmpty) {
      List<String> parts = coordinates.split(",");
      if (parts.length != 2) {
        await callback(HttpStatus.badRequest, {"message": "Die Koordinaten müssen im Format 'lat,lon' sein."});
        return;
      }

      try {
        double lat = double.parse(parts[0]);
        double lon = double.parse(parts[1]);

        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          await callback(HttpStatus.badRequest, {"message": "Die Koordinaten müssen im Format 'lat,lon' sein."});
          return;
        }

        coordinates = "${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}";
      } catch (e) {
        await callback(HttpStatus.badRequest, {"message": "Die Koordinaten müssen im Format 'lat,lon' sein."});
        return;
      }
    }

    var station = Station(
      name: name,
      area: area,
      prefix: prefix,
      stationNumber: stationNumber,
      address: address,
      coordinates: coordinates,
      adminPersons: [],
      id: 0,
      persons: [],
      updated: DateTime.now(),
    );

    await Station.insert(station);

    await callback(HttpStatus.ok, station.toJson());
  }

  static Future<void> stationUpdate(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    Station? station = await Station.getById(id);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Die Wache konnte nicht gefunden werden."});
      return;
    }

    String name = data["name"];
    if (name.isEmpty || name.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Der Name muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    String area = data["area"];
    if (area.isEmpty || area.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Das Gebiet muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    String prefix = data["prefix"];
    if (prefix.isEmpty || prefix.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Der Präfix muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    int stationNumber = data["stationnumber"];

    String address = data["address"];
    if (address.isEmpty || address.length > 200) {
      await callback(HttpStatus.badRequest, {"message": "Die Adresse muss zwischen 1 und 200 Zeichen lang sein."});
      return;
    }

    String coordinates = data["coordinates"];
    if (coordinates.isNotEmpty) {
      List<String> parts = coordinates.split(",");
      if (parts.length != 2) {
        await callback(HttpStatus.badRequest, {"message": "Die Koordinaten müssen im Format 'lat,lon' sein."});
        return;
      }

      try {
        double lat = double.parse(parts[0]);
        double lon = double.parse(parts[1]);

        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          await callback(HttpStatus.badRequest, {"message": "Die Koordinaten müssen im Format 'lat,lon' sein."});
          return;
        }

        coordinates = "${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}";
      } catch (e) {
        await callback(HttpStatus.badRequest, {"message": "Die Koordinaten müssen im Format 'lat,lon' sein."});
        return;
      }
    }

    station.name = name;
    station.area = area;
    station.prefix = prefix;
    station.stationNumber = stationNumber;
    station.address = address;
    station.coordinates = coordinates;

    await Station.update(station);

    await callback(HttpStatus.ok, {});
  }

  static Future<void> stationDelete(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var station = await Station.getById(id);
    if (station == null) {
      await callback(HttpStatus.notFound, {"message": "Wache nicht gefunden."});
      return;
    }

    var units = await Unit.getByStationId(station.id);
    if (units.isNotEmpty) {
      await callback(HttpStatus.conflict, {"message": "Wache kann nicht gelöscht werden, da dieser noch Einheiten zugeordnet sind."});
      return;
    }

    await Station.deleteById(id);

    await callback(HttpStatus.ok, {});
  }

  static Future<void> personList(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var persons = await Person.getAll();
    await callback(HttpStatus.ok, {"persons": persons.map((e) => e.toJson()).toList()});
  }

  static Future<void> personGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var person = await Person.getById(id);
    if (person == null) {
      await callback(HttpStatus.notFound, {"message": "Person nicht gefunden."});
      return;
    }

    var units = await Unit.getForPerson(person);

    var stations = await Station.getForPerson(person.id);

    await callback(HttpStatus.ok, {
      "units": units.map((e) => e.toJson()).toList(),
      "stations": stations.map((e) => e.toJson()).toList(),
    });
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

  static Future<void> alarmGetDetails(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    int id = data["id"];
    var alarm = await Alarm.getById(id);
    if (alarm == null) {
      await callback(HttpStatus.notFound, {"message": "Alarm nicht gefunden."});
      return;
    }

    var personIds = await alarm.getInvolvedPersonIds();
    var persons = await Person.getByIds(personIds);

    var units = await Unit.getByIds(alarm.units);

    var stations = await Station.getByIds(units.map((e) => e.stationId));

    await callback(HttpStatus.ok, {
      "persons": persons.map((e) => e.toJson()).toList(),
      "units": units.map((e) => e.toJson()).toList(),
      "stations": stations.map((e) => e.toJson()).toList(),
    });
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

  static Future<void> getCoordinates(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    String address = data["address"];

    try {
      String escapedAddress = Uri.encodeComponent(address);
      String url = 'https://nominatim.openstreetmap.org/search?q=$escapedAddress&format=json';
      Dio dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
      Response response = await dio.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        if (data.isNotEmpty) {
          String lat = data[0]['lat'];
          String lon = data[0]['lon'];
          double latD = double.parse(lat);
          double lonD = double.parse(lon);
          await callback(HttpStatus.ok, {"lat": latD, "lon": lonD});
        } else {
          await callback(HttpStatus.notFound, {"message": "Adresse nicht gefunden."});
        }
        return;
      }
      await callback(HttpStatus.internalServerError, {"message": "Fehler beim Abrufen der Koordinaten."});
    } catch (e, s) {
      outln(e.toString(), Color.error);
      outln(s.toString(), Color.error);
      await callback(HttpStatus.internalServerError, {"message": "Fehler beim Abrufen der Koordinaten."});
    }
  }

  static Future<void> getAddress(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    double lat = data["lat"];
    double lon = data["lon"];

    try {
      String url = 'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json';
      Dio dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
      Response response = await dio.get(url);
      if (response.statusCode == 200) {
        Map<String, dynamic> data = response.data;
        if (data.isNotEmpty) {
          String returnData;
          try {
            String road = data['address']['road']!;
            String houseNumber = data['address']['house_number'] ?? '';
            String postcode = data['address']['postcode']!;
            String city = data['address']['city']!;

            String address = '$road $houseNumber, $postcode $city';
            // replace multiple spaces with one
            address = address.replaceAll(RegExp(r'\s+'), ' ');
            // remove leading and trailing spaces
            address = address.trim();
            // replace ' , ' with ', '
            address = address.replaceAll(RegExp(r'\s,\s'), ', ');

            returnData = address;
          } catch (e) {
            returnData = data['display_name'] ?? '';
          }
          await callback(HttpStatus.ok, {"address": returnData});
        } else {
          await callback(HttpStatus.notFound, {"message": "Adresse nicht gefunden."});
        }
        return;
      }

      await callback(HttpStatus.internalServerError, {"message": "Fehler beim Abrufen der Adresse."});
    } catch (e, s) {
      outln(e.toString(), Color.error);
      outln(s.toString(), Color.error);
      await callback(HttpStatus.internalServerError, {"message": "Fehler beim Abrufen der Adresse."});
    }
  }

  static Future<void> getReadiness(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
    var persons = await Person.getAll();

    List<AdminReadinessEntry> readiness = [];
    for (var person in persons) {
      readiness.add(AdminReadinessEntry.fromPerson(person));
    }

    await callback(HttpStatus.ok, {"readiness": readiness.map((e) => e.toString()).toList()});
  }
}

class AdminReadinessEntry {
  int personId;
  double? lat;
  double? lon;
  int? timestamp;
  int amountStationsReady;

  AdminReadinessEntry({required this.personId, this.lat, this.lon, this.timestamp, required this.amountStationsReady});

  factory AdminReadinessEntry.fromPerson(Person person) {
    int amountStationsReady = 0;
    for (var response in person.response.values) {
      if (response.shouldNotify(person.id)) {
        amountStationsReady++;
      }
    }

    double? lat;
    double? lon;
    int? timestamp;
    if (PersonInterface.globalLocations.containsKey(person.id)) {
      lat = PersonInterface.globalLocations[person.id]!.lat;
      lon = PersonInterface.globalLocations[person.id]!.lon;
      timestamp = PersonInterface.globalLocations[person.id]!.time;
    }

    return AdminReadinessEntry(
      personId: person.id,
      amountStationsReady: amountStationsReady,
      lat: lat,
      lon: lon,
      timestamp: timestamp,
    );
  }

  @override
  String toString() {
    String lat;
    if (this.lat == null) {
      lat = "0";
    } else {
      lat = this.lat!.toStringAsFixed(5);
    }

    String lon;
    if (this.lon == null) {
      lon = "0";
    } else {
      lon = this.lon!.toStringAsFixed(5);
    }

    return "$personId:$amountStationsReady:$lat:$lon:${timestamp ?? 0}";
  }
}
