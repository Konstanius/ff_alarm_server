import '../utils/database.dart';

class Unit {
  final int id;
  int stationId;
  int unitType;
  int unitIdentifier;
  String unitDescription;
  int status;
  List<UnitPosition> positions;
  int capacity;
  DateTime updated;

  Unit({
    required this.id,
    required this.stationId,
    required this.unitType,
    required this.unitIdentifier,
    required this.unitDescription,
    required this.status,
    required this.positions,
    required this.capacity,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "id": "i",
    "stationId": "si",
    "unitType": "ut",
    "unitIdentifier": "ui",
    "unitDescription": "ud",
    "status": "st",
    "positions": "po",
    "capacity": "ca",
    "updated": "up",
  };

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json[jsonShorts["id"]],
      stationId: json[jsonShorts["stationId"]],
      unitType: json[jsonShorts["unitType"]],
      unitIdentifier: json[jsonShorts["unitIdentifier"]],
      unitDescription: json[jsonShorts["unitDescription"]],
      status: json[jsonShorts["status"]],
      positions: json[jsonShorts["positions"]].map((e) => UnitPosition.values[e]).toList(),
      capacity: json[jsonShorts["capacity"]],
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["id"]!: id,
      jsonShorts["stationId"]!: stationId,
      jsonShorts["unitType"]!: unitType,
      jsonShorts["unitIdentifier"]!: unitIdentifier,
      jsonShorts["unitDescription"]!: unitDescription,
      jsonShorts["status"]!: status,
      jsonShorts["positions"]!: positions.map((e) => e.index).toList(),
      jsonShorts["capacity"]!: capacity,
      jsonShorts["updated"]!: updated.millisecondsSinceEpoch,
    };
  }

  factory Unit.fromDatabase(Map<String, dynamic> data) {
    return Unit(
      id: data["id"],
      stationId: data["stationid"],
      unitType: data["unittype"],
      unitIdentifier: data["unitidentifier"],
      unitDescription: data["unitdescription"],
      status: data["status"],
      positions: data["positions"].map((e) => UnitPosition.values[e]).toList(),
      capacity: data["capacity"],
      updated: DateTime.fromMillisecondsSinceEpoch(data["updated"]),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "id": id,
      "stationid": stationId,
      "unittype": unitType,
      "unitidentifier": unitIdentifier,
      "unitdescription": unitDescription,
      "status": status,
      "positions": positions.map((e) => e.index).toList(),
      "capacity": capacity,
      "updated": updated.millisecondsSinceEpoch,
    };
  }

  static Future<void> initialize() async {
    var result = await Database.connection.query("SELECT EXISTS ("
        "SELECT FROM information_schema.tables "
        "WHERE table_schema = 'public' "
        "AND table_name = 'units'"
        ");");

    if (result[0][0] == false) {
      await Database.connection.query("CREATE TABLE units ("
          "id SERIAL PRIMARY KEY,"
          "stationid INTEGER,"
          "unittype INTEGER,"
          "unitidentifier INTEGER,"
          "unitdescription TEXT,"
          "status INTEGER,"
          "positions INTEGER[],"
          "capacity INTEGER,"
          "updated BIGINT"
          ");");
    }
  }

  static Future<Unit> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM units WHERE id = @id;", substitutionValues: {"id": id});
    if (result.isEmpty) {
      throw "No unit found with id $id";
    }
    return Unit.fromDatabase(result[0].toColumnMap());
  }

  static Future<List<Unit>> getAll() async {
    var result = await Database.connection.query("SELECT * FROM units;");
    return result.map((e) => Unit.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<List<Unit>> getByStationId(int stationId) async {
    var result = await Database.connection.query("SELECT * FROM units WHERE stationid = @stationid;", substitutionValues: {"stationId": stationId});
    return result.map((e) => Unit.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> insert(Unit unit) async {
    unit.updated = DateTime.now();
    await Database.connection.query(
      "INSERT INTO units (id, stationid, unittype, unitidentifier, unitdescription, status, positions, capacity, updated) VALUES (@id, @stationid, @unittype, @unitidentifier, @unitdescription, @status, @positions, @capacity, @updated);",
      substitutionValues: unit.toDatabase(),
    );
  }

  static Future<void> update(Unit unit) async {
    unit.updated = DateTime.now();
    await Database.connection.query(
      "UPDATE units SET stationid = @stationid, unittype = @unittype, unitidentifier = @unitidentifier, unitdescription = @unitdescription, status = @status, positions = @positions, capacity = @capacity, updated = @updated WHERE id = @id;",
      substitutionValues: unit.toDatabase(),
    );
  }

  static Future<void> deleteById(int id) async {
    await Database.connection.query("DELETE FROM units WHERE id = @id;", substitutionValues: {"id": id});
  }

  static Future<List<Unit>> getByIds(Iterable<int> units) async {
    var result = await Database.connection.query("SELECT * FROM units WHERE id = ANY(@units);", substitutionValues: {"units": units});
    return result.map((e) => Unit.fromDatabase(e.toColumnMap())).toList();
  }
}

enum UnitPosition {
  ma,
  gf,
  atf,
  atm,
  wtf,
  wtm,
  stf,
  stm,
  me;
}
