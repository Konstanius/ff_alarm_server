import 'dart:io';

Future<void> handleGeoPing(Map<String, dynamic> data, Function(int statusCode, Map<String, dynamic> response) callback) async {
  double lat = data['lat'];
  double lon = data['lon'];
  int time = data['time'];
  DateTime date = DateTime.fromMillisecondsSinceEpoch(time);
  print("Received ping from $lat, $lon at $date");
  await callback(HttpStatus.ok, {});
}
