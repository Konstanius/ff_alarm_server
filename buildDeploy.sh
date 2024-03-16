set -e
echo "Getting dependencies of dart project"
dart pub get
echo "Successfully got dependencies"

echo "Compiling executable"
dart compile exe main.dart -o resources/main.exe
echo "Successfully compiled executable to resources/main.exe"

echo "Building docker image \"ff_alarm_server\""
docker build -t ff_alarm_server .
echo "Successfully built docker image \"ff_alarm_server\""

# delete the old docker image (by name: ff_alarm_server)
echo "Deleting old docker image \"ff_alarm_server\""
docker stop ff_alarm_server || true
docker container rm ff_alarm_server || true
#docker volume prune -f
echo "Successfully deleted old docker image and container \"ff_alarm_server\""

# run the docker image
docker create --hostname ff_alarm_server --name ff_alarm_server --network ff_alarm_network -v "$(pwd)/resources:/ff/resources" ff_alarm_server
docker start ff_alarm_server

# make the volume "resources" owned by the current user
sudo chmod -R 777 resources/

# delete dangling docker images
#echo "Deleting dangling docker images"
#docker image prune -f
#echo "Successfully deleted dangling docker images"

echo "Successfully built and deployed docker image \"ff_alarm_server\""
