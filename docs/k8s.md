
---
## Table Of Content

* [Introduce](#introduce)
* [Prerequisites](#prerequisites)
* [Steps](#steps)
* [HouseKeeping](#housekeeping)

---
## Introduce
This document is a guidance for init a k8s cluster for performance sandbox. The k8s cluster should contains k8s, prometheus and jaeger. With following steps, you will have a k8s cluster basing on [kind](https://kind.sigs.k8s.io) with 
[prometheus operator](https://github.com/prometheus-operator/kube-prometheus) and [jaeger operator](https://github.com/jaegertracing/jaeger-operator).
Or you are able to use [minikube](https://minikube.sigs.k8s.io/docs/start/), and ensure start minikube with `--cni=bridge`

You are free to skip some of the steps, if you want to deploy performance sandbox on your own k8s cluster or you already have a k8s cluster with [prometheus operator](https://github.com/prometheus-operator/kube-prometheus) and [jaeger operator](https://github.com/jaegertracing/jaeger-operator).

---
## Prerequisites
- [git](https://github.com/)
- [docker](https://www.docker.com/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kind](https://kind.sigs.k8s.io) or [minikube](https://minikube.sigs.k8s.io/docs/start/)

---

## Steps
1. start k8s cluster
optional
[kind](https://kind.sigs.k8s.io)
```shell
./infra.sh up
```
[minikube](https://minikube.sigs.k8s.io/docs/start/)
```shell
minikube start --cni=bridge && minikube addons enable ingress && minikube addons enable ingress-dns 
```

optional, if you have a image listed in find image_list, you are able to run script below to load local image to kind.
```shell
./infra.sh load_image
```
`image_list` looks like:
```shell
ghcr.io/hyperledger-twgc/tape:edge
```

2. [prometheus operator](https://github.com/prometheus-operator/kube-prometheus)
```shell
./infra.sh prometheus
```

3. [jaeger operator](https://github.com/jaegertracing/jaeger-operator)
```shell
./infra.sh jaeger
```

4. verify 
```shell
./infra.sh verify
```
if everything completed, it looks like:
```shell
% ./infra.sh verify
Verify prometheus and jaeger, in all namespaces
NAME                                 READY   STATUS    RESTARTS   AGE
alertmanager-main-0                  2/2     Running   0          113s
alertmanager-main-1                  2/2     Running   0          113s
alertmanager-main-2                  2/2     Running   0          113s
blackbox-exporter-65f6b65965-gg25r   3/3     Running   0          2m1s
grafana-79ccfb4557-mmtbj             1/1     Running   0          2m1s
kube-state-metrics-5498b5d7b-hsv7r   3/3     Running   0          2m1s
node-exporter-4l8l4                  2/2     Running   0          2m
prometheus-adapter-6f6b6c667-4ccpl   1/1     Running   0          2m
prometheus-adapter-6f6b6c667-xhtwc   1/1     Running   0          2m
prometheus-k8s-0                     2/2     Running   0          111s
prometheus-k8s-1                     2/2     Running   0          111s
prometheus-operator-8bdc4bdd-xdlm5   2/2     Running   0          2m
NAME                               READY   STATUS    RESTARTS   AGE
jaeger-operator-5f5dcf7bf5-6zhrk   1/1     Running   0          105s
NAME                        READY   STATUS    RESTARTS   AGE
simplest-75977cbc89-w6xmx   1/1     Running   0          73s
Complete Verify prometheus and jaeger,in all namespaces
```

5. port forward
```shell
./infra.sh portforward
```
access http://localhost:3000 and http://loalhost:16686

## HouseKeeping
```shell
./infra.sh down
```