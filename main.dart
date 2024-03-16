import 'dart:async';
import 'dart:io';

import 'firebase/fcm_service.dart';
import 'server/init.dart';
import 'utils/config.dart';
import 'utils/console.dart';
import 'utils/database.dart';

Future<void> main(List<String> arguments) async {
  Config.initialize();
  await Database.initialize();

  await initServer();

  Timer.periodic(Duration(seconds: 5), (timer) {
    print("${DateTime.now()} : Server is running");
  });

  ProcessSignal.sigterm.watch().listen((event) {
    outln("Received SIGTERM, shutting down", Color.warn);
    exit(0);
  });

  startFCMService();
}
