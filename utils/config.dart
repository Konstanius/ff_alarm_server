import 'dart:convert';
import 'dart:io';

abstract class Config {
  static late Map<String, dynamic> config;

  static void initialize() {
    File file = File("config.json");
    String content = file.readAsStringSync();
    config = jsonDecode(content);
  }
}
