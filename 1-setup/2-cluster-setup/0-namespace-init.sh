#!/bin/bash

source ../../dap-service.config

main() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI login -u $CLUSTER_ADMIN
  fi
  clean_namespace
  if [[ "$1" == "clean" ]]; then
    exit 0
  fi
  init_namespace
}

########################
clean_namespace() {
  $CLI delete -f ./manifests/$CYBERARK_NAMESPACE_NAME-manifest.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  rm -f ./manifests/$CYBERARK_NAMESPACE_NAME-manifest.yaml
}

########################
init_namespace() {
  sed -e "s#{{ CYBERARK_NAMESPACE_NAME }}#$CYBERARK_NAMESPACE_NAME#g" 			\
	./templates/CYBERARK-manifest.template.yaml					\
  | sed -e "s#{{ CYBERARK_NAMESPACE_ADMIN }}#$CYBERARK_NAMESPACE_ADMIN#g" 		\
  > ./manifests/$CYBERARK_NAMESPACE_NAME-manifest.yaml
  $CLI apply -f ./manifests/$CYBERARK_NAMESPACE_NAME-manifest.yaml -n $CYBERARK_NAMESPACE_NAME

  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI adm policy add-scc-to-user anyuid -z dap-authn-service -n $CYBERARK_NAMESPACE_NAME
  fi
}

main "$@"
