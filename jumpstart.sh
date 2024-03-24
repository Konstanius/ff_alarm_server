set -e

# Purpose of this script is to install dart 3.3.1, docker, and then run ./init/installer.dart
# This script is intended to be run on a fresh Ubuntu 20.04 LTS installation

# basic requirements: sudo, wget, curl, gpg, docker
sudo apt-get update && sudo apt-get install -y sudo wget curl gpg docker apt-transport-https

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

# Run installer.dart
dart run ./init/installer.dart
