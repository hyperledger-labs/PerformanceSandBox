# 目前只支持 Hyperledger Fabric
当前样本从 fabric-sample 中的 test-network-k8s 学习

＃＃ 用法
启动网络，创建通道，并部署 [basic-asset-transfer](./asset-transfer-basic) 智能合约：
```外壳
cd ./SUT/织物
./network.sh up
./network.sh 频道
./network.sh 链码部署
```

调用和查询链码：
```外壳
cd ./SUT/织物
./network.sh 链码调用 '{"Args":["CreateAsset","5","blue","35","tom","1000"]}'
./network.sh 链码查询 '{"Args":["ReadAsset","5"]}'
```

## 自定义
所有自定义参数：
```外壳
LOCAL_CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-hyperledger}
FABRIC_CA_VERSION=${TEST_NETWORK_FABRIC_CA_VERSION:-1.5.2}
FABRIC_VERSION=${TEST_NETWORK_FABRIC_VERSION:-2.4}
CHANNEL_NAME=${TEST_NETWORK_CHANNEL_NAME:-mychannel}
CHAINCODE_IMAGE=${TEST_NETWORK_CHAINCODE_IMAGE:-ghcr.io/hyperledgendary/fabric-ccaas-asset-transfer-basic}
CHAINCODE_NAME=${TEST_NETWORK_CHAINCODE_NAME:-asset-transfer-basic}
CHAINCODE_LABEL=${TEST_NETWORK_CHAINCODE_LABEL:-basic_1.0}
```
要使用本地存储库：
```外壳
导出 CONTAINER_REGISTRY=localhost:5000
```

＃＃ 清理
```外壳
./network.sh 关闭
```

＃＃ 注意：
您可能需要重新运行 `./infra.sh jaeger` 和 `./infra.sh portforward` 以在清理后重新启动 jaeger。

##部署集成
与大提琴会议预先讨论。对于任何一种 Hyperledger Fabric 部署工具，例如 Cello（在本章中，我们将其简称为部署工具）。应遵循/检查以下任务以了解 Performance Sandbox 和部署工具之间的集成。
- [ ] 部署工具应该能够支持 k8s 部署。 （这部分可以以文档为指导完成）
- [ ] 我们能够按照“hello world”指南通过部署工具在 k8s 上部署 Hyperledger Fabric。 （这部分可以以文档为指导完成）
- [ ] 部署工具应该能够支持任何类型的 prometheus 和 jaeger 系统。在 PerformanceSandBox 中，我们使用了 prometheus 和 jaeger 运算符，如果需要，需要进行一些代码更改。
- [ ] 部署工具应该能够支持任何类型的 Hyperledger Fabric 应用程序。例如 Caliper 或 Tape 需要证书、网络信息、链码信息等来向 SUT 发送流量。我们可以按照区块链应用程序的部署工具指南来部署 Caliper 和 Tape。
- [ ] 部署工具应该能够支持镜像升级，并为 Hyperledger Fabric 自定义镜像。

## 待办事项/待定：
- [] jeager 操作员问题与端口转发和部署有关。
- [] https://github.com/hyperledger/bevel
- [] https://github.com/hyperledger-labs/minifabric

- [ ] 其他区块链项目
