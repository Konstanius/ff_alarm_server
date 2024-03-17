import 'dart:io';

import '../server/init.dart';
import '../utils/database.dart';
import '../utils/generic.dart';
import 'alarm.dart';
import 'station.dart';
import 'unit.dart';

class Person {
  int id;
  String firstName;
  String lastName;
  List<int> allowedUnits;
  String qualifications;
  List<String> fcmTokens;
  String registrationKey;
  AlarmResponse response;
  DateTime updated;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.allowedUnits,
    required this.qualifications,
    required this.fcmTokens,
    required this.registrationKey,
    required this.response,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "firstName": "f",
    "lastName": "l",
    "allowedUnits": "au",
    "qualifications": "q",
    "response": "r",
    "updated": "up",
  };

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["firstName"]!: firstName,
      jsonShorts["lastName"]!: lastName,
      jsonShorts["allowedUnits"]!: allowedUnits,
      jsonShorts["qualifications"]!: qualifications,
      jsonShorts["response"]!: response.toJson(),
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }

  factory Person.fromDatabase(Map<String, dynamic> data) {
    return Person(
      id: data["id"],
      firstName: data["firstname"],
      lastName: data["lastname"],
      allowedUnits: data["allowedunits"],
      qualifications: data["qualifications"],
      fcmTokens: data["fcmtokens"],
      registrationKey: data["registrationkey"],
      response: AlarmResponse.fromJson(data["response"]),
      updated: DateTime.fromMillisecondsSinceEpoch(data["updated"]),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "id": id,
      "firstname": firstName,
      "lastname": lastName,
      "allowedunits": allowedUnits,
      "qualifications": qualifications,
      "fcmtokens": fcmTokens,
      "registrationkey": registrationKey,
      "response": response.toJson(),
      "updated": updated.millisecondsSinceEpoch,
    };
  }

  static Future<void> initialize() async {
    var result = await Database.connection.query("SELECT EXISTS ("
        "SELECT FROM information_schema.tables "
        "WHERE table_schema = 'public' "
        "AND table_name = 'persons'"
        ");");

    if (result[0][0] == false) {
      await Database.connection.query("CREATE TABLE persons ("
          "id SERIAL PRIMARY KEY,"
          "firstname TEXT,"
          "lastname TEXT,"
          "allowedunits INTEGER[],"
          "qualifications TEXT,"
          "fcmtokens TEXT[],"
          "registrationkey TEXT,"
          "response JSONB,"
          "updated BIGINT"
          ");");
    }
  }

  static Future<Person> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM persons WHERE id = $id;");
    if (result.isEmpty) {
      throw RequestException(HttpStatus.notFound, "Die Person konnte nicht gefunden werden.");
    }
    return Person.fromDatabase(result[0].toColumnMap());
  }

  static Future<List<Person>> getAll() async {
    var result = await Database.connection.query("SELECT * FROM persons;");
    return result.map((e) => Person.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> insert(Person person) async {
    person.updated = DateTime.now();
    var result = await Database.connection.query(
      "INSERT INTO persons (firstname, lastname, allowedunits, qualifications, fcmtokens, registrationkey, response, updated) @firstname, @lastname, @allowedunits, @qualifications, @fcmtokens, @registrationkey, @response, @updated RETURNING id;",
      substitutionValues: person.toDatabase(),
    );
    person.id = result[0][0];
    Person.broadcastChange(person);
  }

  static Future<void> update(Person person) async {
    person.updated = DateTime.now();
    await Database.connection.query(
      "UPDATE persons SET firstname = @firstname, lastname = @lastname, allowedunits = @allowedunits, qualifications = @qualifications, fcmtokens = @fcmtokens, registrationkey = @registrationkey, response = @response, updated = @updated WHERE id = @id;",
      substitutionValues: person.toDatabase(),
    );
    Person.broadcastChange(person);
  }

  static Future<void> delete(int id) async {
    await Database.connection.query("DELETE FROM persons WHERE id = $id;");
    Person.broadcastDelete(id);
  }

  static Future<List<Person>> getByUnitId(int unitId) async {
    var result = await Database.connection.query("SELECT * FROM persons WHERE $unitId = ANY(allowedunits);");
    return result.map((e) => Person.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<List<Person>> getByStationId(int stationId) async {
    List<Unit> units = await Unit.getByStationId(stationId);
    List<Person> persons = [];
    for (var unit in units) {
      persons.addAll(await getByUnitId(unit.id));
    }
    return persons;
  }

  static Future<Set<int>> personsThatCanSee(int personId) async {
    var stations = await Station.getByPersonId(personId);
    Set<int> canSee = {};
    for (var station in stations) {
      canSee.addAll(station.persons);
    }
    return canSee;
  }

  static Future<void> broadcastChange(Person person) async {
    var involvedPersonIds = await personsThatCanSee(person.id);

    var json = person.toJson();
    for (var connection in realtimeConnections) {
      if (involvedPersonIds.contains(connection.personId)) {
        connection.send("person", json);
      }
    }
  }

  static Future<void> broadcastDelete(int personId) async {
    for (var connection in realtimeConnections) {
      connection.send("person_delete", {"id": personId});
    }
  }
}
