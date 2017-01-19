#!/bin/bash
cd "$APP_HOME"

echo "================ Waiting for MySQL's port to respond"

/bin/bash /wait_for_port.sh "$SQL_HOST" "$SQL_HOST_PORT"

echo "================ Migrating Openlogic database"
rake db:create db:migrate

# echo "================ Starting memcache - oh no, two long running processes in the same container."
# memcached -d -uroot


rails s -d Puma -b 0.0.0.0 -p 3000
tail -100f ./log/production.log
