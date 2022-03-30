# So far just supports for Hyperledger Fabric
Current sample learn from test-network-k8s in fabric-sample

## Usage
Launch the network, create a channel, and deploy the [basic-asset-transfer](./asset-transfer-basic) smart contract: 
```shell
cd ./SUT/fabric
./network.sh up
./network.sh channel
```

<details>
<summary>Click here to use your own chaincode as sample as NFT</summary>

```shell
export TEST_NETWORK_CHAINCODE_IMAGE=localhost:5000/nftsample:latest
export TEST_NETWORK_CHAINCODE_NAME=nftsample
export TEST_NETWORK_CHAINCODE_LABEL=nft_1.0
./network.sh buildchaincode ./chaincode/nftsamplecode
```
</details>

```shell
./network.sh chaincode deploy
```

Invoke and query chaincode:
```shell
cd ./SUT/fabric
./network.sh chaincode invoke '{"Args":["CreateAsset","5","blue","35","tom","1000"]}' 
./network.sh chaincode query '{"Args":["ReadAsset","5"]}'
```

## Customization
All customization parameters:
```shell
LOCAL_CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-hyperledger}
FABRIC_CA_VERSION=${TEST_NETWORK_FABRIC_CA_VERSION:-1.5.2}
FABRIC_VERSION=${TEST_NETWORK_FABRIC_VERSION:-2.4}
CHANNEL_NAME=${TEST_NETWORK_CHANNEL_NAME:-mychannel}
CHAINCODE_IMAGE=${TEST_NETWORK_CHAINCODE_IMAGE:-ghcr.io/hyperledgendary/fabric-ccaas-asset-transfer-basic}
CHAINCODE_NAME=${TEST_NETWORK_CHAINCODE_NAME:-asset-transfer-basic}
CHAINCODE_LABEL=${TEST_NETWORK_CHAINCODE_LABEL:-basic_1.0}
```
To use your local repository:
```shell
export CONTAINER_REGISTRY=localhost:5000
```

## Clean up
```shell
./network.sh down
```

## Notice:
You may need to rerun `./infra.sh jaeger` and `./infra.sh portforward` to restart jaeger after clean up.

## Deployment intergration
Pre discussed with Cello meeting. For any kind of Hyperledger Fabric deployment tools, such as Cello(in this chapter, we will call it as deployment tool for short in following). Tasks below should be followed/checked for intergration between Performance Sandbox and deployment tool.
- [ ] Deployment tool should able to support k8s deployment. (this part can be done with a document as guide)
- [ ] We are able to following the "hello world" guidelines to deploy Hyperledger Fabric on k8s by deployment tool. (this part can be done with a document as guide)
- [ ] Deployment tool should able to support any kind of prometheus and jaeger system. In PerformanceSandBox we used prometheus and jaeger operator, if needed, there need some code changes.
- [ ] Deployment tool should able to support any kind of Hyperledger Fabric Application. For ex either Caliper or Tape needs certs, network info, chaincode info etc for making traffic to SUT. We can following deployment tool's guidelines for blockchain application to deploy Caliper and Tape.
- [ ] Deployment tool should able to support image upgrade, and customize image for Hyperledger Fabric.

## ToDo/TBD: 
- [ ] jeager operator issue with portforward and deployment.
- [ ] https://github.com/hyperledger/bevel
- [ ] https://github.com/hyperledger-labs/minifabric

- [ ] other blockchain projects