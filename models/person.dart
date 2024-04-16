import 'dart:collection';

import '../interfaces/person_interface.dart';
import '../server/init.dart';
import '../utils/config.dart';
import '../utils/database.dart';
import '../utils/generic.dart';
import 'alarm.dart';
import 'station.dart';
import 'unit.dart';

class Person {
  int id;
  String firstName;
  String lastName;
  DateTime birthday;
  List<int> allowedUnits;
  List<Qualification> qualifications;
  Set<String> fcmTokens;
  String registrationKey;
  Map<int, PersonStaticAlarmResponse> response;
  DateTime updated;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.birthday,
    required this.allowedUnits,
    required this.qualifications,
    required this.fcmTokens,
    required this.registrationKey,
    required this.response,
    required this.updated,
  });

  factory Person.copyFrom(Person person) {
    return Person(
      id: person.id,
      firstName: person.firstName,
      lastName: person.lastName,
      birthday: person.birthday,
      allowedUnits: [...person.allowedUnits],
      qualifications: [...person.qualifications.map((e) => Qualification.copyFrom(e))],
      fcmTokens: {...person.fcmTokens},
      registrationKey: person.registrationKey,
      response: {...person.response.map((key, value) => MapEntry(key, PersonStaticAlarmResponse.copyFrom(value)))},
      updated: person.updated,
    );
  }

  static const Map<String, String> jsonShorts = {
    "server": "s",
    "id": "i",
    "firstName": "f",
    "lastName": "l",
    "birthday": "b",
    "allowedUnits": "au",
    "qualifications": "q",
    "updated": "up",
  };

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["server"]!: Config.config["server"],
      jsonShorts["id"]!: id,
      jsonShorts["firstName"]!: firstName,
      jsonShorts["lastName"]!: lastName,
      jsonShorts["birthday"]!: birthday.millisecondsSinceEpoch,
      jsonShorts["allowedUnits"]!: allowedUnits,
      jsonShorts["qualifications"]!: qualifications.map((e) => e.toString()).toList(),
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }

  factory Person.fromDatabase(Map<String, dynamic> data) {
    return Person(
      id: data["id"],
      firstName: data["firstname"],
      lastName: data["lastname"],
      birthday: DateTime.fromMillisecondsSinceEpoch(data["birthday"]),
      allowedUnits: data["allowedunits"],
      qualifications: () {
        List<Qualification> qualifications = [];
        for (var qualification in data["qualifications"].split(",")) {
          if (qualification.isEmpty) continue;
          try {
            qualifications.add(Qualification.fromString(qualification));
          } catch (_) {}
        }
        return qualifications;
      }(),
      fcmTokens: {...data["fcmtokens"]},
      registrationKey: data["registrationkey"],
      response: PersonStaticAlarmResponse.fromJsonMap(data["response"]),
      updated: DateTime.fromMillisecondsSinceEpoch(data["updated"]),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "id": id,
      "firstname": firstName,
      "lastname": lastName,
      "birthday": birthday.millisecondsSinceEpoch,
      "allowedunits": allowedUnits,
      "qualifications": qualifications.map((e) => e.toString()).join(","),
      "fcmtokens": fcmTokens.toList(),
      "registrationkey": registrationKey,
      "response": PersonStaticAlarmResponse.toJsonMap(response),
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
          "firstname TEXT NOT NULL,"
          "lastname TEXT NOT NULL,"
          "birthday BIGINT NOT NULL,"
          "allowedunits INTEGER[] NOT NULL,"
          "qualifications TEXT NOT NULL,"
          "fcmtokens TEXT[] NOT NULL,"
          "registrationkey TEXT NOT NULL,"
          "response JSONB NOT NULL,"
          "updated BIGINT NOT NULL"
          ");");
    }
  }

  static final HashMap<int, Person> _personsCache = HashMap<int, Person>();
  
  static HashMap<int, Person> get directCacheAccess => _personsCache;

  static Future<List<Person>> populateCache() async {
    var result = await Database.connection.query("SELECT * FROM persons;");
    return result.map((e) => Person.fromDatabase(e.toColumnMap())).toList();
  }

  static Person? getById(int id) {
    Person? person = _personsCache[id];
    if (person == null) return null;
    return Person.copyFrom(person);
  }

  static List<Person> getByIds(List<int> ids) {
    List<Person> persons = [];
    for (var id in ids) {
      Person? person = getById(id);
      if (person != null) persons.add(person);
    }
    return persons;
  }

  static List<Person> getAll() {
    return _personsCache.values.map((e) => Person.copyFrom(e)).toList();
  }

  static Future<void> insert(Person person) async {
    person.updated = DateTime.now();
    var result = await Database.connection.query(
      "INSERT INTO persons (firstname, lastname, birthday, allowedunits, qualifications, fcmtokens, registrationkey, response, updated) @firstname, @lastname, @birthday, @allowedunits, @qualifications, @fcmtokens, @registrationkey, @response, @updated RETURNING id;",
      substitutionValues: person.toDatabase(),
    );
    person.id = result[0][0];
    _personsCache[person.id] = Person.copyFrom(person);
    Person.broadcastChange(person);
  }

  static Future<void> update(Person person) async {
    person.updated = DateTime.now();
    await Database.connection.query(
      "UPDATE persons SET firstname = @firstname, lastname = @lastname, birthday = @birthday, allowedunits = @allowedunits, qualifications = @qualifications, fcmtokens = @fcmtokens, registrationkey = @registrationkey, response = @response, updated = @updated WHERE id = @id;",
      substitutionValues: person.toDatabase(),
    );
    _personsCache[person.id] = Person.copyFrom(person);
    Person.broadcastChange(person);
  }

  static Future<void> delete(int id) async {
    await Database.connection.query("DELETE FROM persons WHERE id = $id;");
    _personsCache.remove(id);
    Person.broadcastDelete(id);
  }

  static List<Person> getByUnitId(int unitId) {
    List<Person> persons = [];
    for (var person in _personsCache.values) {
      if (person.allowedUnits.contains(unitId)) {
        persons.add(Person.copyFrom(person));
      }
    }
    return persons;
  }

  static Future<List<Person>> getByStationId(int stationId) async {
    Station? station = await Station.getById(stationId);
    if (station == null) return [];
    return getByIds(station.persons);
  }

  static Future<Set<int>> personsThatCanSee(int personId) async {
    var stations = await Station.getForPerson(personId);
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
      if (!involvedPersonIds.contains(connection.person.id)) continue;
      connection.send("person", json);
    }
  }

  static Future<void> broadcastDelete(int personId) async {
    for (var connection in realtimeConnections) {
      connection.send("person_delete", {"id": personId});
    }
  }

  AlarmResponse getForAlarm(Alarm alarm, Map<int, Unit> relevantUnits, Map<int, Station> relevantStations) {
    List<Station> stationsOfPerson = [];

    for (var unit in allowedUnits) {
      if (!relevantUnits.containsKey(unit)) continue;
      if (!relevantStations.containsKey(relevantUnits[unit]!.stationId)) continue;
      var station = relevantStations[relevantUnits[unit]!.stationId]!;
      if (!station.persons.contains(id)) continue;
      stationsOfPerson.add(station);
    }

    Map<int, AlarmResponseType> responses = {};
    for (var station in stationsOfPerson) {
      if (!response.containsKey(station.id)) {
        responses[station.id] = AlarmResponseType.notSet;
        continue;
      }
      var responseType = response[station.id]!;
      if (!responseType.shouldNotify(id)) {
        responses[station.id] = AlarmResponseType.notReady;
      } else {
        responses[station.id] = AlarmResponseType.notSet;
      }
    }

    return AlarmResponse(
      note: "",
      time: DateTime.now(),
      responses: responses,
    );
  }
}

class Qualification {
  final String type;
  final DateTime? start;
  final DateTime? end;

  Qualification(this.type, this.start, this.end);

  factory Qualification.copyFrom(Qualification qualification) {
    return Qualification(qualification.type, qualification.start, qualification.end);
  }

  factory Qualification.fromString(String str) {
    var parts = str.split(':');
    String type = parts[0];
    DateTime? start = parts[1] == "0" ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
    DateTime? end = parts[2] == "0" ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2]));
    return Qualification(type, start, end);
  }

  @override
  String toString() {
    return "$type:${start?.millisecondsSinceEpoch ?? 0}:${end?.millisecondsSinceEpoch ?? 0}";
  }
}

class PersonStaticAlarmResponse {
  int stationId;

  /// 0 = off, 1 = none, 2 = always
  int manualOverride;

  /// List of DateTime to DateTime when it is definitely disabled
  List<({DateTime start, DateTime end})> calendar = [];

  /// EITHER Schichtplan OR Geofencing is enabled, not both
  /// 0 = none, 1 = shiftPlan active, 2 = shiftPlan inactive, 3 = geofencing
  int enabledMode;

  /// List of day int, millisecond to millisecond when it is disabled
  List<({int day, int start, int end})> shiftPlan;

  /// List of LatLng to Radius in meters when it is enabled
  List<({double latitude, double longitude, int radius})> geofencing;

  PersonStaticAlarmResponse({
    required this.stationId,
    required this.manualOverride,
    required this.calendar,
    required this.enabledMode,
    required this.shiftPlan,
    required this.geofencing,
  });

  factory PersonStaticAlarmResponse.copyFrom(PersonStaticAlarmResponse response) {
    return PersonStaticAlarmResponse(
      stationId: response.stationId,
      manualOverride: response.manualOverride,
      calendar: [...response.calendar.map((e) => (start: e.start, end: e.end))],
      enabledMode: response.enabledMode,
      shiftPlan: [...response.shiftPlan.map((e) => (day: e.day, start: e.start, end: e.end))],
      geofencing: [...response.geofencing.map((e) => (latitude: e.latitude, longitude: e.longitude, radius: e.radius))],
    );
  }

  factory PersonStaticAlarmResponse.make({
    required int stationId,
    int? manualOverride,
    List<({DateTime start, DateTime end})>? calendar,
    int? enabledMode,
    List<({int day, int start, int end})>? shiftPlan,
    List<({double latitude, double longitude, int radius})>? geofencing,
  }) {
    return PersonStaticAlarmResponse(
      stationId: stationId,
      manualOverride: manualOverride ?? 1,
      calendar: calendar ?? [],
      enabledMode: enabledMode ?? 0,
      shiftPlan: shiftPlan ?? [],
      geofencing: geofencing ?? [],
    );
  }

  bool shouldNotify(int personId) {
    // manualOverride = 0 means everything is disabled
    if (manualOverride == 0) return false;
    // manualOverride = 2 means everything is enabled
    if (manualOverride == 2) return true;

    DateTime now = DateTime.now();
    // if the calendar is not empty, check if we are in a disabled time
    if (calendar.isNotEmpty) {
      for (var item in calendar) {
        if (now.isAfter(item.start) && now.isBefore(item.end)) return false;
      }
    }

    if (enabledMode == 0) return true;

    // if shiftPlan is not empty and enabledMode is 1 or 2
    if ((enabledMode == 1 || enabledMode == 2)) {
      int day = now.weekday;
      int dayMillis = now.hour * 3600000 + now.minute * 60000 + now.second * 1000 + now.millisecond;
      if (enabledMode == 1) {
        for (var item in shiftPlan) {
          if (item.day == day && dayMillis >= item.start && dayMillis <= item.end) return true;
        }

        return false;
      } else if (enabledMode == 2) {
        for (var item in shiftPlan) {
          if (item.day == day && dayMillis >= item.start && dayMillis <= item.end) return false;
        }

        return true;
      }
    }

    if (enabledMode == 3) {
      if (geofencing.isEmpty) return false;
      var position = PersonInterface.globalLocations[personId];
      if (position == null) return true;

      var now = DateTime.now().millisecondsSinceEpoch;
      if (now - position.time > PersonInterface.locationTimeout) return true;

      for (var item in geofencing) {
        try {
          double distance = Utils.distanceBetween(item.latitude, item.longitude, position.lat, position.lon);
          if (distance < item.radius) return true;
        } catch (_) {}
      }

      return false;
    }

    return true;
  }

  static const Map<String, String> jsonShorts = {
    "stationId": "s",
    "manualOverride": "m",
    "calendar": "c",
    "enabledMode": "e",
    "shiftPlan": "sp",
    "geofencing": "g",
  };

  Map<String, dynamic> toJson() {
    DateTime now = DateTime.now();
    calendar.removeWhere((element) => element.end.isBefore(now) || element.end.isBefore(element.start));
    return {
      if (manualOverride != 1) jsonShorts["manualOverride"]!: manualOverride,
      if (calendar.isNotEmpty) jsonShorts["calendar"]!: calendar.map((e) => "${e.start.millisecondsSinceEpoch};${e.end.millisecondsSinceEpoch}").toList(),
      if (enabledMode != 0) jsonShorts["enabledMode"]!: enabledMode,
      if (shiftPlan.isNotEmpty) jsonShorts["shiftPlan"]!: shiftPlan.map((e) => "${e.day};${e.start};${e.end}").toList(),
      if (geofencing.isNotEmpty) jsonShorts["geofencing"]!: geofencing.map((e) => "${e.latitude};${e.longitude};${e.radius}").toList(),
    };
  }

  factory PersonStaticAlarmResponse.fromJson(int stationId, Map<String, dynamic> json) {
    int manualOverride = json[jsonShorts["manualOverride"]] ?? 1;
    if (manualOverride < 0 || manualOverride > 2) manualOverride = 1;

    List<dynamic> calendar = json[jsonShorts["calendar"]] ?? [];
    List<({DateTime start, DateTime end})> calendarList = [];
    DateTime now = DateTime.now();
    for (String item in calendar) {
      try {
        List<String> split = item.split(";");
        DateTime start = DateTime.fromMillisecondsSinceEpoch(int.parse(split[0]));
        DateTime end = DateTime.fromMillisecondsSinceEpoch(int.parse(split[1]));
        if (end.isBefore(start)) continue;
        if (end.isBefore(now)) continue;
        calendarList.add((
          start: start,
          end: end,
        ));
      } catch (_) {}
    }

    int enabledMode = json[jsonShorts["enabledMode"]] ?? 0;
    if (enabledMode < 0 || enabledMode > 3) enabledMode = 0;

    List<dynamic> shiftPlan = json[jsonShorts["shiftPlan"]] ?? [];
    List<({int day, int start, int end})> shiftPlanList = [];
    for (String item in shiftPlan) {
      try {
        List<String> split = item.split(";");
        int day = int.parse(split[0]);
        if (day < 1 || day > 7) continue;

        int start = int.parse(split[1]);
        if (start < 0 || start > 86400000) continue;
        int end = int.parse(split[2]);
        if (end < 0 || end > 86400000) continue;
        if (end < start) continue;
        shiftPlanList.add((
          day: day,
          start: start,
          end: end,
        ));
      } catch (_) {}
    }

    List<dynamic> geofencing = json[jsonShorts["geofencing"]] ?? [];
    List<({double latitude, double longitude, int radius})> geofencingList = [];
    for (String item in geofencing) {
      try {
        List<String> split = item.split(";");
        geofencingList.add((
          latitude: double.parse(split[0]),
          longitude: double.parse(split[1]),
          radius: int.parse(split[2]),
        ));
      } catch (_) {}
    }

    return PersonStaticAlarmResponse(
      stationId: stationId,
      manualOverride: manualOverride,
      calendar: calendarList,
      enabledMode: enabledMode,
      shiftPlan: shiftPlanList,
      geofencing: geofencingList,
    );
  }

  static Map<String, dynamic> toJsonMap(Map<int, PersonStaticAlarmResponse> responses) {
    Map<String, dynamic> json = {};
    responses.forEach((key, value) {
      try {
        json[key.toString()] = value.toJson();
      } catch (_) {}
    });
    return json;
  }

  static Map<int, PersonStaticAlarmResponse> fromJsonMap(Map<String, dynamic> json) {
    Map<int, PersonStaticAlarmResponse> responses = {};
    json.forEach((key, value) {
      try {
        responses[int.parse(key)] = PersonStaticAlarmResponse.fromJson(int.parse(key), value);
      } catch (_) {}
    });
    return responses;
  }
}
