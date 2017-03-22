#!/bin/bash
set -e


################################################################################
################################################################################
# BASE CONFIGURATION                                                           #
################################################################################
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
SCRIPT_NAME=$(basename $0)
BASE_DIR=$(cd $SCRIPT_DIR/.. && pwd)
MODULE_NAME=sso

if [ ! -f ${BASE_DIR}/common/common.sh ]; then
  echo "Missing file ../common/common.sh. Please make sure that all required modules are downloaded or run the download.sh script from $BASE_DIR."
  exit
fi

source ${BASE_DIR}/common/common.sh

################################################################################
# FUNCTIONS                                                                    #
################################################################################



################################################################################
# MAIN: DEPLOY                                                                 #
################################################################################

pushd $SCRIPT_DIR > /dev/null


# Service specific commands
echo_header "Creating the build configuration and image stream"

oc get bc/$MODULE_NAME 2>/dev/null | grep -q "^$MODULE_NAME" && echo "A build config for $MODULE_NAME already exists, skipping" || { oc new-build --strategy=docker --binary --name=$MODULE_NAME > /dev/null; }

echo_header "Starting build"
oc get builds 2>/dev/null | grep "^$MODULE_NAME" | grep -q "Running" && echo "There is already a running build, skipping" || { oc start-build $MODULE_NAME --from-dir=s2i > /dev/null; }

wait_while_empty "$MODULE_NAME starting build" 600 "oc get builds 2>/dev/null| grep \"^$MODULE_NAME\" | grep Running"
wait_while_empty "$MODULE_NAME build" 600 "oc get builds 2>/dev/null| grep \"^$MODULE_NAME\" | tail -1 | grep -v Running"    

echo_header "Creating application"
oc get services 2>/dev/null | grep -q "^$MODULE_NAME" && echo "A service named $MODULE_NAME already exists, skipping" || { oc process -f main-template.yaml | oc create -f -  || true; }

wait_while_empty "$MODULE_NAME service to be running" 20 "oc get pods | grep -v build | grep -v postgresql | grep -v deploy | grep Running"
wait_while_empty "$MODULE_NAME service to be running" 600 "oc get pods | grep -v build | grep -v postgresql | grep -v deploy | grep Running | grep 1/1"

echo_header "Adding user and roles to SSO"
oc get configmaps 2>/dev/null | grep -q "sso-config-files" && echo "A configmap with named sso-config-file already exists, skipping" || oc create configmap sso-config-files --from-file=config
oc create -f config-sso.yaml

echo Done

popd  > /dev/null

















