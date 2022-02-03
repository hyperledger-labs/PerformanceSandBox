#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x

function create_channel() {
    echo "start fabric channel creation"
    create_channel_MSP
    aggregate_channel_MSP
    launch_admin_CLIs

    create_genesis_block
    join_peers
    echo "complete fabric channel creation"
}

function create_channel_org_MSP() {
  local org=$1
  local org_type=$2
  local ecert_ca=${org}-ecert-ca 
  
  echo 'set -x
 
  mkdir -p /var/hyperledger/fabric/organizations/'${org_type}'Organizations/'${org}'.example.com/msp/cacerts
  cp \
    $FABRIC_CA_CLIENT_HOME/'${ecert_ca}'/rcaadmin/msp/cacerts/'${ecert_ca}'.pem \
    /var/hyperledger/fabric/organizations/'${org_type}'Organizations/'${org}'.example.com/msp/cacerts
  
  mkdir -p /var/hyperledger/fabric/organizations/'${org_type}'Organizations/'${org}'.example.com/msp/tlscacerts
  cp \
    $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp/cacerts/'${org}'-tls-ca.pem \
    /var/hyperledger/fabric/organizations/'${org_type}'Organizations/'${org}'.example.com/msp/tlscacerts
  
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/'${ecert_ca}'.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/'${ecert_ca}'.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/'${ecert_ca}'.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/'${ecert_ca}'.pem
      OrganizationalUnitIdentifier: orderer "> /var/hyperledger/fabric/organizations/'${org_type}'Organizations/'${org}'.example.com/msp/config.yaml
      
  ' | exec kubectl -n $NS exec deploy/${ecert_ca} -i -- /bin/sh
}

function create_channel_MSP() {
  echo "Creating channel MSP"

  create_channel_org_MSP org0 orderer 
  create_channel_org_MSP org1 peer
  create_channel_org_MSP org2 peer

  echo "Complete creating channel MSP"
}


function aggregate_channel_MSP() {
  echo "Aggregating channel MSP"

  rm -rf ./build/msp/
  mkdir -p ./build/msp
  
  kubectl -n $NS exec deploy/org0-ecert-ca -- tar zcvf - -C /var/hyperledger/fabric organizations/ordererOrganizations/org0.example.com/msp > build/msp/msp-org0.example.com.tgz
  kubectl -n $NS exec deploy/org1-ecert-ca -- tar zcvf - -C /var/hyperledger/fabric organizations/peerOrganizations/org1.example.com/msp > build/msp/msp-org1.example.com.tgz
  kubectl -n $NS exec deploy/org2-ecert-ca -- tar zcvf - -C /var/hyperledger/fabric organizations/peerOrganizations/org2.example.com/msp > build/msp/msp-org2.example.com.tgz

  kubectl -n $NS delete configmap msp-config || true
  kubectl -n $NS create configmap msp-config --from-file=build/msp/

  echo "Complete aggregating channel MSP"
}

function launch_admin_CLIs() {
  echo "Launching admin CLIs"

  launch kube/org0/org0-admin-cli.yaml
  launch kube/org1/org1-admin-cli.yaml
  launch kube/org2/org2-admin-cli.yaml

  kubectl -n $NS rollout status deploy/org0-admin-cli
  kubectl -n $NS rollout status deploy/org1-admin-cli
  kubectl -n $NS rollout status deploy/org2-admin-cli

  echo "Complete Launching admin CLIs"
}

function create_genesis_block() {
  echo "Creating channel \"${CHANNEL_NAME}\""

  echo 'set -x
  configtxgen -profile TwoOrgsApplicationGenesis -channelID '${CHANNEL_NAME}' -outputBlock genesis_block.pb
  # configtxgen -inspectBlock genesis_block.pb
  
  osnadmin channel join --orderer-address org0-orderer1:9443 --channelID '${CHANNEL_NAME}' --config-block genesis_block.pb
  osnadmin channel join --orderer-address org0-orderer2:9443 --channelID '${CHANNEL_NAME}' --config-block genesis_block.pb
  osnadmin channel join --orderer-address org0-orderer3:9443 --channelID '${CHANNEL_NAME}' --config-block genesis_block.pb
  
  ' | exec kubectl -n $NS exec deploy/org0-admin-cli -i -- /bin/bash
  
  # todo: readiness / liveiness equivalent for channel ?    Needs a little bit to settle before peers can join. 
  sleep 10

  echo "Complete creating channel \"${CHANNEL_NAME}\""
}

function join_peers() {
  join_org_peers org1
  join_org_peers org2
}

function join_org_peers() {
  local org=$1
  echo "Joining ${org} peers to channel \"${CHANNEL_NAME}\""

  echo 'set -x
  # Fetch the genesis block from an orderer
  peer channel \
    fetch oldest \
    genesis_block.pb \
    -c '${CHANNEL_NAME}' \
    -o org0-orderer1:6050 \
    --tls --cafile /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/msp/tlscacerts/org0-tls-ca.pem

  # Join peer1 to the channel.
  CORE_PEER_ADDRESS='${org}'-peer1:7051 \
  peer channel \
    join \
    -b genesis_block.pb \
    -o org0-orderer1:6050 \
    --tls --cafile /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/msp/tlscacerts/org0-tls-ca.pem

  # Join peer2 to the channel.
  CORE_PEER_ADDRESS='${org}'-peer2:7051 \
  peer channel \
    join \
    -b genesis_block.pb \
    -o org0-orderer1:6050 \
    --tls --cafile /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/msp/tlscacerts/org0-tls-ca.pem

  ' | exec kubectl -n $NS exec deploy/${org}-admin-cli -i -- /bin/bash

  echo "Complete joining ${org} peers to channel \"${CHANNEL_NAME}\""
}