#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x

NS=default

function main() {
  #const tape config sample
  echo $1
  config_tape_sample $1
  #start tape
  rollout_tape_sample
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

function config_tape_sample() {
  echo "Starting tape configuration"
  # rm
  rm -rf ./build/tape
  # make dir
  mkdir -p ./build/tape

  # construct_rest_sample_configmap
  extract_MSP_archives

  cat ./build/msp/organizations/peerOrganizations/org1.example.com/msp/tlscacerts/org1-tls-ca.pem > ./build/tape/org1-tls-ca.pem
  cat ./build/msp/organizations/peerOrganizations/org2.example.com/msp/tlscacerts/org2-tls-ca.pem > ./build/tape/org2-tls-ca.pem
  cat ./build/msp/organizations/ordererOrganizations/org0.example.com/msp/tlscacerts/org0-tls-ca.pem > ./build/tape/org0-tls-ca.pem
  cat ./build/msp/organizations/peerOrganizations/org1.example.com/users/Admin\@org1.example.com/msp/signcerts/cert.pem > ./build/tape/HLF_CERTIFICATE_ORG1
  cat ./build/msp/organizations/peerOrganizations/org1.example.com/users/Admin\@org1.example.com/msp/keystore/server.key > ./build/tape/HLF_PRIVATE_KEY_ORG1
  # id
  # tls cert
  # config file
  cp ./scripts/tapetemplate ./build/tape/tapeconfig.yaml
  
  if [ "${1}" == "NFT" ]; then
    cp -f ./scripts/tapetemplateNFT ./build/tape/tapeconfig.yaml
  fi
  cp ./scripts/Logic.rego ./build/tape/Logic.rego

  kubectl -n $NS delete configmap fabric-tape-sample-config || true
  kubectl -n $NS create configmap fabric-tape-sample-config --from-file=./build/tape/
  # kube config
  echo "Complete tape configuration"
}

function rollout_tape_sample() {
  echo "Starting tape for traffic"

  # to do here, play as a job?
  # to do here part2, play as a distributed job?
  #kubectl -n $NS apply -f kube/fabric-tape-sample.yaml
  kubectl delete -f ./kube/fabric-tape-sample.yaml -n $NS || true
  kubectl apply -f ./kube/fabric-tape-sample.yaml -n $NS
  echo "Complete tape init"
}

main $1