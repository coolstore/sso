#!/bin/bash

set -e

function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}

function wait_while_empty() {
  local _NAME=$1
  local _TIMEOUT=$(($2/5))
  local _CONDITION=$3

  echo "Waiting for $_NAME to be ready..."
  local x=1
  while [ -z "$(eval ${_CONDITION})" ]
  do
    echo "."
    sleep 5
    x=$(( $x + 1 ))
    if [ $x -gt $_TIMEOUT ]
    then
      echo "$_NAME still not ready, I GIVE UP!"
      exit 255
    fi
  done

  echo "$_NAME is ready."
}


pushd $(cd $(dirname $0) && pwd) > /dev/null

APP_DIR=$(pwd)
APP_NAME=$(basename $0)

echo_header "Running pre-checks...."
oc status >/dev/null 2>&1 || { echo >&2  "You are not connected to OCP cluster, please login using oc login ... before running $APP_NAME!"; exit 1; }
mvn -v -q >/dev/null 2>&1 || { echo >&2 "Maven is required but not installed yet... aborting."; exit 2; }
oc version | grep openshift | grep -q "v3\.[4-9]" || { echo >&2 "Only OpenShift Container Platfrom 3.4 or later is supported"; exit 3; }

echo "[OK]"
echo
# Display project and server for user and sleep 2 seconds to allow user to abort if wrong user

oc project
echo "Press CTRL-C NOW if this is not correct!" 
sleep 4

# Service specific commands

echo_header "Creating the build configuration and image stream"

oc get bc/sso 2>/dev/null | grep -q "^sso" && echo "A build config for sso already exists, skipping" || { oc new-build --strategy=docker --binary --name=sso > /dev/null; }

echo_header "Starting build"
oc get builds 2>/dev/null | grep "^sso" | grep -q "Running" && echo "There is already a running build, skipping" || { oc start-build sso --from-dir=s2i > /dev/null; }

wait_while_empty "sso starting build" 600 "oc get builds 2>/dev/null| grep \"^sso\" | grep Running"
wait_while_empty "sso build" 600 "oc get builds 2>/dev/null| grep \"^sso\" | tail -1 | grep -v Running"    

# echo_header "Creating application"
# oc get svc/sso 2>/dev/null | grep -q "^sso" && echo "A service named sso already exists, skipping" || { oc new-app sso > /dev/null; }

# echo_header "Exposing the route"
# oc get route/sso 2>/dev/null | grep -q "^sso" && echo "A route named sso already exists, skipping" || { oc expose service sso > /dev/null; }



















