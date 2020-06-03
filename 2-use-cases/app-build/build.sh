#!/bin/bash -e

source ../../dap-service.config

set -x
sed -e "s#{{ ACCOUNT_USERNAME }}#$ACCOUNT_USERNAME#g"		\
	./templates/secrets.template.yml				\
    | sed -e "s#{{ ACCOUNT_PASSWORD }}#$ACCOUNT_PASSWORD#g"	\
    > ./secrets.yml

sed -e "s#{{ ACCOUNT_USERNAME }}#$ACCOUNT_USERNAME#g"		\
	./templates/mysql_REST.template.sh			\
    | sed -e "s#{{ ACCOUNT_PASSWORD }}#$ACCOUNT_PASSWORD#g"	\
    > ./mysql_REST.sh

chmod +x ./mysql_REST.sh

if [[ "$(docker images | grep $APP_IMAGE)" != "" ]]; then
  docker rmi $APP_IMAGE
fi
docker build -t $LOCAL_APP_IMAGE .
