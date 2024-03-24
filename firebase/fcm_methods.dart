import '../models/alarm.dart';
import '../models/person.dart';
import 'fcm_service.dart';

abstract class FCMMethods {
  static Future<void> sendTestAlarm() async {
    List<Person> persons = await Person.getAll();

    Set<String> androidTokens = {};
    Set<String> iosTokens = {};

    for (Person person in persons) {
      for (String token in person.fcmTokens) {
        if (token.startsWith("A")) {
          androidTokens.add(token.substring(1));
        } else if (token.startsWith("I")) {
          iosTokens.add(token.substring(1));
        } else {
          // Should not happen, optionally for alternative platforms / future use
        }
      }
    }

    DateTime now = DateTime.now();

    await Future.delayed(const Duration(seconds: 5));

    Alarm alarm = Alarm(
      id: 0,
      type: "Test",
      word: "Alarmierungstest FF",
      date: now,
      number: (now.year - 2000) * 10000000 + now.month * 100000,
      address: "Am Anger 28, 07743 Jena",
      notes: ["Diese Alarmierung ist ein Test.", "Es besteht kein Handlungsbedarf."],
      units: [],
      updated: now,
    );
    await Alarm.insert(alarm);

    String deflated = alarm.deflateToString();

    await invokeSDK(
      false,
      "alarm",
      {"alarm": deflated},
      androidTokens: androidTokens,
      iosTokens: iosTokens,
    );
  }
}
