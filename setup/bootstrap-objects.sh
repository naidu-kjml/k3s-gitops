#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

kapply() {
  if output=$(envsubst < "$@"); then
    printf '%s' "$output" | kubectl apply -f -
  fi
}

ksecret() {
  if output=$(envsubst < "$2"); then
    # NAMESPACE_READY=1
    # while [ $NAMESPACE_READY != 0 ]; do
    #   echo "waiting for $1 namespace to be ready"
    #   ready=$(kubectl get ns --output=name | grep "$1")
    #   if [ -n $ready ]
    #   then
    #     NAMESPACE_READY=0
    #   fi
    #   sleep 5
    # done
    kubectl create secret generic -n "$1" "$1"-helm-values --from-literal=values.yaml="$output"
  fi
}

installManualObjects(){
  message "installing manual secrets and objects"

  #########################
  # cert-manager bootstrap
  #########################
  kapply "$REPO_ROOT"/kube-system/cert-manager/cloudflare-api-key.txt
  CERT_MANAGER_READY=1
  while [ $CERT_MANAGER_READY != 0 ]; do
    echo "waiting for cert-manager to be fully ready..."
    kubectl -n kube-system wait --for condition=Available deployment/cert-manager > /dev/null 2>&1
    CERT_MANAGER_READY="$?"
    sleep 5
  done
  kapply "$REPO_ROOT"/kube-system/cert-manager/letsencrypt-issuer.txt
}

installValuesSecrets() {
  message "creating helm values secrets"

  ksecret pihole "$REPO_ROOT"/pihole/pihole-values-secret.txt
  ksecret openfaas "$REPO_ROOT"/openfaas/openfaas-values-secret.txt
}

. "$REPO_ROOT"/setup/.env

installManualObjects
installValuesSecrets

message "all done!"