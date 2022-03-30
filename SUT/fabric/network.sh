#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x

NS=default
LOCAL_CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-hyperledger}
FABRIC_CA_VERSION=${TEST_NETWORK_FABRIC_CA_VERSION:-1.5.2}
FABRIC_VERSION=${TEST_NETWORK_FABRIC_VERSION:-2.4}
CHANNEL_NAME=${TEST_NETWORK_CHANNEL_NAME:-mychannel}
CHAINCODE_IMAGE=${TEST_NETWORK_CHAINCODE_IMAGE:-ghcr.io/hyperledgendary/fabric-ccaas-asset-transfer-basic}
CHAINCODE_NAME=${TEST_NETWORK_CHAINCODE_NAME:-asset-transfer-basic}
CHAINCODE_LABEL=${TEST_NETWORK_CHAINCODE_LABEL:-basic_1.0}
TLSADMIN_AUTH=tlsadmin:tlsadminpw
RCAADMIN_AUTH=rcaadmin:rcaadminpw

. ./networkdeploy.sh
. ./channel.sh
. ./chaincode.sh

function main() {
## Parse mode
    if [[ $# -lt 1 ]] ; then
        print_help
        exit 0
    else
        MODE=$1
        shift
    fi

    if [ "${MODE}" == "up" ]; then
        network_up
    elif [ "${MODE}" == "down" ]; then
        network_down
    elif [ "${MODE}" == "verify" ]; then
        verify
    elif [ "${MODE}" == "channel" ]; then
        create_channel
    elif [ "${MODE}" == "jaeger" ]; then
        jaeger
    elif [ "${MODE}" == "buildchaincode" ]; then
        buildchaincode $1
    elif [ "${MODE}" == "chaincode" ]; then
        action=$1
        shift
        
        if [ "${action}" == "deploy" ]; then
            chaincode_deploy
        elif [ "${action}" == "invoke" ]; then
            chaincode_invoke $@
        elif [ "${action}" == "query" ]; then
            chaincode_query $@
        else
            print_help
        fi
    else
        print_help
        exit 1
    fi
}

function print_help() {
    echo "./network.sh up for start fabric network"
    echo "./network.sh down for clean up"
    echo "./network.sh verify for checking all resources in namespace" 
    echo "./network.sh channel for create channel"
    echo "./network.sh chaincode deploy for deploy a chaincode to channel"
    echo "./network.sh channel invoke for send a tx"
    echo "./network.sh channel query for query data"
    echo "./network.sh jaeger for restart jaeger"
}

function verify() {
    kubectl get pv
    kubectl get pvc -n $NS
    kubectl get po -n $NS
    kubectl get svc -n $NS
}

main $*