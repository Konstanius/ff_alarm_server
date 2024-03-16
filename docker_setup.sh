docker network create ff_alarm_network

docker create --hostname ff_alarm_postgres --name ff_alarm_postgres --network ff_alarm_network -e POSTGRES_PASSWORD=Lyxa8psV92t7KSdcPqFTEf3MYC6hZBHjmeDnJvXw5R4AkugNUW -e POSTGRES_DB=FFAlarm -p 5432:5432 postgres
docker start ff_alarm_postgres

dart compile exe main.dart -o resources/main.exe
docker build -t ff_alarm_server .

docker create --hostname ff_alarm_server --name ff_alarm_server --network ff_alarm_network -v "$(pwd)/resources:/hbv/resources" ff_alarm_server
docker start ff_alarm_server
sudo chmod -R 777 resources/

sleep 3

docker create --hostname ff_alarm_nginx --name ff_alarm_nginx --network ff_alarm_network -p 80:80 -p 443:443 nginx
docker start ff_alarm_nginx
docker cp resources/nginx.conf ff_alarm_nginx:/etc/nginx/nginx.conf
docker restart ff_alarm_nginx
