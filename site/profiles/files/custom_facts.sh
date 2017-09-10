#!/usr/bin/env bash
## Get Current yum updates avaialble in a json format
CHECK_UPDATES=$(yum check-update -q | awk '(NR >=4) {print "\"" $1 "\":" " " "\"" $2 "\",";}')
CHECK_UPDATES=$(echo $CHECK_UPDATES | sed 's/\(.*\),/\1 /')
CHECK_UPDATES=$(echo "{" $CHECK_UPDATES "}")

## Get dates for recently applied patches
RECENTLY_PATCHED=$(echo "{" $(rpm -qa --qf '{%{INSTALLTIME} "%{NAME}": "%{INSTALLTIME}",\n' | sort -n | tail -100 |cut -d' ' -f2-) "}")
RECENTLY_PATCHED=$(echo $RECENTLY_PATCHED | sed 's/\(.*\),/\1 /')

## Get the current status of the applications
APP_STATUS="{"
for d in /opt/landregistry/applications/*/lr-*.service ; do
    SERVICE_NAME=$(basename $d)
    APP_PATH=$(dirname $d)
    APP_NAME=$(basename $APP_PATH)
    SERVICE_STATUS=$(sudo systemctl | grep ${SERVICE_NAME} | awk '{print $4;}')
    SERVICE_PORT=$(cat $APP_PATH/startup.sh | grep "export PORT" | tr -dc '0-9')
    SERVICE_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$SERVICE_PORT/health)
    echo $SERVICE_STATUS
    echo $APP_PATH
    echo $SERVICE_PORT
    echo $SERVICE_HEALTH
    APP_STATUS=$(echo $APP_STATUS "\"$APP_NAME\": {\"port\": \"${SERVICE_PORT}\", \"application_health\": \"${SERVICE_HEALTH}\", \"service_health\": \"${SERVICE_STATUS}\"}," )
done
APP_STATUS=$(echo $APP_STATUS | sed 's/\(.*\),/\1 /')
APP_STATUS=$(echo $APP_STATUS "}")

echo "lr_application_status=${APP_STATUS}"
echo "server_patches_applied=${RECENTLY_PATCHED}"
echo "server_available_updates_json=${CHECK_UPDATES}"
echo "server_available_updates=$(yum check-update --quiet | grep '^[a-z0-9]' | wc -l)"
echo "server_last_update=$(cat /var/log/yum.log | grep Updated: | tail -1 | awk '{print $1 " " $2 " " $3}')"
echo "clamav_version=$(clamscan -V)"
