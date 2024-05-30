import '../../utils/database.dart';
import '../../utils/generic.dart';

class Monitor {
  static final Map<String, Monitor> preparedMonitors = {};

  int id;
  String name;
  int stationId;
  List<int> units;
  String tokenHash;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime expiresAt;
  
  Monitor({
    required this.id,
    required this.name,
    required this.stationId,
    required this.units,
    required this.tokenHash,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  factory Monitor.fromDatabase(Map<String, dynamic> data) {
    return Monitor(
      id: data["id"],
      name: data["name"],
      stationId: data["station_id"],
      units: data["units"],
      tokenHash: data["token_hash"],
      createdAt: DateTime.fromMillisecondsSinceEpoch(data["created_at"]),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data["updated_at"]),
      expiresAt: DateTime.now().add(const Duration(days: 56)),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "id": id,
      "name": name,
      "station_id": stationId,
      "units": units,
      "token_hash": tokenHash,
      "created_at": createdAt.millisecondsSinceEpoch,
      "updated_at": updatedAt.millisecondsSinceEpoch,
      "expires_at": expiresAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "stationId": stationId,
      "units": units,
      "createdAt": createdAt.millisecondsSinceEpoch,
      "updatedAt": updatedAt.millisecondsSinceEpoch,
      "expiresAt": expiresAt.millisecondsSinceEpoch,
    };
  }

  static Future<void> initialize() async {
    var result = await Database.connection.query("SELECT EXISTS ("
        "SELECT FROM information_schema.tables "
        "WHERE table_schema = 'public' "
        "AND table_name = 'monitors'"
        ");");

    if (result[0][0] == false) {
      await Database.connection.query("CREATE TABLE monitors ("
          "id SERIAL PRIMARY KEY,"
          "name TEXT NOT NULL,"
          "station_id INTEGER NOT NULL,"
          "units INTEGER[] NOT NULL,"
          "token_hash TEXT NOT NULL,"
          "created_at BIGINT NOT NULL,"
          "updated_at BIGINT NOT NULL,"
          "expires_at BIGINT NOT NULL"
          ");",
      );
    }
  }

  Future<bool> validate(String key) async {
    if (DateTime.now().isAfter(expiresAt)) return false;
    if (tokenHash != HashUtils.lightHash(key)) return false;

    if (DateTime.now().difference(updatedAt).inDays > 1) {
      expiresAt = DateTime.now().add(const Duration(days: 56));
      await update(this);
    }

    return true;
  }

  static Future<Monitor?> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM monitors WHERE id = $id;");
    if (result.isEmpty) return null;
    return Monitor.fromDatabase(result[0].toColumnMap());
  }

  static Future<void> insert(Monitor monitor) async {
    monitor.updatedAt = DateTime.now();
    var result = await Database.connection.query(
      "INSERT INTO monitors (name, station_id, units, token_hash, created_at, updated_at, expires_at) "
      "VALUES (@name, @station_id, @units, @token_hash, @created_at, @updated_at, @expires_at) RETURNING id;",
      substitutionValues: monitor.toDatabase(),
    );
    monitor.id = result[0][0];
  }

  static Future<void> update(Monitor monitor) async {
    monitor.updatedAt = DateTime.now();
    await Database.connection.query(
      "UPDATE monitors SET name = @name, station_id = @station_id, units = @units, token_hash = @token_hash, "
      "created_at = @created_at, updated_at = @updated_at, expires_at = @expires_at WHERE id = @id;",
      substitutionValues: monitor.toDatabase(),
    );
  }

  static Future<void> delete(Monitor monitor) async {
    await Database.connection.query("DELETE FROM monitors WHERE id = @id;", substitutionValues: {"id": monitor.id});
  }
  
  static Future<void> refresh(Monitor monitor) async {
    await Database.connection.query("UPDATE monitors SET updated_at = @updated_at WHERE id = @id AND expires_at > @updated_at;", substitutionValues: {
      "id": monitor.id,
      "updated_at": DateTime.now().millisecondsSinceEpoch,
    });
  }
}
