set -e

# Purpose of this script is to install dart 3.3.1, docker, and then run ./init/installer.dart
# This script is intended to be run on a fresh Ubuntu 20.04 LTS installation

apt-get update

# check if sudo is installed
if ! command -v sudo &> /dev/null
then
  apt-get install -y sudo
fi

# basic requirements: wget, curl, gpg, docker..io, apt-transport-https
sudo apt-get install -y wget curl gpg docker.io apt-transport-https

# Check if dart is not already installed
if ! command -v dart &> /dev/null
then
  echo "Installing Dart"
  wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg  --dearmor -o /usr/share/keyrings/dart.gpg
  echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
  sudo apt-get update && sudo apt-get install dart -y

  # Add Dart to PATH
  # shellcheck disable=SC2016
  echo 'export PATH="$PATH:/usr/lib/dart/bin"' >> ~/.bashrc
fi

# pub get
dart pub get

# Run installer.dart
dart run ./init/installer.dart
