SHELL=/bin/bash
INFRA_DIR=$(CURDIR)/infra
RESOURCES_DIR=$(INFRA_DIR)/resources
OVERLAYS_DIR=$(INFRA_DIR)/overlays
K8S_DASHBOARD_TOKEN=$(kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 -d)

.DEFAULT_GOAL:=kubectl.serve
kubectl.serve: kubectl.serve.istio

kubectl.serve.istio:
	kubectl port-forward -n istio-system service/todo-ingressgateway 8080:8080

kubectl.serve.service:
	kubectl port-forward service/todo 8080:8080

kubectl.deploy/%: docker.push/%
	$(if $(shell cat $(RESOURCES_DIR)/kustomization.yaml \
	               | grep $*)\
	, \
	, pushd $(RESOURCES_DIR)/todo; \
	      kustomize edit set image localhost:5000/todo=localhost:5000/todo:$*; \
	  popd; \
	)
	kubectl apply -k $(OVERLAYS_DIR)/local
	make istioctl.inject

kubectl.dashboard:
	@echo "To log into the Kubernetes Dashboard, use this token: $${K8S_DASHBOARD_TOKEN}"
	kubectl proxy

docker.push/%: docker.build/%
	make -C $(CURDIR)/services/todo docker.push/v$*

docker.build/%:
	make -C $(CURDIR)/services/todo docker.build/v$*

istioctl.init:
	istioctl operator init
	- kubectl create ns istio-system
	kubectl apply -f istio.yaml

istioctl.inject: istioctl.inject.todo istioctl.inject.database
	@
istioctl.inject.%:
	kubectl get deployment -o yaml $* \
	  | istioctl kube-inject -f - \
	  | kubectl apply -f -

kind.reinit: kind.delete kind.create istioctl.init

kind.create:
	$(SHELL) scripts/kind_create.sh todo
	kubectl config use-context kind-todo
	kubectl cluster-info --context kind-todo
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
	kubectl create clusterrolebinding default-admin --clusterrole cluster-admin --serviceaccount=default:default

kind.delete:
	kind delete cluster --name todo
