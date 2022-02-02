#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
#set -x
CLUSTER_NAME=${ENV_KIND_CLUSTER_NAME:-kind}

LOCAL_REGISTRY_NAME=${ENV_LOCAL_REGISTRY_NAME:-kind-registry}
LOCAL_REGISTRY_PORT=${ENV_LOCAL_REGISTRY_PORT:-5000}

NGINX_HTTP_PORT=${ENV_NETWORK_INGRESS_HTTP_PORT:-80}
NGINX_HTTPS_PORT=${ENV_NETWORK_INGRESS_HTTPS_PORT:-443}

main() {
    check_prereqs
    ## Parse mode
    if [[ $# -lt 1 ]] ; then
        print_help
        exit 0
    else
        MODE=$1
        shift
    fi

    if [ "${MODE}" == "up" ]; then
        kind_init
    elif [ "${MODE}" == "down" ]; then
        kind_unkind
    elif [ "${MODE}" == "load_image" ]; then
        load_image
    elif [ "${MODE}" == "verify" ]; then
        verify
    elif [ "${MODE}" == "portforward" ]; then
        portforward
    elif [ "${MODE}" == "prometheus" ]; then
        prometheus_init
    elif [ "${MODE}" == "jaeger" ]; then
        jaeger_init
    else
        print_help
        exit 1
    fi
}

function print_help() {
    echo "./infra.sh up for start k8s base on kind"
    echo "./infra.sh load_image for load images to kind(optional)"
    echo "./infra.sh verify for verify the deployment"
    echo "./infra.sh portforward for monitoring pods port forward "
    echo "./infra.sh prometheus for init prometheus"
    echo "./infra.sh jaeger for init jaeger operator"
    echo "./infra.sh down for clean up"
}

function kind_init() {
    echo "Starting kind with cluster name \"${CLUSTER_NAME}\""
    
    local reg_name=${LOCAL_REGISTRY_NAME}
    local reg_port=${LOCAL_REGISTRY_PORT}
    local ingress_http_port=${NGINX_HTTP_PORT}
    local ingress_https_port=${NGINX_HTTPS_PORT}
    docker rm -f ${reg_name}
    kind delete cluster --name $CLUSTER_NAME

  cat <<EOF | kind create cluster -v=6 --name $CLUSTER_NAME --config=-
---
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: ${ingress_http_port}
        protocol: TCP
      - containerPort: 443
        hostPort: ${ingress_https_port}
        protocol: TCP

# create a cluster with the local registry enabled in containerd
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]

EOF

    kubectl apply -f kube/ingress-nginx.yaml

    echo "Launching container registry \"${LOCAL_REGISTRY_NAME}\" at localhost:${LOCAL_REGISTRY_PORT}"
    running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
    if [ "${running}" != 'true' ]; then
        docker run \
        -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
        registry:2
    fi

    # connect the registry to the cluster network
    # (the network may already be connected)
    docker network connect "kind" "${reg_name}" || true

    # Document the local registry
    # https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
    cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

    echo "Complete start kind"
}

function kind_unkind() {
    echo "Removing kind with cluster name \"${CLUSTER_NAME}\""
    kind delete cluster --name $CLUSTER_NAME
    local reg_name=${LOCAL_REGISTRY_NAME}
    docker rm -f ${reg_name}
    echo "Complete remove kind"
}

function prometheus_init() {
    echo "Init prometheus"
    LOCLPATH=$PWD
    cd kube-prometheus
    kubectl create -f manifests/setup
    sleep 30
    kubectl create -f manifests/
    cd $LOCLPATH
    echo "Complete init prometheus"

}

function jaeger_init() {
    echo "Init jaeger"
    kubectl create namespace observability
    kubectl create -n observability -f ./kube/jaeger/deploy/crds/jaegertracing.io_jaegers_crd.yaml
    kubectl create -n observability -f ./kube/jaeger/deploy/service_account.yaml
    kubectl create -n observability -f ./kube/jaeger/deploy/role.yaml
    kubectl create -n observability -f ./kube/jaeger/deploy/role_binding.yaml
    kubectl create -n observability -f ./kube/jaeger/deploy/operator.yaml
    kubectl create -n observability -f ./kube/jaeger/deploy/cluster_role.yaml
    kubectl create -n observability -f ./kube/jaeger//deploy/cluster_role_binding.yaml
    sleep 30
kubectl apply -n observability -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
EOF
    echo "Complete init jaeger"
}

function check_prereqs() {
  docker version > /dev/null
  if [[ $? -ne 0 ]]; then
    echo "No 'docker' binary available? (https://www.docker.com)"
    exit 1
  fi

  kind version > /dev/null
  if [[ $? -ne 0 ]]; then
    echo "No 'kind' binary available? (https://kind.sigs.k8s.io/docs/user/quick-start/#installation)"
    exit 1
  fi

  kubectl > /dev/null
  if [[ $? -ne 0 ]]; then
    echo "No 'kubectl' binary available? (https://kubernetes.io/docs/tasks/tools/)"
    exit 1
  fi
}

function verify() {
    echo "Verify prometheus and jaeger, in monitoring namespace"
    kubectl get po -n monitoring
    echo "Complete Verify prometheus and jaeger, in monitoring namespace"
    echo "Verify prometheus and jaeger, in observability namespace"
    kubectl get po -n observability
    echo "Complete Verify prometheus and jaeger, in observability namespace"

}

function portforward() {
    echo "Start port forwarding in backend"
    nohup kubectl --namespace monitoring port-forward svc/grafana 3000 &
    nohup kubectl --namespace observability port-forward svc/simplest-query 16686 &
}

function load_image() {
    echo "Start load images to kind"
    for image in `cat ./image_list`; do
        echo "Loading image $image to kind"
        kind load docker-image $image
    done    
    echo "Complete load images to kind"
}

main $*
