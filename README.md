# Practice project for ISTIO Operator + Kustomize tools

## How to run

This small project is using KinD and istioctl, so you need to install them first:

https://kind.sigs.k8s.io/docs/user/quick-start/
https://istio.io/docs/ops/diagnostic-tools/istioctl/

After that you can initialize cluster for Todo project:
```bash
make kind.create
make istioctl.init
```

## How to deploy

To deploy this project using kubectl with building and pushing docker images 
just run this command with any tag you want after `/`:
```bash
make kubectl.deploy/v0.1
make kubectl.deploy/$COMMIT_SHA
make kubectl.deploy/latest
```

## How to do port-forwarding

You just need to run default target or any of `kubectl.serve.%` targets:
```bash
# this is just shortcut to kubectl.serve
make
# this is just shortcut to kubectl.serve.istio
make kubectl.serve
# To port-forward istio ingress gateway
make kubectl.serve.istio 
# To port-forward todo service
make kubectl.serve.service
```