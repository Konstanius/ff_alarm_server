import '../../server/init.dart';
import '../../utils/database.dart';
import '../../utils/generic.dart';

class Session {
  int id;
  int personId;
  String tokenHash;
  String userAgent;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime expiresAt;

  Session({
    required this.id,
    required this.personId,
    required this.tokenHash,
    required this.userAgent,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  factory Session.fromDatabase(Map<String, dynamic> json) {
    return Session(
      id: json["id"],
      personId: json["person_id"],
      tokenHash: json["token_hash"],
      userAgent: json["user_agent"],
      createdAt: DateTime.parse(json["created_at"]),
      updatedAt: DateTime.parse(json["updated_at"]),
      expiresAt: DateTime.parse(json["expires_at"]),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      "id": id,
      "person_id": personId,
      "token_hash": tokenHash,
      "user_agent": userAgent,
      "created_at": createdAt.toIso8601String(),
      "updated_at": updatedAt.toIso8601String(),
      "expires_at": expiresAt.toIso8601String(),
    };
  }

  static Future<void> init() async {
    var result = await Database.connection.query("SELECT EXISTS ("
        "SELECT FROM information_schema.tables "
        "WHERE table_schema = 'public' "
        "AND table_name = 'sessions'"
        ");");

    if (result[0][0] == false) {
      await Database.connection.query("CREATE TABLE sessions ("
          "id SERIAL PRIMARY KEY,"
          "person_id INTEGER NOT NULL,"
          "token_hash TEXT NOT NULL,"
          "user_agent TEXT NOT NULL,"
          "created_at BIGINT NOT NULL,"
          "updated_at BIGINT NOT NULL,"
          "expires_at BIGINT NOT NULL"
          ");");
    }
  }

  static Future<Session?> getById(int id) async {
    var result = await Database.connection.query("SELECT * FROM sessions WHERE id = $id;");
    if (result.isEmpty) return null;
    return Session.fromDatabase(result[0].toColumnMap());
  }

  static Future<List<Session>> getForPerson(int personId) async {
    var result = await Database.connection.query("SELECT * FROM sessions WHERE person_id = $personId;");
    return result.map((e) => Session.fromDatabase(e.toColumnMap())).toList();
  }

  static Future<void> insert(Session session) async {
    session.updatedAt = DateTime.now();
    var result = await Database.connection.query(
      "INSERT INTO sessions (person_id, token_hash, user_agent, created_at, updated_at, expires_at) VALUES (@person_id, @ip, @token_hash, @user_agent, @created_at, @updated_at, @expires_at) RETURNING id;",
      substitutionValues: session.toDatabase(),
    );
    session.id = result[0][0];
  }

  static Future<void> update(Session session) async {
    session.updatedAt = DateTime.now();
    await Database.connection.query(
      "UPDATE sessions SET person_id = @person_id, token_hash = @token_hash, user_agent = @user_agent, created_at = @created_at, updated_at = @updated_at, expires_at = @expires_at WHERE id = @id;",
      substitutionValues: session.toDatabase(),
    );
  }

  static Future<void> delete(int id) async {
    await Database.connection.query("DELETE FROM sessions WHERE id = $id;");
  }

  Future<void> invalidate() async {
    expiresAt = DateTime.now();
    await update(this);

    for (var connection in realtimeConnections) {
      if (connection.session.id == id) {
        try {
          connection.close();
        } catch (_) {}
      }
    }
  }

  Future<bool> validate(String key) async {
    if (DateTime.now().isAfter(expiresAt)) return false;
    if (tokenHash != HashUtils.lightHash(key)) return false;

    if (DateTime.now().difference(updatedAt).inDays > 1) {
      expiresAt = DateTime.now().add(const Duration(days: 28));
      await update(this);
    }

    return true;
  }
}
