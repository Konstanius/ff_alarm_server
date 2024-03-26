import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:qr_terminal/qr_terminal.dart';

import '../utils/console.dart';
import 'otp.dart';

void main() async {
  await install();
}

Future<void> install() async {
  // if ./resources doesnt exist or isnt a dir, set working dir to ..
  if (!Directory("resources").existsSync()) {
    Directory.current = Directory.current.parent;
    outln("Changed working directory to ${Directory.current.path}", Color.verbose);
  }

  /// Requires Linux
  if (!Platform.isLinux) {
    outln('The FF Alarm Server can only be installed on Linux.', Color.error);
    return;
  }

  /// Requires Docker
  try {
    var result = await Process.run('docker', ['--version']);
    if (result.exitCode != 0) {
      outln('Docker is not installed. Please install Docker first.', Color.error);
      return;
    }
  } catch (e) {
    outln('Docker is not installed. Please install Docker first.', Color.error);
    return;
  }

  /// Requires Dart >= 3.0.0 and < 4.0.0
  try {
    var result = await Process.run('dart', ['--version']);
    if (result.exitCode != 0) {
      outln('Dart is not accessible. Please add the dart bin to your PATH.', Color.error);
      return;
    }
    var version = RegExp(r'\d+\.\d+\.\d+').firstMatch(result.stdout.toString())?.group(0);
    if (version == null || version.compareTo('3.0.0') < 0 || version.compareTo('4.0.0') >= 0) {
      outln('Dart version >= 3.0.0 and < 4.0.0 is required.', Color.error);
      return;
    }
  } catch (e) {
    outln('Dart is not accessible. Please add the dart bin to your PATH.', Color.error);
    return;
  }

  /// Required variables:
  /// (Database):
  /// - database_port
  /// - database_user
  /// - database_password
  /// - database_database
  ///
  /// (Firebase):
  /// - check resources/firebase/firebase-admin-token.json is present
  /// - check resources/firebase/FCMService.jar is present
  ///
  /// (Nginx):
  /// - nginx_host
  /// - nginx_port
  /// - nginx_ssl
  ///
  /// (Server):
  /// - admin_name
  /// - admin_password
  /// - admin_2fa (generate, display QR, save)
  ///
  /// (Setup):
  /// - prompt to open web admin panel and login

  if (!File('resources/firebase/firebase-admin-token.json').existsSync()) {
    outln('resources/firebase/firebase-admin-token.json is missing.', Color.error);
    outln('If this is your first time setting this up, please contact konstantin.dubnack@gmail.com to request a token.', Color.error);
    return;
  }

  if (!File('resources/firebase/FCMService.jar').existsSync()) {
    outln('resources/firebase/FCMService.jar is missing. Please check the git clone.', Color.error);
    return;
  }

  Map<String, dynamic> config = {};

  getInputValue(
    config,
    'Enter the database port (5432):',
    'database_port',
    (input) {
      try {
        int port = int.parse(input!);
        return port > 0 && port < 65536;
      } catch (_) {
        return false;
      }
    },
  );

  getInputValue(
    config,
    'Enter the database user (postgres):',
    'database_user',
    (input) => input != null && input.isNotEmpty,
  );

  getInputValue(
    config,
    'Enter the database password:',
    'database_password',
    (input) => input != null && input.isNotEmpty,
  );

  getInputValue(
    config,
    'Enter the database name (FF Alarm):',
    'database_database',
    (input) => input != null && input.isNotEmpty,
  );

  getInputValue(
    config,
    'Enter the domain for the Nginx server (example.com):',
    'nginx_host',
    (input) => input != null && input.isNotEmpty && input.contains('.'),
  );

  getInputValue(
    config,
    'Enter the port for the Nginx server (443):',
    'nginx_port',
    (input) {
      try {
        int port = int.parse(input!);
        return port > 0 && port < 65536;
      } catch (_) {
        return false;
      }
    },
  );

  getInputValue(
    config,
    'Enable SSL for the Nginx server (y/n):',
    'nginx_ssl',
    (input) => input?.toLowerCase() == 'y' || input?.toLowerCase() == 'n',
  );
  if (config['nginx_ssl'] == 'y') {
    if (!File('resources/cert.pem').existsSync()) {
      outln('resources/cert.pem is missing. Please generate a certificate and key.', Color.error);
      return;
    }

    if (!File('resources/key.pem').existsSync()) {
      outln('resources/key.pem is missing. Please generate a certificate and key.', Color.error);
      return;
    }
  }

  getInputValue(
    config,
    'Enter the login name of the admin user for the web panel (admin):',
    'admin_name',
    (input) => input != null && input.isNotEmpty,
  );

  getInputValue(
    config,
    'Enter the login password of the admin user for the web panel:',
    'admin_password',
    (input) => input != null && input.isNotEmpty,
  );

  /// Generate 2FA secret
  String secret = '';
  Random random = Random.secure();
  for (int i = 0; i < 32; i++) {
    secret += String.fromCharCode(random.nextInt(26) + 65);
  }
  String qrContent = "otpauth://totp/FF%20Alarm%20Administrator:${config['admin_name']}?secret=$secret&issuer=FF%20Alarm%20${config['nginx_host']}";
  config['admin_2fa'] = qrContent;
  outln('TOTP 2FA secret: $secret', Color.verbose);
  outln('TOTP 2FA access code: $qrContent', Color.verbose);
  outln('Scan the below QR code on your phone using Google Authenticator or similar. MAKE SURE TO NOT LOOSE THIS CODE!', Color.verbose);
  generate(qrContent, small: true);

  outln('Please enter the 6 digit code from your 2FA app:', Color.verbose);
  while (true) {
    String? input = stdin.readLineSync()?.trim() ?? '';
    if (OTP.verifyNow(secret, input)) {
      outln('TOTP 2FA setup successful.', Color.success);
      break;
    }

    outln('Invalid code. Please try again.', Color.error);
  }

  outln('Setup successful! Proceeding with installation of the FF Alarm Server...', Color.success);
  outln('Installing Docker network...', Color.verbose);

  // Check if docker network exists, if not, create it
  var result = await Process.run("docker", ["network", "ls", "--format", "{{.Name}}"]);
  if (!result.stdout.toString().contains("ff_alarm_network")) {
    result = await Process.run("docker", ["network", "create", "ff_alarm_network"]);
    if (result.exitCode != 0) {
      outln("Failed to create the network.", Color.error);
      return;
    }
  }

  // Check if the database exists
  result = await Process.run("docker", ["ps", "-a", "--format", "{{.Names}}"]);
  if (result.stdout.toString().contains("ff_alarm_postgres")) {
    outln("Database container already exists. Continuing will delete the existing database and create a new one.", Color.warn);
    bool confirmed = confirm();
    if (!confirmed) {
      outln("Installation cancelled.", Color.error);
      return;
    }

    result = await Process.run("docker", ["rm", "-f", "ff_alarm_postgres"]);
    if (result.exitCode != 0) {
      outln("Failed to delete the existing database container.", Color.error);
      return;
    }
  }

  outln("Docker network installation successful!", Color.success);
  outln("Setting up database container...", Color.verbose);

  // create the database container
  result = await Process.run("docker", [
    "create",
    "--hostname",
    "ff_alarm_postgres",
    "--name",
    "ff_alarm_postgres",
    "--network",
    "ff_alarm_network",
    "-e",
    "POSTGRES_PASSWORD=${config['database_password']}",
    "-e",
    "POSTGRES_DB=${config['database_database']}",
    "-p",
    "${config['database_port']}:${config['database_port']}",
    "postgres"
  ]);
  if (result.exitCode != 0) {
    outln("Failed to create the database container.", Color.error);
    return;
  }
  result = await Process.run("docker", ["start", "ff_alarm_postgres"]);
  if (result.exitCode != 0) {
    outln("Failed to start the database container.", Color.error);
    return;
  }

  outln("Database container setup successful!", Color.success);
  outln("Compiling FF Alarm backend...", Color.verbose);

  // compile the FF Alarm server
  result = await Process.run("dart", ["compile", "exe", "main.dart", "-o", "resources/main.exe"]);
  if (result.exitCode != 0) {
    outln("Failed to compile the FF Alarm server.", Color.error);
    return;
  }

  outln("Compilation successful!", Color.success);
  outln("Building Docker image...", Color.verbose);

  // build the docker image
  result = await Process.run("docker", ["build", "-t", "ff_alarm_server", "."]);
  if (result.exitCode != 0) {
    outln("Failed to build the FF Alarm server image.", Color.error);
    return;
  }

  outln("Docker image built successfully!", Color.success);
  outln("Setting up FF Alarm backend...", Color.verbose);

  // set the config file
  File configFile = File("resources/config.json");
  JsonEncoder encoder = JsonEncoder.withIndent('  ');
  Map<String, dynamic> newConfig = {
    "database": {
      "host": "ff_alarm_postgres",
      "port": int.parse(config['database_port']!),
      "user": config['database_user']!,
      "password": config['database_password']!,
      "database": config['database_database']!,
    },
    "admin": [
      {
        "name": config['admin_name']!,
        "password": config['admin_password']!,
        "2fa": config['admin_2fa']!,
      }
    ],
  };
  configFile.writeAsStringSync(encoder.convert(newConfig));

  // create the FF Alarm server
  result = await Process.run("docker",
      ["create", "--hostname", "ff_alarm_server", "--name", "ff_alarm_server", "--network", "ff_alarm_network", "-v", "${Directory.current.path}/resources:/ff/resources", "ff_alarm_server"]);
  if (result.exitCode != 0) {
    outln("Failed to create the FF Alarm server container.", Color.error);
    return;
  }
  result = await Process.run("docker", ["start", "ff_alarm_server"]);
  if (result.exitCode != 0) {
    outln("Failed to start the FF Alarm server container.", Color.error);
    return;
  }

  // set up chmod -R 777 resources
  result = await Process.run("sudo", ["chmod", "-R", "777", "resources"]);
  if (result.exitCode != 0) {
    outln("Failed to set permissions for the resources folder. Please run 'sudo chmod -R 777 resources' manually. Pausing until this is done.", Color.error);
    while (true) {
      result = await Process.run("ls", ["-l", "resources"]);
      // each line should start with "<any char>rwxrwxrwx"
      if (result.stdout.toString().split("\n").every((line) => RegExp(r".rwxrwxrwx").hasMatch(line))) {
        outln("Permissions set successfully.", Color.success);
        break;
      }

      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  outln("FF Alarm backend setup successful!", Color.success);

  await Future.delayed(Duration(seconds: 3));

  outln("Setting up Nginx server...", Color.verbose);

  // modify the nginx_template.conf
  File nginxTemplate = File("resources/nginx_template.conf");
  String nginxConfig = nginxTemplate.readAsStringSync();
  nginxConfig = nginxConfig.replaceAll("{{SERVER_NAME}}", config['nginx_host']);
  nginxConfig = nginxConfig.replaceAll("{{SERVER_PORT}}", config['nginx_port']);

  if (config['nginx_ssl'] == 'y') {
    nginxConfig = nginxConfig.replaceAll("{{COMMENT_NO_SSL}}", "#");
    nginxConfig = nginxConfig.replaceAll("{{COMMENT_SSL}}", "");
  } else {
    nginxConfig = nginxConfig.replaceAll("{{COMMENT_NO_SSL}}", "");
    nginxConfig = nginxConfig.replaceAll("{{COMMENT_SSL}}", "#");
  }

  File nginxConfigFile = File("resources/nginx.conf");
  nginxConfigFile.writeAsStringSync(nginxConfig);

  // docker create --hostname ff_alarm_nginx --name ff_alarm_nginx --network ff_alarm_network -p 80:80 -p 443:443 nginx
  // docker start ff_alarm_nginx
  // docker cp resources/nginx.conf ff_alarm_nginx:/etc/nginx/nginx.conf
  // docker restart ff_alarm_nginx
  result = await Process.run("docker", [
    "create",
    "--hostname",
    "ff_alarm_nginx",
    "--name",
    "ff_alarm_nginx",
    "--network",
    "ff_alarm_network",
    "-p",
    "80:80",
    if (config['nginx_port'] != '80') "-p",
    "${config['nginx_port']}:${config['nginx_port']}",
    "nginx"
  ]);
  if (result.exitCode != 0) {
    outln("Failed to create the Nginx container.", Color.error);
    return;
  }

  result = await Process.run("docker", ["start", "ff_alarm_nginx"]);
  if (result.exitCode != 0) {
    outln("Failed to start the Nginx container.", Color.error);
    return;
  }

  result = await Process.run("docker", ["cp", "resources/nginx.conf", "ff_alarm_nginx:/etc/nginx/nginx.conf"]);
  if (result.exitCode != 0) {
    outln("Failed to copy the Nginx configuration file.", Color.error);
    return;
  }

  if (config['nginx_ssl'] == 'y') {
    result = await Process.run("docker", ["cp", "resources/cert.pem", "ff_alarm_nginx:/etc/ssl/cert.pem"]);
    if (result.exitCode != 0) {
      outln("Failed to copy the SSL certificate.", Color.error);
      return;
    }
    result = await Process.run("docker", ["cp", "resources/key.pem", "ff_alarm_nginx:/etc/ssl/key.pem"]);
    if (result.exitCode != 0) {
      outln("Failed to copy the SSL key.", Color.error);
      return;
    }

    outln("SSL certificate and key copied successfully.", Color.success);

    outln("Please ensure that the SSL certificates are renewed before they expire.", Color.warn);
    outln("You might want to set up an automated renewal process using certbot or similar.", Color.warn);
  }

  // copy the entire ./panel/ folder recursively to /var/www/panel/
  result = await Process.run("docker", ["exec", "ff_alarm_nginx", "mkdir", "-p", "/var/www/panel"]);

  result = await Process.run("docker", ["cp", "panel/build/web/.", "ff_alarm_nginx:/var/www/panel"]);
  if (result.exitCode != 0) {
    outln("Failed to copy the web panel files.", Color.error);
    return;
  }

  result = await Process.run("docker", ["restart", "ff_alarm_nginx"]);
  if (result.exitCode != 0) {
    outln("Failed to restart the Nginx container.", Color.error);
    return;
  }

  outln("Nginx server setup successful!", Color.success);

  outln(
    "Please open the web panel at http${config['nginx_ssl'] == 'y' ? 's' : ''}://${config['nginx_host']}:${config['nginx_port']}/panel/?user=${config['admin_name']}&pass=${config['admin_password']} to login and complete the setup.",
    Color.info,
  );
}

void getInputValue(Map<String, dynamic> config, String prompt, String key, bool Function(String? input) check) {
  outln(prompt, Color.verbose);
  String? input = stdin.readLineSync();
  while (!check(input)) {
    outln('Invalid input. Please try again.', Color.error);
    input = stdin.readLineSync();
  }
  config[key] = input;
}

bool confirm() {
  outln("Do you want to continue? (y/n)", Color.warn);
  while (true) {
    String? input = stdin.readLineSync()?.trim().toLowerCase();
    if (input == 'y') {
      return true;
    } else if (input == 'n') {
      return false;
    }
    outln('Invalid input. Please try again.', Color.error);
  }
}
