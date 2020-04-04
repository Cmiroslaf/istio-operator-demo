##
##     \e[1;4mMakefile for building and deploying TODO-list application\e[0m
##
SHELL=/bin/bash

INFRA_DIR=$(CURDIR)/infra
COMMON_BASES_DIR=$(INFRA_DIR)/bases
GCLOUD_OVERLAY_DIR=$(INFRA_DIR)/gcloud
KIND_OVERLAY_DIR=$(INFRA_DIR)/kind

K8S_DASHBOARD_TOKEN=$(shell kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 -d)
# KinD local docker image registry
#DOCKER_REGISTRY_URL=localhost:5000
DOCKER_REGISTRY_URL=gcr.io/miroc-sandbox
##
##  \e[1mMain targets\e[0m
##   \e[34mserve\e[0m                            - Serves the application deployed in Kubernetes using NGINX ingress
.DEFAULT_GOAL:=serve
serve: kubectl.serve.nginx

##   \e[34minit\e[0m                             - Initializes local cluster using KinD, Istio and NGINX
init: istioctl.init

##   \e[34mhelp\e[0m                             - Shows this help
help: Makefile
	@echo -e "$$(sed -n 's/^##//p' Makefile)"
##
##  \e[1mKubectl targets\e[0m
##   \e[34mkubectl.serve.nginx\e[0m              - Serves NGINX ingress
kubectl.serve.nginx:
	kubectl port-forward -n ingress-nginx service/ingress-nginx 8080:80

##   \e[34mkubectl.serve.todo\e[0m               - Serves todo service directly
kubectl.serve.todo:
	kubectl port-forward service/todo 8081:8080

##   \e[34mkubectl.serve.ui\e[0m                 - Serves ui service directly
kubectl.serve.ui:
	kubectl port-forward service/ui 8082:8080

##   \e[34mkubectl.serve.prometheus\e[0m         - Serves Prometheus
kubectl.serve.prometheus:
	kubectl port-forward -n istio-system service/prometheus 6660:9090

##   \e[34mkubectl.serve.tracing\e[0m            - Serves Prometheus
kubectl.serve.tracing:
	kubectl port-forward -n istio-system service/tracing 6661:80

##   \e[34mkubectl.serve.dashboard\e[0m          - Serves Kubernetes dashboard
kubectl.serve.dashboard:
	@echo "To log into the Kubernetes Dashboard, use this token: $(K8S_DASHBOARD_TOKEN)"
	@echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
	kubectl proxy

##   \e[34mkubectl.deploy/%\e[0m                 - Deploys whole application into the Kubernetes
kubectl.deploy/%: docker.push/%
	set -e; \
	  pushd $(COMMON_BASES_DIR); \
	    kustomize edit set image localhost:5000/ui=localhost:5000/ui:$*; \
	  popd
	set -e; \
	  pushd $(COMMON_BASES_DIR); \
	    kustomize edit set image localhost:5000/todo=localhost:5000/todo:$*; \
	  popd
	kubectl apply -k $(OVERLAYS_DIR)/local
	make istioctl.inject
##
##  \e[1mDocker targets\e[0m
##   \e[34mdocker.push/%\e[0m                    - Pushes built image into the repository with given image tag
docker.push/%: docker.build/%
	make -C $(CURDIR)/services/todo docker.push/$* DOCKER_REGISTRY_URL=$(DOCKER_REGISTRY_URL)
	make -C $(CURDIR)/services/ui docker.push/$* DOCKER_REGISTRY_URL=$(DOCKER_REGISTRY_URL)

##   \e[34mdocker.build/%\e[0m                   - Builds image with given image tag
docker.build/%:
	make -C $(CURDIR)/services/todo docker.build/$* DOCKER_REGISTRY_URL=$(DOCKER_REGISTRY_URL)
	make -C $(CURDIR)/services/ui docker.build/$* DOCKER_REGISTRY_URL=$(DOCKER_REGISTRY_URL)
##
##  \e[1mIstioctl targets\e[0m
##   \e[34mistioctl.init\e[0m                    - Initializes istioctl
istioctl.init:
	istioctl operator init
	- kubectl create ns istio-system
	kubectl apply -f istio.yaml

##   \e[34mistioctl.inject\e[0m                  - Injects database and service with sidecar
istioctl.inject: istioctl.inject.todo istioctl.inject.database
	@
istioctl.inject.%:
	kubectl get deployment -o yaml $* \
	  | istioctl kube-inject -f - \
	  | kubectl apply -f -
##
## \e[33;1mGCloud Cluster:\e[0m
##  \e[1mTerraform targets\e[0m
##   \e[34mtf.plan\e[0m                          - Plans a changes to be done on cluster using Terraform
tf.plan:
	terraform plan -out=.terraform/tfplan.out

##   \e[34mtf.apply\e[0m                         - Applies terraform plan to the cluster
tf.apply:
	terraform apply .terraform/tfplan.out

##   \e[34mtf.init\e[0m                          - Applies terraform plan to the cluster
tf.init:
	terraform init
	terraform import kubernetes_namespace.default_namespace default
##
## \e[33;1mLocal Cluster:\e[0m
## To use this you need to install KinD and istioctl locally
## Follow instructions in README.md
##  \e[1mNGINX targets\e[0m
##   \e[34mnginx.init\e[0m                       - Initializes the NGINX with mandatory components and service with type NodePort
nginx.init:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/baremetal/service-nodeport.yaml
	kubectl patch deployments -n ingress-nginx nginx-ingress-controller -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":[{"containerPort":80,"hostPort":80},{"containerPort":8080,"hostPort":8080},{"containerPort":443,"hostPort":443}]}],"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'

##
##  \e[1mKinD targets\e[0m
##   \e[34mkind.create\e[0m                      - Creates KinD cluster on this machine with docker registry and Kubernetes dashboard
kind.create:
	$(SHELL) scripts/kind_create.sh todo
	kubectl config use-context kind-todo
	kubectl cluster-info --context kind-todo
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
	kubectl create clusterrolebinding default-admin --clusterrole cluster-admin --serviceaccount=default:default

##   \e[34mkind.delete\e[0m                      - Deletes KinD cluster that is running on this machine
kind.delete:
	kind delete cluster --name todo
