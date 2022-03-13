#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x

NS=default

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

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
  local ORG=$1
  local PP=$(one_line_pem $2)
  local CP=$(one_line_pem $3)
  sed -e "s/\${ORG}/$ORG/" \
      -e "s#\${PEERPEM}#$PP#" \
      -e "s#\${CAPEM}#$CP#" \
      scripts/ccp-template.json
}

function construct_rest_sample_configmap() {
  echo "Constructing fabric-rest-sample connection profiles"

  extract_MSP_archives

  mkdir -p build/fabric-rest-sample-config

  local peer_pem=build/msp/organizations/peerOrganizations/org1.example.com/msp/tlscacerts/org1-tls-ca.pem
  local ca_pem=build/msp/organizations/peerOrganizations/org1.example.com/msp/cacerts/org1-ecert-ca.pem

  echo "$(json_ccp 1 $peer_pem $ca_pem)" > build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG1
  cat build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG1
  
  peer_pem=build/msp/organizations/peerOrganizations/org2.example.com/msp/tlscacerts/org2-tls-ca.pem
  ca_pem=build/msp/organizations/peerOrganizations/org2.example.com/msp/cacerts/org2-ecert-ca.pem

  echo "$(json_ccp 2 $peer_pem $ca_pem)" > build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG2
  cat build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG2

  cat build/msp/organizations/peerOrganizations/org1.example.com/users/Admin\@org1.example.com/msp/signcerts/cert.pem > build/fabric-rest-sample-config/HLF_CERTIFICATE_ORG1
  cat build/msp/organizations/peerOrganizations/org2.example.com/users/Admin\@org2.example.com/msp/signcerts/cert.pem > build/fabric-rest-sample-config/HLF_CERTIFICATE_ORG2

  cat build/msp/organizations/peerOrganizations/org1.example.com/users/Admin\@org1.example.com/msp/keystore/server.key > build/fabric-rest-sample-config/HLF_PRIVATE_KEY_ORG1
  cat build/msp/organizations/peerOrganizations/org2.example.com/users/Admin\@org2.example.com/msp/keystore/server.key > build/fabric-rest-sample-config/HLF_PRIVATE_KEY_ORG2

  kubectl -n $NS delete configmap fabric-rest-sample-config || true

  kubectl -n $NS create configmap fabric-rest-sample-config --from-file=build/fabric-rest-sample-config/

  echo "Compelte Constructing fabric-rest-sample connection profiles"
}

function rollout_rest_sample() {
  echo "Starting fabric-rest-sample"

  kubectl -n $NS apply -f ./kube/fabric-rest-sample.yaml
  kubectl -n $NS rollout status deploy/fabric-rest-sample

  echo "Complete fabric-rest-sample"
}

echo "begin deploy sample app"

construct_rest_sample_configmap
rollout_rest_sample

echo "end sample app deployment"
echo "to access app from ui: kubectl port-forward svc/fabric-rest-sample 3001:3000"