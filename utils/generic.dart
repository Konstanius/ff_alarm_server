import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dargon2/dargon2.dart';

class RequestException {
  int statusCode;
  String message;

  RequestException(this.statusCode, this.message);
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
    return await argon2.verifyHashString(plainText, hash, type: _argonType);
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
