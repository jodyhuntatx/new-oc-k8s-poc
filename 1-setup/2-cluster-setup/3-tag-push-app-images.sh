#!/bin/bash

source ../../dap-service.config

LOCAL_LAB_IMAGES=(
  $LOCAL_APP_IMAGE
  $LOCAL_AUTHENTICATOR_IMAGE
  $LOCAL_SECRETS_PROVIDER_IMAGE
  $LOCAL_SECRETLESS_CLIENT
  $LOCAL_SECRETLESS_BROKER_IMAGE
)

main() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI login -u $CYBERARK_NAMESPACE_ADMIN
  fi
  check_local_lab_image_tags
  tag_and_push_lab_images
}

#############################
check_local_lab_image_tags() {
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

#############################
tag_and_push_lab_images() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    docker login -u $($CLI whoami) -p $($CLI whoami -t) $EXTERNAL_REGISTRY_URL
  fi
  all_found=true
  for img_name in "${LOCAL_LAB_IMAGES[@]}"; do
	docker tag $img_name $EXTERNAL_REGISTRY_URL/$CYBERARK_NAMESPACE_NAME/$img_name
        docker push $EXTERNAL_REGISTRY_URL/$CYBERARK_NAMESPACE_NAME/$img_name
  done
}

main "$@"
