#!/usr/bin/env bash
set -ex

git clone https://github.com/Cmiroslaf/istio-operator-demo.git

tree .

scripts/kind_create.sh todo
kubectl config use-context kind-todo
kubectl cluster-info --context kind-todo

make nginx.init

kubectl get pods --all-namespaces

docker build -t localhost:5000/todo:latest -f ./services/todo/Dockerfile ./services/todo
docker push localhost:5000/todo:latest

docker build -t localhost:5000/ui:latest -f ./services/ui/Dockerfile ./services/ui
docker push localhost:5000/ui:latest

cat ./deployments/namespace.yaml
kubectl apply -f ./deployments/namespace.yaml
kubectl get namespaces

cat ./deployments/config-map.yaml
kubectl apply -f ./deployments/config-map.yaml
kubectl get configmaps --namespace todo

cat ./deployments/volumes.yaml
kubectl apply -f ./deployments/volumes.yaml

cat ./deployments/services.yaml
#
kubectl apply -f ./deployments/services.yaml
kubectl get services --namespace todo

cat ./example/pod.yaml
cat ./deployments/deployments.yaml
kubectl apply -f ./deployments/deployments.yaml
kubectl get deployments --namespace todo
kubectl get pods -n todo --watch

kubectl edit deployment todo -n todo
kubectl apply -f ./deployments/deployments.yaml
kubectl get pods -n todo -w

kubectl top pods -n todo
kubectl logs -n todo todo-<hash> todo
kubectl get pod -n todo todo -o yaml

kubectl get pods --namespace todo

kind delete cluster --name todo