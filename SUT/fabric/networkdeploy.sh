#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x

function network_up() {
    echo "Setting up fabric network"
    # Kube config
    echo "Step 1/4, basic k8s config"
    #init_namespace
    init_storage_volumes
    load_org_config

    # Network TLS CAs
    echo "Step 2/4, set up TLS CA"
    launch_TLS_CAs
    enroll_bootstrap_TLS_CA_users

    # Network ECert CAs
    echo "Step 3/4, set up ECert CA"
    register_enroll_ECert_CA_bootstrap_users
    launch_ECert_CAs
    enroll_bootstrap_ECert_CA_users

    # Test Network
    echo "Step 4/4, set up ECert CA"
    create_local_MSP
    launch_orderers
    launch_peers
    
    echo "Complete setting up fabric network"
}

function network_down() {
    echo "Tear down fabric network"
    kubectl -n $NS delete deployment --all
    kubectl -n $NS delete pod --all
    kubectl -n $NS delete service --all
    kubectl -n $NS delete configmap --all
    kubectl -n $NS delete secret --all
    kubectl -n $NS delete -f ./kube/job-scrub-fabric-volumes.yaml || true
    kubectl -n $NS create -f ./kube/job-scrub-fabric-volumes.yaml
    kubectl -n $NS wait --for=condition=complete --timeout=60s job/job-scrub-fabric-volumes || true
    kubectl -n $NS delete -f ./kube/job-scrub-fabric-volumes.yaml || true
    kubectl delete pvc fabric-org0 -n $NS || true
    kubectl delete pvc fabric-org1 -n $NS || true
    kubectl delete pvc fabric-org2 -n $NS || true
    kubectl delete -f ./kube/pv-fabric-org0.yaml || true
    kubectl delete -f ./kube/pv-fabric-org1.yaml || true
    kubectl delete -f ./kube/pv-fabric-org2.yaml || true
    #kubectl delete namespace $NS || true
    echo "Complete tear down fabric network"
}

function init_namespace() {
  echo "Creating namespace \"$NS\""
  #kubectl create namespace $NS || true
  echo "Complete namespace creation"
}


function init_storage_volumes() {
  echo "Provisioning volume storage"

  kubectl create -f ./kube/pv-fabric-org0.yaml || true
  kubectl create -f ./kube/pv-fabric-org1.yaml || true
  kubectl create -f ./kube/pv-fabric-org2.yaml || true

  kubectl -n $NS create -f ./kube/pvc-fabric-org0.yaml || true
  kubectl -n $NS create -f ./kube/pvc-fabric-org1.yaml || true
  kubectl -n $NS create -f ./kube/pvc-fabric-org2.yaml || true

  echo "Complete Provisioning volume storage"
}

function load_org_config() {
  echo "Creating fabric config maps"

  kubectl -n $NS delete configmap org0-config || true
  kubectl -n $NS delete configmap org1-config || true
  kubectl -n $NS delete configmap org2-config || true

  kubectl -n $NS create configmap org0-config --from-file=./config/org0
  kubectl -n $NS create configmap org1-config --from-file=./config/org1
  kubectl -n $NS create configmap org2-config --from-file=./config/org2

  echo "Complete fabric config maps"
}

function launch_CA() {
  local yaml=$1
  cat ${yaml} \
    | sed 's,{{LOCAL_CONTAINER_REGISTRY}},'${LOCAL_CONTAINER_REGISTRY}',g' \
    | sed 's,{{FABRIC_CA_VERSION}},'${FABRIC_CA_VERSION}',g' \
    | kubectl -n $NS apply -f -
}

function launch_TLS_CAs() {
  echo "Launching TLS CAs"
  launch_CA kube/org0/org0-tls-ca.yaml
  launch_CA kube/org1/org1-tls-ca.yaml
  launch_CA kube/org2/org2-tls-ca.yaml

  kubectl -n $NS rollout status deploy/org0-tls-ca
  kubectl -n $NS rollout status deploy/org1-tls-ca
  kubectl -n $NS rollout status deploy/org2-tls-ca

  # todo: this papers over a nasty bug whereby the CAs are ready, but sporadically refuse connections after a down / up
  sleep 10
  echo "Complete launching TLS CAs"
}

function enroll_bootstrap_TLS_CA_users() {
  echo "Enrolling bootstrap TLS CA users"

  enroll_bootstrap_TLS_CA_user org0 $TLSADMIN_AUTH
  enroll_bootstrap_TLS_CA_user org1 $TLSADMIN_AUTH
  enroll_bootstrap_TLS_CA_user org2 $TLSADMIN_AUTH

  echo "Complete Enrolling bootstrap TLS CA users"
}

function enroll_bootstrap_TLS_CA_user() {
  local org=$1
  local auth=$2
  local tlsca=${org}-tls-ca

  # todo: get rid of export here - put in yaml

  echo 'set -x

  mkdir -p $FABRIC_CA_CLIENT_HOME/tls-root-cert
  cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem

  fabric-ca-client enroll \
    --url https://'$auth'@'${tlsca}' \
    --tls.certfiles $FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem \
    --csr.hosts '${tlsca}' \
    --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp

  ' | exec kubectl -n $NS exec deploy/${tlsca} -i -- /bin/sh
}

function register_enroll_ECert_CA_bootstrap_users() {
  echo "Registering and enrolling ECert CA bootstrap users"

  register_enroll_ECert_CA_bootstrap_user org0 $TLSADMIN_AUTH
  register_enroll_ECert_CA_bootstrap_user org1 $TLSADMIN_AUTH
  register_enroll_ECert_CA_bootstrap_user org2 $TLSADMIN_AUTH

  echo "Complete registering and enrolling ECert CA bootstrap users"
}

function register_enroll_ECert_CA_bootstrap_user() {
  local org=$1
  local tlsauth=$2
  local tlsca=${org}-tls-ca
  local ecertca=${org}-ecert-ca

  echo 'set -x

  fabric-ca-client register \
    --id.name rcaadmin \
    --id.secret rcaadminpw \
    --url https://'${tlsca}' \
    --tls.certfiles $FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem \
    --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp

  fabric-ca-client enroll \
    --url https://'${tlsauth}'@'${tlsca}' \
    --tls.certfiles $FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem \
    --csr.hosts '${ecertca}' \
    --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin/msp

  # Important: the rcaadmin signing certificate is referenced by the ECert CA FABRIC_CA_SERVER_TLS_CERTFILE config attribute.
  # For simplicity, reference the key at a fixed, known location
  cp $FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin/msp/keystore/*_sk $FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin/msp/keystore/key.pem

  ' | exec kubectl -n $NS exec deploy/${tlsca} -i -- /bin/sh
}

function launch_ECert_CAs() {
  echo "Launching ECert CAs"

  launch_CA kube/org0/org0-ecert-ca.yaml
  launch_CA kube/org1/org1-ecert-ca.yaml
  launch_CA kube/org2/org2-ecert-ca.yaml

  kubectl -n $NS rollout status deploy/org0-ecert-ca
  kubectl -n $NS rollout status deploy/org1-ecert-ca
  kubectl -n $NS rollout status deploy/org2-ecert-ca

  # todo: this papers over a nasty bug whereby the CAs are ready, but sporadically refuse connections after a down / up
  sleep 10

  echo "Complete Launch ECert CAs"
}

function enroll_bootstrap_ECert_CA_users() {
  echo "Enrolling bootstrap ECert CA users"

  enroll_bootstrap_ECert_CA_user org0 $RCAADMIN_AUTH
  enroll_bootstrap_ECert_CA_user org1 $RCAADMIN_AUTH
  enroll_bootstrap_ECert_CA_user org2 $RCAADMIN_AUTH

  echo "Complete Enrolling bootstrap ECert CA users"
}

function enroll_bootstrap_ECert_CA_user() {
  local org=$1
  local auth=$2
  local ecert_ca=${org}-ecert-ca

  echo 'set -x

  fabric-ca-client enroll \
    --url https://'${auth}'@'${ecert_ca}' \
    --tls.certfiles $FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem \
    --mspdir $FABRIC_CA_CLIENT_HOME/'${ecert_ca}'/rcaadmin/msp

  ' | exec kubectl -n $NS exec deploy/${ecert_ca} -i -- /bin/sh
}

function create_local_MSP() {
  echo "Creating local node MSP"

  create_org0_local_MSP
  create_org1_local_MSP
  create_org2_local_MSP

  echo "Complete creating local node MSP"
}


function create_org0_local_MSP() {
  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name org0-orderer1 --id.secret ordererpw --id.type orderer --url https://org0-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name org0-orderer2 --id.secret ordererpw --id.type orderer --url https://org0-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name org0-orderer3 --id.secret ordererpw --id.type orderer --url https://org0-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name org0-admin --id.secret org0adminpw  --id.type admin   --url https://org0-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ecert-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  fabric-ca-client enroll --url https://org0-orderer1:ordererpw@org0-ecert-ca --csr.hosts org0-orderer1 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp
  fabric-ca-client enroll --url https://org0-orderer2:ordererpw@org0-ecert-ca --csr.hosts org0-orderer2 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer2.org0.example.com/msp
  fabric-ca-client enroll --url https://org0-orderer3:ordererpw@org0-ecert-ca --csr.hosts org0-orderer3 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer3.org0.example.com/msp
  fabric-ca-client enroll --url https://org0-admin:org0adminpw@org0-ecert-ca --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/users/Admin@org0.example.com/msp

  # Each node in the network needs a TLS registration and enrollment.
  fabric-ca-client register --id.name org0-orderer1 --id.secret ordererpw --id.type orderer --url https://org0-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp
  fabric-ca-client register --id.name org0-orderer2 --id.secret ordererpw --id.type orderer --url https://org0-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp
  fabric-ca-client register --id.name org0-orderer3 --id.secret ordererpw --id.type orderer --url https://org0-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp

  fabric-ca-client enroll --url https://org0-orderer1:ordererpw@org0-tls-ca --csr.hosts org0-orderer1 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/tls
  fabric-ca-client enroll --url https://org0-orderer2:ordererpw@org0-tls-ca --csr.hosts org0-orderer2 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer2.org0.example.com/tls
  fabric-ca-client enroll --url https://org0-orderer3:ordererpw@org0-tls-ca --csr.hosts org0-orderer3 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer3.org0.example.com/tls

  # Copy the TLS signing keys to a fixed path for convenience when starting the orderers.
  cp /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/tls/keystore/server.key
  cp /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer2.org0.example.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer2.org0.example.com/tls/keystore/server.key
  cp /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer3.org0.example.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer3.org0.example.com/tls/keystore/server.key

  # Create an MSP config.yaml (why is this not generated by the enrollment by fabric-ca-client?)
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/org0-ecert-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/org0-ecert-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/org0-ecert-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/org0-ecert-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp/config.yaml

  cp /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer2.org0.example.com/msp/config.yaml
  cp /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer3.org0.example.com/msp/config.yaml
  ' | exec kubectl -n $NS exec deploy/org0-ecert-ca -i -- /bin/sh
}

function create_org1_local_MSP() {

  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name org1-peer1 --id.secret peerpw --id.type peer --url https://org1-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org1-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name org1-peer2 --id.secret peerpw --id.type peer --url https://org1-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org1-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name org1-admin --id.secret org1adminpw  --id.type admin   --url https://org1-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org1-ecert-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  fabric-ca-client enroll --url https://org1-peer1:peerpw@org1-ecert-ca --csr.hosts org1-peer1 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp
  fabric-ca-client enroll --url https://org1-peer2:peerpw@org1-ecert-ca --csr.hosts org1-peer2 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer2.org1.example.com/msp
  fabric-ca-client enroll --url https://org1-admin:org1adminpw@org1-ecert-ca  --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp

  # Each node in the network needs a TLS registration and enrollment.
  fabric-ca-client register --id.name org1-peer1 --id.secret peerpw --id.type peer --url https://org1-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp
  fabric-ca-client register --id.name org1-peer2 --id.secret peerpw --id.type peer --url https://org1-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp

  fabric-ca-client enroll --url https://org1-peer1:peerpw@org1-tls-ca --csr.hosts org1-peer1 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/tls
  fabric-ca-client enroll --url https://org1-peer2:peerpw@org1-tls-ca --csr.hosts org1-peer2 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer2.org1.example.com/tls

  # Copy the TLS signing keys to a fixed path for convenience when launching the peers
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/tls/keystore/server.key
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer2.org1.example.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer2.org1.example.com/tls/keystore/server.key

  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/server.key

  # Create local MSP config.yaml
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/org1-ecert-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/org1-ecert-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/org1-ecert-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/org1-ecert-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp/config.yaml


  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer2.org1.example.com/msp/config.yaml
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/config.yaml
  ' | exec kubectl -n $NS exec deploy/org1-ecert-ca -i -- /bin/sh

}

function create_org2_local_MSP() {
  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name org2-peer1 --id.secret peerpw --id.type peer --url https://org2-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org2-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name org2-peer2 --id.secret peerpw --id.type peer --url https://org2-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org2-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name org2-admin --id.secret org2adminpw  --id.type admin   --url https://org2-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/org2-ecert-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  fabric-ca-client enroll --url https://org2-peer1:peerpw@org2-ecert-ca --csr.hosts org2-peer1 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp
  fabric-ca-client enroll --url https://org2-peer2:peerpw@org2-ecert-ca --csr.hosts org2-peer2 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer2.org2.example.com/msp
  fabric-ca-client enroll --url https://org2-admin:org2adminpw@org2-ecert-ca  --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp

  # Each node in the network needs a TLS registration and enrollment.
  fabric-ca-client register --id.name org2-peer1 --id.secret peerpw --id.type peer --url https://org2-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp
  fabric-ca-client register --id.name org2-peer2 --id.secret peerpw --id.type peer --url https://org2-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp

  fabric-ca-client enroll --url https://org2-peer1:peerpw@org2-tls-ca --csr.hosts org2-peer1 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/tls
  fabric-ca-client enroll --url https://org2-peer2:peerpw@org2-tls-ca --csr.hosts org2-peer2 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer2.org2.example.com/tls

  # Copy the TLS signing keys to a fixed path for convenience when launching the peers
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/tls/keystore/server.key
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer2.org2.example.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer2.org2.example.com/tls/keystore/server.key

  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/keystore/server.key

  # Create local MSP config.yaml
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/org2-ecert-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/org2-ecert-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/org2-ecert-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/org2-ecert-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp/config.yaml

  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer2.org2.example.com/msp/config.yaml
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/config.yaml
  ' | exec kubectl -n $NS exec deploy/org2-ecert-ca -i -- /bin/sh
}


function launch() {
  local yaml=$1
  cat ${yaml} \
    | sed 's,{{LOCAL_CONTAINER_REGISTRY}},'${LOCAL_CONTAINER_REGISTRY}',g' \
    | sed 's,{{FABRIC_VERSION}},'${FABRIC_VERSION}',g' \
    | kubectl -n $NS apply -f -
}

function clean_up_old_rs() {
  target_rs=$1
  echo "${target_rs}"
  kubectl get rs | grep $target_rs
  for rs in `kubectl get rs | grep $target_rs`; do
        kubectl delete rs $rs || true
  done   
}

function launch_orderers() {
  echo "Launching orderers"

  launch ./kube/org0/org0-orderer1.yaml
  sleep 10
  clean_up_old_rs org0-orderer
  kubectl -n $NS rollout status deploy/org0-orderer1

  launch ./kube/org0/org0-orderer2.yaml
  sleep 10
  clean_up_old_rs org0-orderer2
  kubectl -n $NS rollout status deploy/org0-orderer2

  launch ./kube/org0/org0-orderer3.yaml
  sleep 10
  clean_up_old_rs org0-orderer3
  kubectl -n $NS rollout status deploy/org0-orderer3

  echo "Complete launching orderers"
}

function launch_peers() {
  echo "Launching peers"

  launch ./kube/org1/org1-peer1.yaml
  sleep 10
  clean_up_old_rs org1-peer1
  kubectl -n $NS rollout status deploy/org1-peer1

  launch ./kube/org1/org1-peer2.yaml
  sleep 10
  clean_up_old_rs org1-peer2
  kubectl -n $NS rollout status deploy/org1-peer2

  launch ./kube/org2/org2-peer1.yaml
  sleep 10
  clean_up_old_rs org2-peer1
  kubectl -n $NS rollout status deploy/org2-peer1

  launch ./kube/org2/org2-peer2.yaml
  sleep 10
  clean_up_old_rs org2-peer2
  kubectl -n $NS rollout status deploy/org2-peer2

  echo "Complete launching peers"
}

function jaeger() {
  echo "Restart jaeger"
  kubectl delete Jaeger simplest
kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
EOF
nohup kubectl port-forward svc/simplest-query 16686 &
  echo "Complete restart jaeger"
}