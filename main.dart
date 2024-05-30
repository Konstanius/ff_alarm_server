import 'dart:async';
import 'dart:io';

import 'firebase/fcm_service.dart';
import 'server/init.dart';
import 'utils/config.dart';
import 'utils/console.dart';
import 'utils/database.dart';

Future<void> main(List<String> arguments) async {
  outln("Server starting", Color.info);

  outln("Initializing configuration", Color.info);
  Config.initialize();

  outln("Configuration serialized, initializing database", Color.info);
  await Database.initialize();

  outln("Database connected and verified, starting server", Color.info);
  await initServer();

  outln("Server started, launching FCM Service", Color.info);

  startFCMService();
  outln("All systems started!", Color.success);

  ProcessSignal.sigterm.watch().listen((event) {
    outln("Received SIGTERM, shutting down", Color.warn);
    exit(0);
  });
}
