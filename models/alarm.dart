import 'dart:convert';
import 'dart:io';

import 'package:postgres/src/execution_context.dart';

import '../firebase/fcm_service.dart';
import '../server/app_realtime.dart';
import '../utils/config.dart';
import '../utils/database.dart';
import 'person.dart';
import 'station.dart';
import 'unit.dart';

class Alarm {
  int id;
  String type;
  String word;
  DateTime date;
  int number;
  String address;
  List<String> notes;
  List<int> units;
  Map<int, AlarmResponse> responses;
  DateTime updated;

  Alarm({
    required this.id,
    required this.type,
    required this.word,
    required this.date,
    required this.number,
    required this.address,
    required this.notes,
    required this.units,
    required this.responses,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "server": "s",
    "id": "i",
    "type": "t",
    "word": "w",
    "date": "d",
    "number": "n",
    "address": "a",
    "notes": "no",
    "units": "u",
    "responses": "r",
    "updated": "up",
  };

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json[jsonShorts["id"]],
      type: json[jsonShorts["type"]],
      word: json[jsonShorts["word"]],
      date: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["date"]]),
      number: json[jsonShorts["number"]],
      address: json[jsonShorts["address"]],
      notes: List<String>.from(json[jsonShorts["notes"]]),
      units: List<int>.from(json[jsonShorts["units"]]),
      responses: () {
        Map<int, AlarmResponse> responses = {};
        json[jsonShorts["responses"]].forEach((key, value) {
          var alarmResponse = AlarmResponse.fromJson(value);
          responses[int.parse(key)] = alarmResponse;
        });
        return responses;
      }(),
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["server"]!: Config.config["server"],
      jsonShorts["id"]!: id,
      jsonShorts["type"]!: type,
      jsonShorts["word"]!: word,
      jsonShorts["date"]!: date.millisecondsSinceEpoch,
      jsonShorts["number"]!: number,
      jsonShorts["address"]!: address,
      jsonShorts["notes"]!: notes,
      jsonShorts["units"]!: units,
      jsonShorts["responses"]!: responses.map((key, value) => MapEntry(key.toString(), value.toJson())),
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }

  String deflateToString() {
    Map<String, dynamic> json = toJson();
    // empty notes, responses, updated to 0 - This is done to reduce the size of the string to fit within the 4KB limit of FCM
    json["notes"] = [];
    json["responses"] = {};
    json["updated"] = 0;
    String jsonString = jsonEncode(json);
    final enCodedJson = utf8.encode(jsonString);
    final gZipJson = gzip.encode(enCodedJson);
    return base64.encode(gZipJson);
  }

  factory Alarm.fromDatabase(Map<String, dynamic> data) {
    return Alarm(
      id: data["id"],
      type: data["type"],
      word: data["word"],
      date: DateTime.fromMillisecondsSinceEpoch(data["date"]),
      number: data["number"],
      address: data["address"],
      notes: data["notes"],
      units: data["units"],
      responses: () {
        Map<int, AlarmResponse> responses = {};
        data["responses"].forEach((key, value) {
          var alarmResponse = AlarmResponse.fromJson(value);
          responses[int.parse(key)] = alarmResponse;
        });
        return responses;
      }(),
      updated: DateTime.fromMillisecondsSinceEpoch(data["updated"]),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "id": id,
      "type": type,
      "word": word,
      "date": date.millisecondsSinceEpoch,
      "number": number,
      "address": address,
      "notes": notes,
      "units": units,
      "responses": responses.map((key, value) => MapEntry(key.toString(), value.toJson())),
      "updated": updated.millisecondsSinceEpoch,
    };
  }

  static Future<void> initialize() async {
    var result = await Database.connection.query("SELECT EXISTS ("
        "SELECT FROM information_schema.tables "
        "WHERE table_schema = 'public' "
        "AND table_name = 'alarms'"
        ");");

    if (result[0][0] == false) {
      await Database.connection.query("CREATE TABLE alarms ("
          "id SERIAL PRIMARY KEY,"
          "type TEXT NOT NULL,"
          "word TEXT NOT NULL,"
          "date BIGINT NOT NULL,"
          "number INTEGER NOT NULL,"
          "address TEXT NOT NULL,"
          "notes TEXT[] NOT NULL,"
          "units INTEGER[] NOT NULL,"
          "responses JSONB NOT NULL,"
          "updated BIGINT NOT NULL"
          ");");
    }
  }

  static Future<Alarm?> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM alarms WHERE id = $id;");
    if (result.isEmpty) return null;
    return Alarm.fromDatabase(result[0].toColumnMap());
  }

  static Future<List<Alarm>> getAll({DateTime? oldest}) async {
    PostgreSQLResult result;
    if (oldest != null) {
      result = await Database.connection.query("SELECT * FROM alarms WHERE date > ${oldest.millisecondsSinceEpoch};");
    } else {
      result = await Database.connection.query("SELECT * FROM alarms;");
    }
    return result.map((e) => Alarm.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> insert(Alarm alarm) async {
    alarm.updated = DateTime.now();
    var result = await Database.connection.query(
      "INSERT INTO alarms (type, word, date, number, address, notes, units, responses, updated) VALUES (@type, @word, @date, @number, @address, @notes, @units, @responses, @updated) RETURNING id;",
      substitutionValues: alarm.toDatabase(),
    );
    alarm.id = result[0][0] as int;
    Alarm.broadcastChange(alarm);
  }

  static Future<void> update(Alarm alarm) async {
    alarm.updated = DateTime.now();
    await Database.connection.query(
      "UPDATE alarms SET type = @type, word = @word, date = @date, number = @number, address = @address, notes = @notes, units = @units, responses = @responses, updated = @updated WHERE id = @id;",
      substitutionValues: alarm.toDatabase(),
    );
    Alarm.broadcastChange(alarm);
  }

  static Future<void> delete(int id) async {
    await Database.connection.query("DELETE FROM alarms WHERE id = $id;");
    Alarm.broadcastDelete(id);
  }

  static Future<List<Alarm>> getForUnit(int unitId) async {
    var result = await Database.connection.query("SELECT * FROM alarms WHERE $unitId = ANY(units);");
    return result.map((e) => Alarm.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<List<Alarm>> getForStation(int stationId) async {
    List<Unit> units = await Unit.getByStationId(stationId);
    List<Alarm> alarms = [];
    for (var unit in units) {
      alarms.addAll(await getForUnit(unit.id));
    }
    return alarms;
  }

  Future<List<Unit>> getUnits() async {
    return Unit.getByIds(units);
  }

  Future<bool> canSee(Person person) async {
    if (units.isEmpty) return true;
    if (responses.containsKey(person.id)) return true;
    if (date.isBefore(DateTime.now().subtract(const Duration(days: 90)))) return false;

    for (var unit in units) {
      if (person.allowedUnits.contains(unit)) return true;
    }

    return false;
  }

  Future<Set<int>> getInvolvedPersonIds() async {
    var result = await Database.connection.query(
      "SELECT id FROM persons WHERE @units && allowedunits;",
      substitutionValues: {"units": units},
    );
    return result.map((e) => e[0] as int).toSet();
  }

  static Future<void> broadcastChange(Alarm alarm) async {
    var involvedPersonIds = await alarm.getInvolvedPersonIds();

    var json = alarm.toJson();
    for (var connection in AppRealtimeConnection.connections) {
      if (!involvedPersonIds.contains(connection.person.id)) continue;
      connection.send("alarm", json);
    }
  }

  static Future<void> broadcastDelete(int alarmId) async {
    for (var connection in AppRealtimeConnection.connections) {
      connection.send("alarm_delete", {"id": alarmId});
    }
  }

  Future<void> sendFCMInformation() async {
    var involvedPersonIds = await getInvolvedPersonIds();
    var persons = await Person.getByIds(involvedPersonIds);

    var units = await getUnits();
    Map<int, Unit> unitMap = {};
    for (var unit in units) {
      unitMap[unit.id] = unit;
    }

    var stations = await Station.getByIds(units.map((e) => e.stationId));
    Map<int, Station> stationMap = {};
    for (var station in stations) {
      stationMap[station.id] = station;
    }

    for (var person in persons) {
      responses[person.id] = person.getForAlarm(this, unitMap, stationMap);
    }

    await update(this);

    Set<String> androidTokens = {};
    Set<String> iosTokens = {};
    for (var person in persons) {
      for (String token in person.fcmTokens) {
        if (token.startsWith("A")) {
          androidTokens.add(token.substring(1));
        } else if (token.startsWith("I")) {
          iosTokens.add(token.substring(1));
        } else {
          // Should not happen, optionally for alternative platforms / future use
        }
      }
    }

    String deflated = deflateToString();

    await invokeSDK(
      false,
      "alarm",
      {"alarm": deflated},
      androidTokens: androidTokens,
      iosTokens: iosTokens,
    );
  }
}

/// Each responder gives a single response to each alarm
class AlarmResponse {
  /// The note left to be visible for other responders of the station they are not "Not going" to
  /// If the response is "Not going" to all stations, the note is visible to all responders
  String note;

  /// The time at which the response was given
  DateTime time;

  /// The type of response given, for each station
  Map<int, AlarmResponseType> responses;

  AlarmResponse({
    required this.note,
    required this.time,
    required this.responses,
  });

  static const Map<String, String> jsonShorts = {
    "note": "n",
    "time": "t",
    "responses": "r",
  };

  factory AlarmResponse.fromJson(Map<String, dynamic> json) {
    return AlarmResponse(
      note: json[jsonShorts["note"]],
      time: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["time"]]),
      responses: () {
        Map<int, AlarmResponseType> responses = {};
        json[jsonShorts["responses"]].forEach((key, value) {
          responses[int.parse(key)] = AlarmResponseType.values[value];
        });
        return responses;
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["note"]!: note,
      jsonShorts["time"]!: time.millisecondsSinceEpoch,
      jsonShorts["responses"]!: responses.map((key, value) => MapEntry(key.toString(), value.index)),
    };
  }
}

enum AlarmResponseType {
  onStation(0),
  under5(5),
  under10(10),
  under15(15),
  onCall(-1),
  notReady(-2),
  notSet(-3);

  final int timeAmount;

  const AlarmResponseType(this.timeAmount);
}
