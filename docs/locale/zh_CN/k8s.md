
---

## 表中的内容

* [介绍](#introduce)
* [先决条件](#prerequisites)
* [步骤](#steps)
* [管家](#家政)

---
## 介绍
本文档是为性能沙箱初始化 k8s 集群的指南。 k8s 集群应该包含 k8s、prometheus 和 jaeger。通过以下步骤，您将拥有一个基于 [kind](https://kind.sigs.k8s.io) 的 k8s 集群
[prometheus 运算符](https://github.com/prometheus-operator/kube-prometheus) 和 [jaeger 运算符](https://github.com/jaegertracing/jaeger-operator)。

如果您想在自己的 k8s 集群上部署性能沙箱，或者您已经有一个带有 [prometheus operator] 的 k8s 集群，您可以跳过一些步骤（https://github.com/prometheus-operator/kube-prometheus ) 和 [jaeger 运算符](https://github.com/jaegertracing/jaeger-operator)。

---
## 先决条件
- [git](https://github.com/)
- [码头工人]（https://www.docker.com/）
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [种类](https://kind.sigs.k8s.io)

---

## 脚步
1. [种类](https://kind.sigs.k8s.io)
```外壳
./infra.sh up
```

可选，如果您在 find image_list 中列出了图像，您可以运行下面的脚本将本地图像加载到 kind。
```外壳
./infra.sh load_image
```
`image_list` 看起来像：
```外壳
ghcr.io/hyperledger-twgc/tape:edge
```

2. [prometheus 算子](https://github.com/prometheus-operator/kube-prometheus)
```外壳
./infra.sh 普罗米修斯
```

3.【jaeger算子】(https://github.com/jaegertracing/jaeger-operator)
```外壳
./infra.sh 杰格
```

4.验证
```外壳
./infra.sh 验证
```
如果一切都完成了，它看起来像：
```外壳
% ./infra.sh 验证
在所有命名空间中验证 prometheus 和 jaege
名称                               就绪          状态        重新开始            年龄
alertmanager-main-0                2/2          运行         0                  113s
alertmanager-main-1                2/2          运行         0                  113s
alertmanager-main-2                2/2          运行         0                  113s
blackbox-exporter-65f6b65965-gg25r 3/3          运行         0                  2m1s
grafana-79ccfb4557-mmtbj           1/1          运行         0                  2m1s
kube-state-metrics-5498b5d7b-hsv7r 3/3          运行         0                  2m1s
node-exporter-4l8l4                2/2          运行         0                  2m
prometheus-adapter-6f6b6c667-4ccpl 1/1          运行         0                  2m
prometheus-adapter-6f6b6c667-xhtwc 1/1          运行         0                  2m
prometheus-k8s-0                   2/2          运行         0                  111s
prometheus-k8s-1                   2/2          运行         0                  111s
prometheus-operator-8bdc4bdd-xdlm5 2/2          运行         0                  2m
名称                               就绪          状态        重新开始     年龄
jaeger-operator-5f5dcf7bf5-6zhrk   1/1          运行         0           105s
名称                               就绪         状态         重新开始     年龄
最简单-75977cbc89-w6xmx            1/1          运行          0          73s
在所有命名空间中完成验证 prometheus 和 jaeger
```

5.端口转发
```外壳
./infra.sh 端口转发
```
访问 http://localhost:3000 和 http://loalhost:16686

## 管家
```外壳
./infra.sh 向下
```
