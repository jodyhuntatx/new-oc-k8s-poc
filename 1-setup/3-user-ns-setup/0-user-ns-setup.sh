#!/bin/bash

source ../../dap-service.config

main() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI login -u $CLUSTER_ADMIN
  fi

  clean_user_labs
  if [[ "$1" == "clean" ]]; then
    exit 0
  fi

  create_lab_namespaces
  create_secrets_access_clusterrole

  if [[ "$PLATFORM" == "openshift" ]]; then
    update_htpasswd_file
    grant_user_access_to_dap_cm
    grant_user_access_to_lab_images
  fi
}

#############################
clean_user_labs() {
  for (( unum=1; unum<=$NUM_USER_NAMESPACES; unum++ ))
  do
    uname=$(echo user${unum})

    $CLI delete -f $uname-manifest.yaml -n $uname --ignore-not-found
    rm -f ./manifests/$uname-manifest.yaml > /dev/null
    $CLI delete ns $uname

    if [[ "$PLATFORM" == "openshift" ]]; then
      $CLI delete user $uname --ignore-not-found
      $CLI delete identity $LAB_HTPASS_PROVIDER:$uname --ignore-not-found
      $CLI delete -f ./manifests/$uname-dap-cm-rolebinding.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
      rm -f ./manifests/$uname-dap-cm-rolebinding.yaml
      rm -f users.htpasswd
    fi
  done

}

#############################
create_lab_namespaces() {

  # For OpenShift, use template that creates user
  NAMESPACE_TEMPLATE_FILE=./templates/APP_NAMESPACE-manifest.template.yaml
  if [[ "$PLATFORM" == "openshift" ]]; then
    NAMESPACE_TEMPLATE_FILE=./templates/APP_NAMESPACE-manifest-ocp.template.yaml
  fi

  for (( unum=1; unum<=$NUM_USER_NAMESPACES; unum++ ))	# apply manifest for namespace and user 
  do
    uname=$(echo user${unum})
    sed -e "s#{{ APP_NAMESPACE_NAME }}#$uname#g" 				\
	$NAMESPACE_TEMPLATE_FILE						\
    | sed -e "s#{{ APP_NAMESPACE_ADMIN }}#$uname#g"				\
    | sed -e "s#{{ CYBERARK_NAMESPACE_NAME }}#$CYBERARK_NAMESPACE_NAME#g" 	\
    > ./manifests/$uname-manifest.yaml
    $CLI apply -f ./manifests/$uname-manifest.yaml -n $uname
  done
}

#############################
create_secrets_access_clusterrole() {
  $CLI apply -f ./templates/secrets-access-clusterrole.template.yaml
}

#############################
# Update EXISTING htpasswd file for users
# Doc: https://docs.openshift.com/container-platform/4.4/authentication/identity_providers/configuring-htpasswd-identity-provider.html

update_htpasswd_file() {
  $CLI get secret $LAB_HTPASS_SECRET -ojsonpath={.data.htpasswd} -n openshift-config | $BASE64D > users.htpasswd
  if [[ $(du -k users.htpasswd | cut -f 1)  == 0 ]]; then
    echo "Password file users.htpasswd is empty."
    exit -1
  fi

  for (( unum=1; unum<=$NUM_USER_NAMESPACES; unum++ ))
  do
    uname=$(echo user${unum})
    passwd=$(echo user${unum})
    htpasswd -B -b users.htpasswd $uname $passwd
  done

  $CLI create secret generic $LAB_HTPASS_SECRET --from-file=htpasswd=users.htpasswd --dry-run -o yaml -n openshift-config | $CLI replace -f -
}

#############################
# Grant user namespace service accounts access to images in CYBERARK_NAMESPACE_NAME
grant_user_access_to_lab_images() {
  for (( unum=1; unum<=$NUM_USER_NAMESPACES; unum++ )); do
     $CLI policy add-role-to-group					\
	system:image-puller system:serviceaccounts:user$unum:default	\
	--namespace=$CYBERARK_NAMESPACE_NAME
     $CLI policy add-role-to-user			\
	system:image-auditor user$unum		\
	--namespace=$CYBERARK_NAMESPACE_NAME
  done
}

#############################
grant_user_access_to_dap_cm() {
  for (( unum=1; unum<=$NUM_USER_NAMESPACES; unum++ ))	# apply manifest for namespace and user 
  do
    uname=$(echo user${unum})
    sed -e "s#{{ APP_NAMESPACE_NAME }}#$uname#g" 				\
	./templates/dap-cm-rolebinding.template.yaml				\
    | sed -e "s#{{ APP_NAMESPACE_ADMIN }}#$uname#g"				\
    | sed -e "s#{{ CYBERARK_NAMESPACE_NAME }}#$CYBERARK_NAMESPACE_NAME#g" 	\
    > ./manifests/$uname-dap-cm-rolebinding.yaml
    $CLI apply -f ./manifests/$uname-dap-cm-rolebinding.yaml -n $CYBERARK_NAMESPACE_NAME
  done
}

main "$@"
