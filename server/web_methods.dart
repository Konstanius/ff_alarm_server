import '../init/otp.dart';
import '../interfaces/web_interface.dart';
import '../utils/config.dart';
import '../utils/console.dart';
import '../utils/generic.dart';

abstract class WebMethods {
  static const Map<String, Future<void> Function(WebSession session, Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback)?> methods = {
    "ping": WebInterface.ping,
    "adminManage": WebInterface.adminManage,
    "systemDiagnostics": WebInterface.systemDiagnostics,
    "logsList": WebInterface.logsList,
    "logsGet": WebInterface.logsGet,
    "auditLogsGet": WebInterface.auditLogsGet,
    "unitList": WebInterface.unitList,
    "unitGetDetails": WebInterface.unitGetDetails,
    "unitCreate": WebInterface.unitCreate,
    "unitUpdate": WebInterface.unitUpdate,
    "unitDelete": WebInterface.unitDelete,
    "stationList": WebInterface.stationList,
    "stationGetDetails": WebInterface.stationGetDetails,
    "stationCreate": WebInterface.stationCreate,
    "stationUpdate": WebInterface.stationUpdate,
    "stationDelete": WebInterface.stationDelete,
    "personList": WebInterface.personList,
    "personGetDetails": WebInterface.personGetDetails,
    "personCreate": WebInterface.personCreate,
    "personUpdate": WebInterface.personUpdate,
    "personDelete": WebInterface.personDelete,
    "alarmList": WebInterface.alarmList,
    "alarmGetDetails": WebInterface.alarmGetDetails,
    "alarmCreate": WebInterface.alarmCreate,
    "alarmUpdate": WebInterface.alarmUpdate,
    "alarmDelete": WebInterface.alarmDelete,
    "getCoordinates": WebInterface.getCoordinates,
    "getAddress": WebInterface.getAddress,
  };
}

class WebSession {
  static const Duration enabledDuration = Duration(minutes: 5);

  DateTime createdAt;
  DateTime lastActive;
  String token;
  String username;

  WebSession({required this.createdAt, required this.lastActive, required this.token, required this.username}) {
    outln("Created session for $username", Color.info);
  }

  static List<WebSession> sessions = [];

  static WebSession? getSession(String token) {
    List<WebSession> toRemove = [];
    WebSession? toReturn;
    DateTime now = DateTime.now();
    for (WebSession session in sessions) {
      if (session.lastActive.isBefore(now.subtract(enabledDuration))) {
        toRemove.add(session);
      } else if (session.token == token) {
        session.lastActive = now;
        toReturn = session;
        break;
      }
    }

    for (WebSession session in toRemove) {
      sessions.remove(session);
    }

    return toReturn;
  }

  static Future<WebSession?> createSession({required String username, required String password, required String otpCode}) async {
    List<dynamic> admins = Config.config["admins"];
    for (Map<String, dynamic> admin in admins) {
      String name = admin["name"];
      if (name != username) continue;

      String passwordHash = admin["password"];
      if (!await HashUtils.compareHash(password, passwordHash)) return null;

      String otpSecret = admin["2fa"];
      String otpInfo = CryptoUtils.decryptAES(otpSecret, password);

      if (!OTP.verifyNow(otpInfo, otpCode)) return null;

      String token;
      while (true) {
        token = HashUtils.generateRandomKey();
        if (getSession(token) == null) break;
      }

      WebSession session = WebSession(createdAt: DateTime.now(), lastActive: DateTime.now(), token: token, username: username);
      sessions.add(session);
      return session;
    }

    return null;
  }
}
