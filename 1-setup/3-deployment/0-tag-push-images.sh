#!/bin/bash

source ../../dap-service.config

LOCAL_LAB_IMAGES=(
  $LOCAL_APPLIANCE_IMAGE
  $LOCAL_CLI_IMAGE
  $LOCAL_SEED_FETCHER_IMAGE
  $LOCAL_MYSQL_IMAGE
  $LOCAL_APP_IMAGE
  $LOCAL_AUTHENTICATOR_IMAGE
  $LOCAL_SECRETS_PROVIDER_IMAGE
  $LOCAL_SECRETLESS_CLIENT
  $LOCAL_SECRETLESS_BROKER_IMAGE
)

PUSH_LAB_IMAGES=(
  $PUSH_APPLIANCE_IMAGE
  $PUSH_CLI_IMAGE
  $PUSH_SEED_FETCHER_IMAGE
  $PUSH_MYSQL_IMAGE
  $PUSH_APP_IMAGE
  $PUSH_AUTHENTICATOR_IMAGE
  $PUSH_SECRETS_PROVIDER_IMAGE
  $PUSH_SECRETLESS_CLIENT
  $PUSH_SECRETLESS_BROKER_IMAGE
)

main() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI login -u $CYBERARK_NAMESPACE_ADMIN
    docker login -u $($CLI whoami) -p $($CLI whoami -t) $EXTERNAL_REGISTRY_URL
  fi
  check_local_image_tags
  tag_and_push_lab_images
}

#############################
check_local_image_tags() {
  all_found=true
  for img_name in "${LOCAL_LAB_IMAGES[@]}"; do
    echo -n "  Checking $img_name: "
    if [[ "$(docker image ls $img_name | grep -v REPOSITORY)" == "" ]]; then
      echo " NOT FOUND"
      all_found=false
    else
      echo "loaded"
    fi
  done
  if ! $all_found; then
    echo "Check image tags."
    exit -1
  fi    
}

########################
tag_and_push_follower_images() {
  for img_name in "${LOCAL_LAB_IMAGES[@]}"; do
    docker tag $LOCAL_APPLIANCE_IMAGE $PUSH_APPLIANCE_IMAGE
    docker push $PUSH_APPLIANCE_IMAGE
  done
}

main "$@"
