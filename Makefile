SHELL=/bin/bash
INFRA_DIR=$(CURDIR)/infra
RESOURCES_DIR=$(INFRA_DIR)/resources
K8S_DASHBOARD_TOKEN=$(kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 -d) \


kubectl.deploy/v%: docker.push/v%
	$(if $(shell cat $(RESOURCES_DIR)/kustomization.yaml \
	               | grep v$*)\
	, \
	, pushd $(RESOURCES_DIR)/todo; \
	    kustomize edit set image localhost:5000/todo=localhost:5000/todo:v$*; \
	  popd; \
	)
	kubectl apply -k $(RESOURCES_DIR)

kubectl.dashboard:
	@echo "To log into the Kubernetes Dashboard, use this token: $${K8S_DASHBOARD_TOKEN}"
	kubectl proxy

docker.push/v%: docker.build/v%
	make -C $(CURDIR)/services/todo docker.push/v$*

docker.build/v%:
	make -C $(CURDIR)/services/todo docker.build/v$*

istioctl.init:
	istioctl operator init
	kubectl create ns istio-system
	kubectl apply -f istio.yaml

istioctl.inject:
	kubectl get deployment -o yaml -n todo-list todo \
	  | istioctl kube-inject -f - \
	  | kubectl apply -f -
	kubectl get deployment -o yaml -n todo-list postgres \
	  | istioctl kube-inject -f - \
	  | kubectl apply -f -

kind.reinit: kind.delete kind.create istioctl.init

kind.create:
	kind_create_w_dr todo
	kubectl config use-context kind-todo
	kubectl cluster-info --context kind-todo
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
	kubectl create clusterrolebinding default-admin --clusterrole cluster-admin --serviceaccount=default:default

kind.delete:
	kind delete cluster --name todo
