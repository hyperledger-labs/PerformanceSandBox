#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x

function chaincode_deploy() {
    echo "starting chaincode deployment"
    install_chaincode
    launch_chaincode_service org1 $CHAINCODE_ID $CHAINCODE_IMAGE
    activate_chaincode
    echo "complete chaincode deployment"
}

function chaincode_invoke() {
    echo "invoking chaincode"
    echo $@
    echo '
    export CORE_PEER_ADDRESS=org1-peer1:7051
    peer chaincode \
        invoke \
        -o org0-orderer1:6050 \
        --tls --cafile /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/msp/tlscacerts/org0-tls-ca.pem \
        -n '${CHAINCODE_NAME}' \
        -C '${CHANNEL_NAME}' \
        -c '"'$@'"'
    ' | exec kubectl -n $NS exec deploy/org1-admin-cli -c main -i -- /bin/bash

    sleep 2
    echo "complete invoking chaincode"
}

function chaincode_query() {
    echo "query chaincode"
    echo '
    export CORE_PEER_ADDRESS=org1-peer1:7051
    peer chaincode query -n '${CHAINCODE_NAME}' -C '${CHANNEL_NAME}' -c '"'$@'"'
    ' | exec kubectl -n $NS exec deploy/org1-admin-cli -c main -i -- /bin/bash
    echo "complete query chaincode"
}

# Package and install the chaincode, but do not activate.
function install_chaincode() {
  local org=org1

  package_chaincode_for ${org}
  transfer_chaincode_archive_for ${org}
  install_chaincode_for ${org}

  set_chaincode_id
}

function package_chaincode_for() {
  local org=$1
  local cc_folder="chaincode/${CHAINCODE_NAME}"
  local build_folder="./build/chaincode"
  local cc_archive="${build_folder}/${CHAINCODE_NAME}.tgz"
  echo "Packaging chaincode folder ${cc_folder}"

  mkdir -p ${build_folder}

  tar -C ${cc_folder} -zcf ${cc_folder}/code.tar.gz connection.json
  tar -C ${cc_folder} -zcf ${cc_archive} code.tar.gz metadata.json

  rm ${cc_folder}/code.tar.gz
}

function transfer_chaincode_archive_for() {
  local org=$1
  local cc_archive="build/chaincode/${CHAINCODE_NAME}.tgz"
  echo "Transferring chaincode archive to ${org}"

  # Like kubectl cp, but targeted to a deployment rather than an individual pod.
  tar cf - ${cc_archive} | kubectl -n $NS exec -i deploy/${org}-admin-cli -c main -- tar xvf -
}

function install_chaincode_for() {
  local org=$1
  echo "Installing chaincode for org ${org}"

  # Install the chaincode
  echo 'set -x
  export CORE_PEER_ADDRESS='${org}'-peer1:7051
  peer lifecycle chaincode install build/chaincode/'${CHAINCODE_NAME}'.tgz
  ' | exec kubectl -n $NS exec deploy/${org}-admin-cli -c main -i -- /bin/bash
}

function set_chaincode_id() {
  local cc_sha256=$(shasum -a 256 build/chaincode/${CHAINCODE_NAME}.tgz | tr -s ' ' | cut -d ' ' -f 1)

  CHAINCODE_ID=${CHAINCODE_LABEL}:${cc_sha256}
}

function launch_chaincode_service() {
  local org=$1
  local cc_id=$2
  local cc_image=$3
  echo "Launching chaincode container \"${cc_image}\""

  # The chaincode endpoint needs to have the generated chaincode ID available in the environment.
  # This could be from a config map, a secret, or by directly editing the deployment spec.  Here we'll keep
  # things simple by using sed to substitute script variables into a yaml template.
  cat kube/${org}/${org}-cc-template.yaml \
    | sed 's,{{CHAINCODE_NAME}},'${CHAINCODE_NAME}',g' \
    | sed 's,{{CHAINCODE_ID}},'${cc_id}',g' \
    | sed 's,{{CHAINCODE_IMAGE}},'${cc_image}',g' \
    | exec kubectl -n $NS apply -f -

  kubectl -n $NS rollout status deploy/${org}-cc-${CHAINCODE_NAME}
}

function activate_chaincode() {
  set_chaincode_id
  activate_chaincode_for org1 $CHAINCODE_ID
}

function activate_chaincode_for() {
  local org=$1
  local cc_id=$2
  echo "Activating chaincode ${CHAINCODE_ID}"

  echo 'set -x 
  export CORE_PEER_ADDRESS='${org}'-peer1:7051
  
  peer lifecycle \
    chaincode approveformyorg \
    --channelID '${CHANNEL_NAME}' \
    --name '${CHAINCODE_NAME}' \
    --version 1 \
    --package-id '${cc_id}' \
    --sequence 1 \
    -o org0-orderer1:6050 \
    --tls --cafile /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/msp/tlscacerts/org0-tls-ca.pem
  
  peer lifecycle \
    chaincode commit \
    --channelID '${CHANNEL_NAME}' \
    --name '${CHAINCODE_NAME}' \
    --version 1 \
    --sequence 1 \
    -o org0-orderer1:6050 \
    --tls --cafile /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/msp/tlscacerts/org0-tls-ca.pem
  ' | exec kubectl -n $NS exec deploy/${org}-admin-cli -c main -i -- /bin/bash

  echo "Complete activating chaincode ${CHAINCODE_ID}"
}