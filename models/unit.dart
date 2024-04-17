import '../server/init.dart';
import '../utils/config.dart';
import '../utils/database.dart';
import 'person.dart';

class Unit {
  int id;
  int stationId;

  /// Callsign should match regex:
  /// ^\S+\s+\S+(?:\s+\S+)*\s+\d+-\d+-\d+$
  /// Florian Jena 5-43-1
  String callSign;
  static final RegExp callSignRegex = RegExp(r"^\S+\s+\S+(?:\s+\S+)*\s+\d+-\d+-\d+$");

  ({String prefix, String area, int stationIdentifier, int unitType, int unitIndex})? get unitInformation {
    List<String> splits = callSign.split(' ');
    if (splits.length < 3) return null;
    List<String> stationSplits = splits.last.split('-');
    if (stationSplits.length != 3) return null;

    String prefix = splits[0];
    String area = splits.sublist(1, splits.length - 1).join(' ');

    int? stationIdentifier = int.tryParse(stationSplits[0]);
    int? unitType = int.tryParse(stationSplits[1]);
    int? unitIndex = int.tryParse(stationSplits[2]);

    if (stationIdentifier == null || unitType == null || unitIndex == null) return null;

    return (prefix: prefix, area: area, stationIdentifier: stationIdentifier, unitType: unitType, unitIndex: unitIndex);
  }

  String unitDescription;
  int status;
  List<UnitPosition> positions;
  int capacity;
  DateTime updated;

  Unit({
    required this.id,
    required this.stationId,
    required this.callSign,
    required this.unitDescription,
    required this.status,
    required this.positions,
    required this.capacity,
    required this.updated,
  });

  static const Map<String, String> jsonShorts = {
    "server": "s",
    "id": "i",
    "stationId": "si",
    "callSign": "cs",
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
      callSign: json[jsonShorts["callSign"]],
      unitDescription: json[jsonShorts["unitDescription"]],
      status: json[jsonShorts["status"]],
      positions: List<UnitPosition>.from(json[jsonShorts["positions"]].map((e) => UnitPosition.values[e])),
      capacity: json[jsonShorts["capacity"]],
      updated: DateTime.fromMillisecondsSinceEpoch(json[jsonShorts["updated"]]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      jsonShorts["server"]!: Config.config["server"],
      jsonShorts["id"]!: id,
      jsonShorts["stationId"]!: stationId,
      jsonShorts["callSign"]!: callSign,
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
      callSign: data["callsign"],
      unitDescription: data["unitdescription"],
      status: data["status"],
      positions: List<UnitPosition>.from(data["positions"].map((e) => UnitPosition.values[e])),
      capacity: data["capacity"],
      updated: DateTime.fromMillisecondsSinceEpoch(data["updated"]),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "id": id,
      "stationid": stationId,
      "callsign": callSign,
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
      await Database.connection.query(
        "CREATE TABLE units ("
        "id SERIAL PRIMARY KEY,"
        "stationid INTEGER NOT NULL,"
        "callsign TEXT NOT NULL,"
        "unitdescription TEXT NOT NULL,"
        "status INTEGER NOT NULL,"
        "positions INTEGER[] NOT NULL,"
        "capacity INTEGER NOT NULL,"
        "updated BIGINT NOT NULL"
        ");",
      );
    }
  }

  static Future<Unit?> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM units WHERE id = @id;", substitutionValues: {"id": id});
    if (result.isEmpty) {
      return null;
    }
    return Unit.fromDatabase(result[0].toColumnMap());
  }

  static Future<List<Unit>> getAll() async {
    var result = await Database.connection.query("SELECT * FROM units;");
    return result.map((e) => Unit.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<List<Unit>> getForPerson(Person person) async {
    var result = await Database.connection.query("SELECT * FROM units WHERE id = ANY(@allowedunits);", substitutionValues: {"allowedunits": person.allowedUnits});
    return result.map((e) => Unit.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<List<Unit>> getByStationId(int stationId) async {
    var result = await Database.connection.query("SELECT * FROM units WHERE stationid = @stationid;", substitutionValues: {"stationid": stationId});
    return result.map((e) => Unit.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> insert(Unit unit) async {
    unit.updated = DateTime.now();
    var result = await Database.connection.query(
      "INSERT INTO units (id, stationid, callsign, unitdescription, status, positions, capacity, updated) VALUES (@id, @stationid, @callsign, @unitdescription, @status, @positions, @capacity, @updated) RETURNING id;",
      substitutionValues: unit.toDatabase(),
    );
    unit.id = result[0][0];
    Unit.broadcastChange(unit);
  }

  static Future<void> update(Unit unit) async {
    unit.updated = DateTime.now();
    await Database.connection.query(
      "UPDATE units SET stationid = @stationid, callsign = @callsign, unitdescription = @unitdescription, status = @status, positions = @positions, capacity = @capacity, updated = @updated WHERE id = @id;",
      substitutionValues: unit.toDatabase(),
    );
    Unit.broadcastChange(unit);
  }

  static Future<void> deleteById(int id) async {
    await Database.connection.query("DELETE FROM units WHERE id = @id;", substitutionValues: {"id": id});
    Unit.broadcastDelete(id);
  }

  static Future<List<Unit>> getByIds(Iterable<int> units) async {
    if (units.isEmpty) return [];
    var result = await Database.connection.query(
      "SELECT * FROM units WHERE id = ANY(@units);",
      substitutionValues: {"units": units.toList()},
    );
    return result.map((e) => Unit.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> broadcastChange(Unit unit) async {
    var json = unit.toJson();
    for (var connection in realtimeConnections) {
      if (!connection.person.allowedUnits.contains(unit.id)) continue;
      connection.send("unit", json);
    }
  }

  static Future<void> broadcastDelete(int id) async {
    for (var connection in realtimeConnections) {
      connection.send("unit_delete", {"id": id});
    }
  }
}

enum UnitPosition {
  zf,
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
