#!/bin/bash

source ../dap-service.config

main() {
  oc login -u $CLUSTER_ADMIN
  clean_postgres
  if [[ "$1" == "clean" ]]; then
    exit 0
  fi
  tag_and_push_postgres_image
  deploy_postgres_db
}

########################
clean_postgres() {
  oc delete -f postgres.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  rm -f postgres.yaml
}

########################
tag_and_push_postgres_image() {
  docker login -u $(oc whoami) -p $(oc whoami -t) $EXTERNAL_REGISTRY_URL
  docker tag $LOCAL_POSTGRES_IMAGE $PUSH_POSTGRES_IMAGE
  docker push $PUSH_POSTGRES_IMAGE
}

########################
deploy_postgres_db() {
  oc adm policy add-scc-to-user anyuid -z postgres-db -n $CYBERARK_NAMESPACE_NAME
  sed "s#{{ IMAGE_NAME }}#$REGISTRY_POSTGRES_IMAGE#g"			\
        ./templates/postgres.template.yml                     		\
    | sed "s#{{ CYBERARK_NAMESPACE_NAME }}#$CYBERARK_NAMESPACE_NAME#g"  \
    | sed "s#{{ POSTGRES_DB_PASSWORD }}#$PG_DB_PASSWORD#g"              \
    > ./postgres.yaml
  oc apply -f ./postgres.yaml -n $CYBERARK_NAMESPACE_NAME
}

main "$@"
