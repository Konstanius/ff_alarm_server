set -e

# prevent running as root or sudo
if [ "$EUID" -eq 0 ]
  then echo "Please do not run as root or sudo"
  exit
fi

sudo chown -R $USER .

# Purpose of this script is to install dart 3.3.1, docker, and then run ./init/installer.dart
# This script is intended to be run on a fresh Ubuntu 20.04 LTS installation

sudo apt-get update

# check if sudo is installed
if ! command -v sudo &> /dev/null
then
  sudo apt-get install -y sudo
fi

# basic requirements: wget, curl, gpg, docker..io, apt-transport-https
sudo apt-get install -y wget curl gpg docker.io apt-transport-https

# Check if flutter is not already installed
if ! command -v flutter &> /dev/null
then
  echo "Installing Flutter"

  # Install Flutter to pwd/flutter-sdk
  curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.4-stable.tar.xz --output flutter.tar.xz
  tar -xf flutter.tar.xz
  rm flutter.tar.xz

  # Add flutter to PATH
  echo "export PATH=\"\$PATH:$(pwd)/flutter/bin\"" >> ~/.bashrc
  export PATH="$PATH:$(pwd)/flutter/bin"

  # Add dart to PATH
  echo "export PATH=\"\$PATH:$(pwd)/flutter/bin/cache/dart-sdk/bin\"" >> ~/.bashrc
  export PATH="$PATH:$(pwd)/flutter/bin/cache/dart-sdk/bin"

  # Check if flutter is installed
  flutter doctor
fi

# pub get
dart pub get

# Run installer.dart
dart run ./init/installer.dart
