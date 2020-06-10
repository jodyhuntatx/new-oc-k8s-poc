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
  tag_and_push_mysql_image
  deploy_mysql_db
}

########################
clean_mysql() {
  $CLI delete -f mysql.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  rm -f mysql.yaml
}

########################
tag_and_push_mysql_image() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    docker login -u $($CLI whoami) -p $($CLI whoami -t) $EXTERNAL_REGISTRY_URL
  fi
  docker tag $LOCAL_MYSQL_IMAGE $PUSH_MYSQL_IMAGE
  docker push $PUSH_MYSQL_IMAGE
}

########################
deploy_mysql_db() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI adm policy add-scc-to-user anyuid -z mysql-db -n $CYBERARK_NAMESPACE_NAME
  fi
  sed "s#{{ MYSQL_IMAGE_NAME }}#$REGISTRY_MYSQL_IMAGE#g"			\
        ./templates/mysql.template.yml                     		\
    | sed "s#{{ CYBERARK_NAMESPACE_NAME }}#$CYBERARK_NAMESPACE_NAME#g"  \
    | sed "s#{{ MYSQL_USERNAME }}#$MYSQL_USERNAME#g"              \
    | sed "s#{{ MYSQL_PASSWORD }}#$MYSQL_PASSWORD#g"              \
    > ./mysql.yaml
  $CLI apply -f ./mysql.yaml -n $CYBERARK_NAMESPACE_NAME
}

main "$@"
