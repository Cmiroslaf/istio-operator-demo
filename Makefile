SHELL=/bin/bash
INFRA_DIR=$(CURDIR)/infra
RESOURCES_DIR=$(INFRA_DIR)/resources

kubectl.deploy/v%: docker.push/v%
	$(if $(shell cat $(RESOURCES_DIR)/kustomization.yaml \
	               | grep v$*)\
	, \
	, pushd $(RESOURCES_DIR)/todo; \
	    kustomize edit set image localhost:5000/todo=localhost:5000/todo:v$*; \
	  popd; \
	)
	kubectl apply -k $(RESOURCES_DIR)

docker.push/v%: docker.build/v%
	make -C $(CURDIR)/services/todo docker.push/v$*

docker.build/v%:
	make -C $(CURDIR)/services/todo docker.build/v$*

istioctl.inject:
	kubectl get deployment -o yaml -n todo-list todo \
	  | istioctl kube-inject -f - \
	  | kubectl apply -f -

istioctl.init:
	istioctl manifest generate --set profile=default >istio.manifest.yaml
	istioctl manifest apply -f istio.manifest.yaml
	istioctl verify-install -f istio.manifest.yaml

kind.reinit: kind.delete kind.create istioctl.init kubectl.deploy/v1

kind.create:
	kind_create_w_dr todo
	kubectl cluster-info --context kind-todo

kind.delete:
	kind delete cluster --name todo
