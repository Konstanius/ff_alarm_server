import '../utils/database.dart';

class Station {
  final int id;
  String area;
  String prefix;
  int stationNumber;
  String address;
  String coordinates;
  List<int> units;
  List<int> persons;
  List<int> adminPersons;
  DateTime updated;

  Station({
    required this.id,
    required this.area,
    required this.prefix,
    required this.stationNumber,
    required this.address,
    required this.coordinates,
    required this.units,
    required this.persons,
    required this.adminPersons,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "area": "a",
    "prefix": "p",
    "stationNumber": "s",
    "address": "ad",
    "coordinates": "c",
    "units": "u",
    "persons": "pe",
    "adminPersons": "ap",
    "updated": "up",
  };

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json[jsonShorts["id"]],
      area: json[jsonShorts["area"]],
      prefix: json[jsonShorts["prefix"]],
      stationNumber: json[jsonShorts["stationNumber"]],
      address: json[jsonShorts["address"]],
      coordinates: json[jsonShorts["coordinates"]],
      units: List<int>.from(json[jsonShorts["units"]]),
      persons: List<int>.from(json[jsonShorts["persons"]]),
      adminPersons: List<int>.from(json[jsonShorts["adminPersons"]]),
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["area"]!: area,
      jsonShorts["prefix"]!: prefix,
      jsonShorts["stationNumber"]!: stationNumber,
      jsonShorts["address"]!: address,
      jsonShorts["coordinates"]!: coordinates,
      jsonShorts["units"]!: units,
      jsonShorts["persons"]!: persons,
      jsonShorts["adminPersons"]!: adminPersons,
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }

  factory Station.fromDatabase(Map<String, dynamic> data) {
    return Station(
      id: data["id"],
      area: data["area"],
      prefix: data["prefix"],
      stationNumber: data["stationmumber"],
      address: data["address"],
      coordinates: data["coordinates"],
      units: List<int>.from(data["units"]),
      persons: List<int>.from(data["persons"]),
      adminPersons: List<int>.from(data["adminpersons"]),
      updated: DateTime.fromMillisecondsSinceEpoch(data["updated"]),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "area": area,
      "prefix": prefix,
      "stationnumber": stationNumber,
      "address": address,
      "coordinates": coordinates,
      "units": units,
      "persons": persons,
      "adminpersons": adminPersons,
      "updated": updated.millisecondsSinceEpoch,
    };
  }

  static Future<void> initialize() async {
    var result = await Database.connection.query("SELECT EXISTS ("
        "SELECT FROM information_schema.tables "
        "WHERE table_schema = 'public' "
        "AND table_name = 'stations'"
        ");");

    if (result[0][0] == false) {
      await Database.connection.execute("CREATE TABLE stations ("
          "id SERIAL PRIMARY KEY,"
          "area TEXT NOT NULL,"
          "prefix TEXT NOT NULL,"
          "stationnumber INT NOT NULL,"
          "address TEXT NOT NULL,"
          "coordinates TEXT NOT NULL,"
          "units INT[] NOT NULL,"
          "persons INT[] NOT NULL,"
          "adminpersons INT[] NOT NULL,"
          "updated BIGINT NOT NULL"
          ");");
    }
  }

  static Future<Station> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM stations WHERE id = @id;", substitutionValues: {"id": id});
    if (result.isEmpty) {
      throw Exception("Station not found");
    }
    return Station.fromDatabase(result[0].toColumnMap());
  }

  static Future<List<Station>> getAll() async {
    var result = await Database.connection.query("SELECT * FROM stations;");
    return result.map((e) => Station.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> insert(Station station) async {
    station.updated = DateTime.now();
    await Database.connection.query(
      "INSERT INTO stations (area, prefix, stationnumber, address, coordinates, units, persons, adminpersons, updated) VALUES (@area, @prefix, @stationnumber, @address, @coordinates, @units, @persons, @adminpersons, @updated);",
      substitutionValues: station.toDatabase(),
    );
  }

  static Future<void> update(Station station) async {
    station.updated = DateTime.now();
    await Database.connection.query(
      "UPDATE stations SET area = @area, prefix = @prefix, stationnumber = @stationnumber, address = @address, coordinates = @coordinates, units = @units, persons = @persons, adminpersons = @adminpersons, updated = @updated WHERE id = @id;",
      substitutionValues: station.toDatabase(),
    );
  }

  static Future<void> deleteById(int id) async {
    await Database.connection.query("DELETE FROM stations WHERE id = @id;", substitutionValues: {"id": id});
  }
}
