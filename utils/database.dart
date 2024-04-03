import 'dart:async';

import 'package:postgres/postgres.dart';

import '../models/alarm.dart';
import '../models/backend/session.dart';
import '../models/person.dart';
import '../models/station.dart';
import '../models/unit.dart';
import 'config.dart';

abstract class Database {
  static late PostgreSQLConnection connection;
  static late String host;
  static late int port;
  static late String database;
  static late String user;
  static late String password;
  static late Timer keepAliveTimer;

  static Future<void> initialize() async {
    host = Config.config['database']['host'];
    port = Config.config['database']['port'];
    database = Config.config['database']['database'];
    user = Config.config['database']['user'];
    password = Config.config['database']['password'];

    connection = PostgreSQLConnection(
      host,
      port,
      database,
      username: user,
      password: password,
    );

    await connection.open();

    keepAliveTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await connection.query("SELECT 1");
    });

    await connection.query("SELECT 1");

    await Station.initialize();
    await Unit.initialize();
    await Person.initialize();
    await Alarm.initialize();
    await Session.initialize();
  }
}
