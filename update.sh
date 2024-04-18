set -e

echo "Updating source"
git pull

echo "Getting dependencies of dart project"
dart pub get

echo "Compiling executable"
dart compile exe main.dart -o resources/main.exe

echo "Building docker image \"ff_alarm_server\""
docker build -t ff_alarm_server .

echo "Stopping old docker container"
docker stop ff_alarm_server || true

echo "Deleting old docker image \"ff_alarm_server\""
docker container rm ff_alarm_server || true

echo "Creating and starting new docker container \"ff_alarm_server\""
docker create --hostname ff_alarm_server --name ff_alarm_server --network ff_alarm_network -v "$(pwd)/resources:/ff/resources" ff_alarm_server

docker cp resources/main.exe ff_alarm_server:/ff/resources/main.exe
docker start ff_alarm_server

echo "Pruning unused docker images"
docker image prune -f

if [ "$(stat -c %a resources/)" != "777" ]; then
    echo "Setting permissions for resources folder"
    sudo chmod -R 777 resources/
fi

echo "Successfully updated and started ff_alarm_server"
