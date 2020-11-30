#!/bin/bash

source ../../dap-service.config

main() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI login -u $CLUSTER_ADMIN
  fi
  clean_mysql
  if [[ "$1" == "clean" ]]; then
    exit 0
  fi
  deploy_mysql_db 
  deploy_db_client
  echo "Waiting for MySQL DB to become available..."
  sleep 45
  init_mysql
}

########################
clean_mysql() {
  $CLI delete -f ./manifests/mysql-manifest.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  rm -f ./manifests/mysql-manifest.yaml
  $CLI delete -f ./manifests/db-client-manifest.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  rm -f ./manifests/db-client-manifest.yaml
}

########################
deploy_mysql_db() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI adm policy add-scc-to-user anyuid -z mysql-db -n $CYBERARK_NAMESPACE_NAME
  fi
  sed "s#{{ MYSQL_IMAGE_NAME }}#$MYSQL_IMAGE#g"				\
        ./templates/mysql-manifest.template.yaml			\
    | sed "s#{{ CYBERARK_NAMESPACE_NAME }}#$CYBERARK_NAMESPACE_NAME#g"  \
    | sed "s#{{ MYSQL_ROOT_PASSWORD }}#$AUTHN_PASSWORD#g"		\
    > ./manifests/mysql-manifest.yaml
  $CLI apply -f ./manifests/mysql-manifest.yaml -n $CYBERARK_NAMESPACE_NAME
}

########################
deploy_db_client() {
  # this client is only used to initialize the database w/ the root user account
  sed "s#{{ APP_IMAGE }}#$APP_IMAGE#g"			\
        ./templates/db-client-manifest.template.yaml	\
    | sed "s#{{ DB_URL }}#$DB_URL#g"  			\
    > ./manifests/db-client-manifest.yaml
  $CLI apply -f ./manifests/db-client-manifest.yaml -n $CYBERARK_NAMESPACE_NAME
}

################################
init_mysql() {
  echo "Initializing MySQL database..."
  cat db_load.sql               				\
  | $CLI -n $CYBERARK_NAMESPACE_NAME exec -i pod/db-client --	\
        mysql -h $DB_URL -u root --password=$AUTHN_PASSWORD
}

main "$@"
