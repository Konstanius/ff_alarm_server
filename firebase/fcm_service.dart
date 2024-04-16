import 'dart:convert';
import 'dart:io';

import '../models/person.dart';
import '../utils/console.dart';
import '../utils/database.dart';

IOSink? fcmStream;

Future<void> startFCMService() async {
  outln("Starting FCM service", Color.info);
  Process process = await Process.start(
    'java',
    [
      '-jar',
      'firebase/FCMService.jar',
    ],
  );

  // redirect stderr to console
  process.stderr.transform(utf8.decoder).listen((data) async {
    try {
      List<String> lines = data.split("\n");
      for (String line in lines) {
        try {
          if (line.contains("SLF4J:") || line.trim().isEmpty) {
            return;
          }

          if (!line.startsWith("MALTOKEN")) {
            outln("[JAVA] $line", Color.error);
            return;
          }

          String token = line.substring(9).trim();
          String tokenA = "A$token";
          String tokenI = "I$token";

          outln("[JAVA] Removing token $token", Color.warn);

          // Remove the token from all persons in a single pgsql query
          Set<int> personsA = {};
          Set<int> personsI = {};
          for (var person in Person.directCacheAccess.values) {
            if (person.fcmTokens.contains(tokenA)) {
              personsA.add(person.id);
              person.fcmTokens.remove(tokenA);
            }

            if (person.fcmTokens.contains(tokenI)) {
              personsI.add(person.id);
              person.fcmTokens.remove(tokenI);
            }
          }

          if (personsA.isNotEmpty) {
            await Database.connection.query(
              "UPDATE persons SET fcmtokens = array_remove(fcm_tokens, @tokenA) WHERE id = ANY(@personsA)",
              substitutionValues: {
                "tokenA": tokenA,
                "personsA": personsA.toList(),
              },
            );
            await Database.connection.query(
              "UPDATE persons SET fcmtokens = array_remove(fcm_tokens, @tokenI) WHERE id = ANY(@personsI)",
              substitutionValues: {
                "tokenI": tokenI,
                "personsI": personsI.toList(),
              },
            );
          }
        } catch (e, s) {
          outln("[JAVA] $e", Color.error);
          outln("[JAVA] $s", Color.error);
          outln("[JAVA] $line", Color.error);
        }
      }
    } catch (_) {}
  });

  process.stdout.transform(utf8.decoder).listen((data) async {
    try {
      List<String> lines = data.split("\n");
      for (String line in lines) {
        try {
          if (line.contains("SLF4J:") || line.trim().isEmpty) {
            return;
          }

          outln("[JAVA] $line", Color.info);
        } catch (e, s) {
          outln("[JAVA] $e", Color.error);
          outln("[JAVA] $s", Color.error);
          outln("[JAVA] $line", Color.error);
        }
      }
    } catch (_) {}
  });

  // When exit code is sent, set sink to null
  process.exitCode.then((exitCode) {
    fcmStream = null;

    outln("[JAVA] Process exited with code $exitCode, restarting", Color.error);
    startFCMService();
  });

  fcmStream = process.stdin;

  outln("FCM service started", Color.success);
}

Future<List<int>> invokeSDK(bool isTopic, String type, Map<String, dynamic> data, {String? topic, Set<String>? androidTokens, Set<String>? iosTokens}) async {
  if (fcmStream == null) {
    await startFCMService();

    await Future.delayed(const Duration(seconds: 1));
  }

  Set<String> genericLow = {};
  Set<String> androidHigh = {...androidTokens ?? {}};
  Set<String> iosHigh = {...iosTokens ?? {}};

  Map<String, dynamic> args = {"method": isTopic ? "topic" : "tokens"};
  if (isTopic) {
    args["topic"] = topic!;
    args["type"] = type;
    args["data"] = data;
  } else {
    Map<String, dynamic> tokens = {
      "genericLow": genericLow.toList(),
      "ios": iosHigh.toList(),
      "android": androidHigh.toList(),
    };
    args["tokens"] = tokens;
    args["type"] = type;
    args["data"] = data;
  }

  fcmStream!.writeln(jsonEncode(args));

  return [genericLow.length, androidHigh.length, iosHigh.length];
}
