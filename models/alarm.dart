import 'dart:convert';
import 'dart:io';

import '../server/init.dart';
import '../utils/database.dart';
import '../utils/generic.dart';
import 'person.dart';
import 'station.dart';
import 'unit.dart';

class Alarm {
  final int id;
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
    this.responses = const {},
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
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
          responses[int.parse(key)] = AlarmResponse.fromJson(value);
        });
        return responses;
      }(),
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
          responses[int.parse(key)] = AlarmResponse.fromJson(value);
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
          "type TEXT,"
          "word TEXT,"
          "date BIGINT,"
          "number INTEGER,"
          "address TEXT,"
          "notes TEXT[],"
          "units INTEGER[],"
          "responses JSONB,"
          "updated BIGINT"
          ");");
    }
  }

  static Future<Alarm> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM alarms WHERE id = $id;");
    if (result.isEmpty) {
      throw RequestException(HttpStatus.notFound, "Die Alarmierung konnte nicht gefunden werden.");
    }
    return Alarm.fromDatabase(result[0].toColumnMap());
  }

  static Future<List<Alarm>> getAll() async {
    var result = await Database.connection.query("SELECT * FROM alarms;");
    return result.map((e) => Alarm.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> insert(Alarm alarm) async {
    alarm.updated = DateTime.now();
    await Database.connection.query(
      "INSERT INTO alarms (type, word, date, number, address, notes, units, responses, updated) VALUES (@type, @word, @date, @number, @address, @notes, @units, @responses, @updated);",
      substitutionValues: alarm.toDatabase(),
    );
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
    if (responses.containsKey(person.id)) return true;
    if (date.isBefore(DateTime.now().subtract(const Duration(days: 90)))) return false;

    var involvedUnits = await getUnits();
    var involvedStationIds = involvedUnits.map((e) => e.stationId).toSet();

    var stations = await Station.getByIds(involvedStationIds);
    for (var station in stations) {
      if (station.persons.contains(person.id)) return true;
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
    for (var connection in realtimeConnections) {
      if (involvedPersonIds.contains(connection.personId)) {
        connection.send("alarm", json);
      }
    }
  }

  static Future<void> broadcastDelete(int alarmId) async {
    for (var connection in realtimeConnections) {
      connection.send("alarm_delete", {"id": alarmId});
    }
  }
}

class AlarmResponse {
  String? note;
  DateTime? time;
  int? duration;
  int? stationId;

  AlarmResponse({this.note, this.time, this.duration, this.stationId});

  factory AlarmResponse.fromJson(Map<String, dynamic> json) {
    return AlarmResponse(
      note: json['n'],
      time: json['t'] != null ? DateTime.fromMillisecondsSinceEpoch(json['t']) : null,
      duration: json['d'],
      stationId: json['s'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': note,
      't': time?.millisecondsSinceEpoch,
      'd': duration,
      's': stationId,
    };
  }
}
