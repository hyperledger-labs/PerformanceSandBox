
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

You are free to skip some of the steps, if you want to deploy performance sandbox on your own k8s cluster or you already have a k8s cluster with [prometheus operator](https://github.com/prometheus-operator/kube-prometheus) and [jaeger operator](https://github.com/jaegertracing/jaeger-operator).

---
## Prerequisites
- [git](https://github.com/)
- [docker](https://www.docker.com/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kind](https://kind.sigs.k8s.io)

---

## Steps
1. [kind](https://kind.sigs.k8s.io)
```bash
./infra.sh up
```

optional, if you have a image listed in find image_list, you are able to run script below to load local image to kind.
```bash
./infra.sh load_image
```
`image_list` looks like:
```bash
ghcr.io/hyperledger-twgc/tape:edge
```

2. [prometheus operator](https://github.com/prometheus-operator/kube-prometheus)
```bash
./infra.sh prometheus
```

3. [jaeger operator](https://github.com/jaegertracing/jaeger-operator)
```bash
./infra.sh jaeger
```

4. verify 
```bash
./infra.sh verify
```
if everything completed, it looks like:
```bash
Verify prometheus and jaeger, in monitoring namespace
NAME                                 READY   STATUS    RESTARTS   AGE
alertmanager-main-0                  2/2     Running   0          2m45s
alertmanager-main-1                  2/2     Running   0          2m45s
alertmanager-main-2                  2/2     Running   0          2m45s
blackbox-exporter-65f6b65965-5h2n4   3/3     Running   0          9m1s
grafana-79ccfb4557-85fcc             1/1     Running   0          9m
kube-state-metrics-5498b5d7b-wggng   3/3     Running   0          9m
node-exporter-p2w4l                  2/2     Running   0          8m59s
prometheus-adapter-6f6b6c667-h2fjr   1/1     Running   0          8m59s
prometheus-adapter-6f6b6c667-t5mg5   1/1     Running   0          8m59s
prometheus-k8s-0                     2/2     Running   0          2m44s
prometheus-k8s-1                     1/2     Running   0          2m44s
prometheus-operator-8bdc4bdd-vs9vn   2/2     Running   0          8m59s
Complete Verify prometheus and jaeger, in monitoring namespace
Verify prometheus and jaeger, in observability namespace
NAME                               READY   STATUS    RESTARTS   AGE
jaeger-operator-5977dbf59f-955sh   1/1     Running   0          7m27s
simplest-75977cbc89-lltdp          1/1     Running   0          89s
Complete Verify prometheus and jaeger, in observability namespace
```

5. port forward
```bash
./infra.sh portforward
```
access http://localhost:3000 and http://loalhost:16686

## HouseKeeping
```bash
./infra.sh down
```