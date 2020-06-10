#!/bin/bash

source ../../dap-service.config

main() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    $CLI login -u $CYBERARK_NAMESPACE_ADMIN
  fi
  clean_follower
  if [[ "$1" == "clean" ]]; then
    exit 0
  fi
  mkdir -p ./manifests
  initialize_k8s_api_secrets
  verify_k8s_api_secrets 
  create_configmaps
  deploy_follower
}

########################
clean_follower() {
  $CLI delete -f ./manifests/dap-cm-manifest.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  $CLI delete -f ./manifests/follower-cm-manifest.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  $CLI delete -f ./manifests/follower-deployment-manifest.yaml -n $CYBERARK_NAMESPACE_NAME --ignore-not-found
  rm -f ./manifests/dap-cm-manifest.yaml ./manifests/follower-cm-manifest.yaml ./manifests/follower-deployment-manifest.yaml
}

########################
initialize_k8s_api_secrets() {
  SA_TOKEN_NAME="$($CLI get secrets -n $CYBERARK_NAMESPACE_NAME \
    | grep "dap-authn-service.*service-account-token" \
    | head -n1 \
    | awk '{print $1}')" && echo $SA_TOKEN_NAME

  # using SA_TOKEN_NAME from above step…
  echo "Adding DAP service account token as secret..."
  ../../get_set.sh set \
     conjur/authn-k8s/$CLUSTER_AUTHN_ID/kubernetes/service-account-token \
     $($CLI get secret -n $CYBERARK_NAMESPACE_NAME $SA_TOKEN_NAME -o json\
     | jq -r .data.token \
     | $BASE64D)

  # using SA_TOKEN_NAME from above step…
  echo
  echo
  echo "Adding ca cert as secret..."
  ../../get_set.sh set \
    conjur/authn-k8s/$CLUSTER_AUTHN_ID/kubernetes/ca-cert \
    "$($CLI get secret -n $CYBERARK_NAMESPACE_NAME $SA_TOKEN_NAME -o json \
      | jq -r '.data["ca.crt"]' \
      | $BASE64D)"

  echo
  echo
  echo "Adding k8s API URL as secret..."
  ../../get_set.sh set \
    conjur/authn-k8s/$CLUSTER_AUTHN_ID/kubernetes/api-url \
    "$($CLI config view --minify -o yaml | grep server | awk '{print $2}')"
}

########################
verify_k8s_api_secrets() {
  echo "Verifying K8s API values." 
  echo
  echo "Get k8s cert..."
  echo "$(../../get_set.sh get conjur/authn-k8s/$CLUSTER_AUTHN_ID/kubernetes/ca-cert)" > k8s.crt
  echo
  echo "Get DAP service account token..."
  TOKEN=$(../../get_set.sh get conjur/authn-k8s/$CLUSTER_AUTHN_ID/kubernetes/service-account-token)
  echo
  echo "Get K8s API URL..."
  API=$(../../get_set.sh get conjur/authn-k8s/$CLUSTER_AUTHN_ID/kubernetes/api-url)
  echo
  echo -n "Verified if 'ok': "
  curl -s --cacert k8s.crt --header "Authorization: Bearer ${TOKEN}" $API/healthz && echo
  rm k8s.crt && unset API TOKEN SA_TOKEN_NAME
}

########################
create_configmaps() {

  if $REMOTE_CONJUR_MASTER; then
    interpreter="ssh -i $SSH_PVT_KEY $SSH_USERNAME@$CONJUR_MASTER_HOSTNAME"
  else
    interpreter=bash
  fi

  # get DAP Master cert & indent w/ 4 spaces
  $interpreter <<EOF | awk '{ print "    " $0 }' > master-cert.indented
	sudo docker exec $CONJUR_MASTER_CONTAINER_NAME \
		cat /opt/conjur/etc/ssl/conjur.pem
EOF

  # Generate Follower cert in Master
  $interpreter <<EOF
	sudo docker exec $CONJUR_MASTER_CONTAINER_NAME \
		bash -c "evoke ca issue $CONJUR_FOLLOWER_SERVICE_NAME"
EOF
	
  # get DAP Follower cert & indent w/ 4 spaces
  $interpreter <<EOF | awk '{ print "    " $0 }' > follower-cert.indented
	sudo docker exec $CONJUR_MASTER_CONTAINER_NAME \
		cat /opt/conjur/etc/ssl/conjur-follower.pem
EOF

  # replace non-file values in configmap manifest
  sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" 				\
	./templates/dap-config-map-manifest.template.yaml 			\
    | sed -e "s#{{ CONJUR_MASTER_HOSTNAME }}#$CONJUR_MASTER_HOSTNAME#g" 	\
    | sed -e "s#{{ CYBERARK_NAMESPACE_NAME }}#$CYBERARK_NAMESPACE_NAME#g"	\
    | sed -e "s#{{ CLUSTER_AUTHN_ID }}#$CLUSTER_AUTHN_ID#g" 			\
    > ./temp1

  # Add Master cert to configmap manifest
  # (see: https://stackoverflow.com/questions/6790631/use-the-contents-of-a-file-to-replace-a-string-using-sed)
  sed -e '/{{ CONJUR_MASTER_CERTIFICATE }}/{
		s/{{ CONJUR_MASTER_CERTIFICATE }}//g
		r ./master-cert.indented
	}' ./temp1 					\
    > ./temp2

  # Add Follower cert to configmap manifest
  sed -e '/{{ CONJUR_FOLLOWER_CERTIFICATE }}/{
		s/{{ CONJUR_FOLLOWER_CERTIFICATE }}//g
		r ./follower-cert.indented
	}' ./temp2 					\
    > ./manifests/dap-cm-manifest.yaml
  rm ./temp? ./*.indented
  $CLI apply -f ./manifests/dap-cm-manifest.yaml -n $CYBERARK_NAMESPACE_NAME

  sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" 			\
	./templates/follower-config-map-manifest.template.yaml 		\
    | sed -e "s#{{ CONJUR_MASTER_HOSTNAME }}#$CONJUR_MASTER_HOSTNAME#g" \
    | sed -e "s#{{ CLUSTER_AUTHN_ID }}#$CLUSTER_AUTHN_ID#g" 		\
    | sed -e "s#{{ CONJUR_AUTHENTICATORS }}#$CONJUR_AUTHENTICATORS#g" 	\
    > ./manifests/follower-cm-manifest.yaml
  $CLI apply -f ./manifests/follower-cm-manifest.yaml -n $CYBERARK_NAMESPACE_NAME
}

########################
deploy_follower() {
  sed -e "s#{{ CONJUR_SEED_FETCHER_IMAGE }}#$REGISTRY_SEED_FETCHER_IMAGE#g" 	\
	./templates/follower-deployment-manifest.template.yaml 			\
    | sed -e "s#{{ CONJUR_APPLIANCE_IMAGE }}#$REGISTRY_APPLIANCE_IMAGE#g" 	\
    > ./manifests/follower-deployment-manifest.yaml
  $CLI apply -f ./manifests/follower-deployment-manifest.yaml -n $CYBERARK_NAMESPACE_NAME

  sleep 3
  follower_pod_name=$($CLI get pods -n $CYBERARK_NAMESPACE_NAME | grep conjur-follower | grep -v Terminating | tail -1 | awk '{print $1}')
  # Wait for Follower to initialize
  echo "Waiting until Follower is ready (about 40 secs)."
  sleep 3
  while [[ 'True' != $($CLI get po "$follower_pod_name" -n $CYBERARK_NAMESPACE_NAME -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}') ]]; do
    echo -n "."; sleep 3
  done
  echo ""
}

main "$@"
