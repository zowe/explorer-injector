#!/bin/bash -e

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

################################################################################
# This script will injector Atlas war files to testing server
# 
# Example: ./inject.sh -h
################################################################################

################################################################################
# constants
SCRIPT_NAME=$(basename "$0")
DEFAULT_TEST_SERVER_IP=172.30.0.1
DEFAULT_TEST_SERVER_PORT=22
DEFAULT_TEST_SERVER_USER=tstradm
DEFAULT_ATLAS_APPS_DIR=/zaas1/atlas/wlp/usr/servers/Atlas/apps
DEFAULT_RESTART_ATLAS=yes
DEFAULT_ATLAS_SERVICE_NAME=FEKATLS
DEFAULT_ATLAS_ROOT_DIR=/zaas1/atlas

# TEST_SERVER_USER=
TEST_SERVER_IP=$DEFAULT_TEST_SERVER_IP
TEST_SERVER_PORT=$DEFAULT_TEST_SERVER_PORT
TEST_SERVER_USER=$DEFAULT_TEST_SERVER_USER
ATLAS_APPS_DIR=$DEFAULT_ATLAS_APPS_DIR
RESTART_ATLAS=$DEFAULT_RESTART_ATLAS
ATLAS_SERVICE_NAME=$DEFAULT_ATLAS_SERVICE_NAME
ATLAS_ROOT_DIR=$DEFAULT_ATLAS_ROOT_DIR

# allow to exit by ctrl+c
function finish {
  echo "[${SCRIPT_NAME}] interrupted"
  exit 1
}
trap finish SIGINT

################################################################################
# parse parameters
function usage {
  echo "Inject latest Atlas artifactories to testing server."
  echo
  echo "Usage: $SCRIPT_NAME [OPTIONS]"
  echo
  echo "Options:"
  echo "  -h  Display this help message."
  echo "  -s  Test server IP. Optional, default is $DEFAULT_TEST_SERVER_IP."
  echo "  -p  Test server port. Optional, default is $DEFAULT_TEST_SERVER_PORT."
  echo "  -u  Test server username. Optional, default is $DEFAULT_TEST_SERVER_USER."
  echo "  -r  DO NOT restart Atlas after inject. By default service will be restarted."
  echo "  -a  Atlas apps directory. Optional, default is $DEFAULT_ATLAS_APPS_DIR."
  echo "  -z  Atlas root directory. Optional, default is $DEFAULT_ATLAS_ROOT_DIR."
  echo
  echo "Tip: for your convenience, you may put your public key to server authorized_keys."
  echo
}
while getopts ":hs:p:u:ra:z:" opt; do
  case $opt in
    h)
      usage
      exit 0
      ;;
    s)
      TEST_SERVER_IP=$OPTARG
      ;;
    p)
      TEST_SERVER_PORT=$OPTARG
      ;;
    u)
      TEST_SERVER_USER=$OPTARG
      ;;
    r)
      RESTART_ATLAS=no
      ;;
    a)
      ATLAS_APPS_DIR=$OPTARG
      ;;
    z)
      ATLAS_ROOT_DIR=$OPTARG
      ;;
    \?)
      echo "[${SCRIPT_NAME}][error] invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "[${SCRIPT_NAME}][error] invalid option argument: -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

################################################################################
# essential validations
if [ -z "$TEST_SERVER_IP" ]; then
  echo "[${SCRIPT_NAME}][error] test server is required."
  exit 1
fi
JFROG_EXISTS=$(which jfrog)
if [ -z "$JFROG_EXISTS" ]; then
  echo "[${SCRIPT_NAME}][error] jfrog CLI is required to run this script to download artifactories."
  echo "       Please visit https://jfrog.com/getcli/ and install."
  exit 1
fi

################################################################################
echo "[${SCRIPT_NAME}] Injecting Atlas to ${TEST_SERVER_USER}@${TEST_SERVER_IP}:${TEST_SERVER_PORT} ..."
echo "[${SCRIPT_NAME}]   - Atlas apps dir    : ${ATLAS_APPS_DIR}"
echo "[${SCRIPT_NAME}]   - restart Atlas     : ${RESTART_ATLAS}"
echo "[${SCRIPT_NAME}]   - Atlas service     : ${ATLAS_SERVICE_NAME}"
echo "[${SCRIPT_NAME}]   - Atlas root dir    : ${ATLAS_ROOT_DIR}"
echo

echo "################################################################################"
echo "Downloading war files ..."
echo
jfrog rt dl --spec=artifactory-download-spec.json

echo
echo "################################################################################"
echo "Uploading to test server ..."
echo
sftp -o BatchMode=no -o StrictHostKeyChecking=no -P ${TEST_SERVER_PORT} -b - ${TEST_SERVER_USER}@${TEST_SERVER_IP} << EOF
cd ${ATLAS_APPS_DIR}
put .tmp/atlas-server.war
put .tmp/explorer-mvs.war
put .tmp/explorer-uss.war
put .tmp/explorer-jes.war
ls -al
EOF

if [ "$RESTART_ATLAS" = "yes" ]; then
  echo
  echo "################################################################################"
  echo "Restarting Atlas on test server ..."
  echo
  SRVRPATH=
  if [ -n "$ATLAS_ROOT_DIR" ]; then
    SRVRPATH=",SRVRPATH='${ATLAS_ROOT_DIR}'"
  fi
  ssh -tt -o StrictHostKeyChecking=no -p ${TEST_SERVER_PORT} ${TEST_SERVER_USER}@${TEST_SERVER_IP} << EOF
cd /u/tstradm && \
  (opercmd "C ${ATLAS_SERVICE_NAME}" || true) && sleep 10 && \
  (opercmd "S ${ATLAS_SERVICE_NAME}${SRVRPATH}") || { echo "[restart-atlas] failed"; exit 1; }
echo "[restart-atlas] succeeds" && exit 0
EOF
fi

echo
echo "################################################################################"
echo "Done."
exit 0
