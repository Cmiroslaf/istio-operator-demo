DOCKER_REGISTRY_URL=localhost:5000

docker.build/%:
	docker build -t $(DOCKER_REGISTRY_URL)/todo:$* .

docker.push/%:
	docker push $(DOCKER_REGISTRY_URL)/todo:$*
