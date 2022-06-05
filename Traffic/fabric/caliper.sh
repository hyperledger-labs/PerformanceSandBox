#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x

NS=default

function main() {
  #const caliper config sample
  config_caliper_sample
  #start caliper
  rollout_caliper_sample
}

function extract_MSP_archives() {
# rm
  rm -rf ./build/msp
  mkdir -p ./build/msp

  kubectl -n $NS exec deploy/org1-ecert-ca -- tar zcf - -C /var/hyperledger/fabric organizations/peerOrganizations/org1.example.com/msp | tar zxf - -C build/msp
  kubectl -n $NS exec deploy/org2-ecert-ca -- tar zcf - -C /var/hyperledger/fabric organizations/peerOrganizations/org2.example.com/msp | tar zxf - -C build/msp
  kubectl -n $NS exec deploy/org0-ecert-ca -- tar zcf - -C /var/hyperledger/fabric organizations/ordererOrganizations/org0.example.com/msp | tar zxf - -C build/msp
  kubectl -n $NS exec deploy/org1-ecert-ca -- tar zcf - -C /var/hyperledger/fabric organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp | tar zxf - -C build/msp
  kubectl -n $NS exec deploy/org2-ecert-ca -- tar zcf - -C /var/hyperledger/fabric organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp | tar zxf - -C build/msp
}

function config_caliper_sample() {
  echo "Starting caliper configuration"
  # rm
  rm -rf ./build/caliper
  # make dir
  mkdir -p ./build/caliper

  # construct_rest_sample_configmap
  extract_MSP_archives

  cat ./build/msp/organizations/peerOrganizations/org1.example.com/msp/tlscacerts/org1-tls-ca.pem > ./build/caliper/org1-tls-ca.pem
  cat ./build/msp/organizations/peerOrganizations/org1.example.com/msp/cacerts/org1-ecert-ca.pem > ./build/caliper/org1-ecert-ca.pem
  cat ./build/msp/organizations/peerOrganizations/org1.example.com/users/Admin\@org1.example.com/msp/signcerts/cert.pem > ./build/caliper/HLF_CERTIFICATE_ORG1
  cat ./build/msp/organizations/peerOrganizations/org1.example.com/users/Admin\@org1.example.com/msp/keystore/server.key > ./build/caliper/HLF_PRIVATE_KEY_ORG1
  # id
  # tls cert
  # config file
  cp ./scripts/caliperconnection.yaml ./build/caliper/connection.yaml
  cp ./scripts/readAsset.js ./build/caliper/readAsset.js
  cp ./scripts/networkConfig.yaml ./build/caliper/networkConfig.yaml
  cp ./scripts/myAssetBenchmark.yaml ./build/caliper/myAssetBenchmark.yaml

  kubectl -n $NS delete configmap fabric-caliper-sample-config || true
  kubectl -n $NS create configmap fabric-caliper-sample-config --from-file=./build/caliper/
  # kube config
  echo "Complete caliper configuration"
}

function rollout_caliper_sample() {
  echo "Starting caliper for traffic"

  # to do here, play as a job?
  # to do here part2, play as a distributed job?
  #kubectl -n $NS apply -f kube/fabric-tape-sample.yaml
  kubectl delete -f ./kube/fabric-caliper-sample.yaml -n $NS || true
  kubectl apply -f ./kube/fabric-caliper-sample.yaml -n $NS
  echo "Complete caliper init"
}

main