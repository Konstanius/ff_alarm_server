set -e

cd panel
git pull
flutter build web --base-href /panel/
docker cp build/web/. ff_alarm_nginx:/var/www/panel/
