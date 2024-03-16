import 'dart:convert';
import 'dart:io';

import '../utils/database.dart';
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
          "updated BIGINT"
          ");");
    }
  }

  static Future<Alarm> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM alarms WHERE id = $id;");
    if (result.isEmpty) {
      throw "No alarm found with id $id";
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
      "INSERT INTO alarms (type, word, date, number, address, notes, units, updated) VALUES (@type, @word, @date, @number, @address, @notes, @units, @updated);",
      substitutionValues: alarm.toDatabase(),
    );
  }

  static Future<void> update(Alarm alarm) async {
    alarm.updated = DateTime.now();
    await Database.connection.query(
      "UPDATE alarms SET type = @type, word = @word, date = @date, number = @number, address = @address, notes = @notes, units = @units, updated = @updated WHERE id = @id;",
      substitutionValues: alarm.toDatabase(),
    );
  }

  static Future<void> delete(int id) async {
    await Database.connection.query("DELETE FROM alarms WHERE id = $id;");
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
}
