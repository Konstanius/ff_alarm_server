import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dargon2/dargon2.dart';
import 'package:encrypt/encrypt.dart';

class RequestException {
  int statusCode;
  String message;

  RequestException(this.statusCode, this.message);
}

abstract class Utils {
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    var earthRadius = 6378137.0;
    var dLat = _toRadians(endLatitude - startLatitude);
    var dLon = _toRadians(endLongitude - startLongitude);

    var a = pow(sin(dLat / 2), 2) + pow(sin(dLon / 2), 2) * cos(_toRadians(startLatitude)) * cos(_toRadians(endLatitude));
    var c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}

abstract class HashUtils {
  static const int _argonIterations = 1024;
  static const int _argonMemory = 1024;
  static const int _argonParallelism = 1;
  static const Argon2Version _argonVersion = Argon2Version.V13;
  static const int _argonLength = 64;
  static const Argon2Type _argonType = Argon2Type.id;
  static const int _argonSaltLength = 16;

  static const int _randomKeyLength = 64;

  static Future<bool> compareHash(String plainText, String hash) async {
    try {
      return await argon2.verifyHashString(plainText, hash, type: _argonType);
    } catch (e) {
      return false;
    }
  }

  static Future<String> generateHash(String plainText) async {
    Salt salt = Salt.newSalt(length: _argonSaltLength);
    DArgon2Result result = await argon2.hashPasswordString(
      plainText,
      iterations: _argonIterations,
      memory: _argonMemory,
      parallelism: _argonParallelism,
      version: _argonVersion,
      length: _argonLength,
      type: _argonType,
      salt: salt,
    );
    return result.encodedString;
  }

  static String lightHash(String plainText) {
    List<int> bytes = utf8.encode(plainText);
    Digest digest = sha512.convert(bytes);
    return digest.toString();
  }

  static String generateRandomKey() {
    var random = Random.secure();
    var values = List<int>.generate(_randomKeyLength, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
}

abstract class CryptoUtils {
  static String generateKeyFromPassword(String password) {
    return HashUtils.lightHash(password).substring(0, 32);
  }

  static get iv => IV.fromBase64("IBYT8ieY6J+EZmKf62hQkg==");

  static String encryptAES(String data, String key) {
    String properKey = generateKeyFromPassword(key);
    Encrypter crypt = Encrypter(AES(Key.fromUtf8(properKey)));
    Encrypted encrypted = crypt.encrypt(data, iv: iv);
    return encrypted.base64;
  }

  static String decryptAES(String data, String key) {
    String properKey = generateKeyFromPassword(key);
    Encrypter crypt = Encrypter(AES(Key.fromUtf8(properKey)));
    Encrypted encrypted = Encrypted.fromBase64(data);
    return crypt.decrypt(encrypted, iv: iv);
  }
}
