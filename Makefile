SHELL := /bin/bash

up: create-cluster apply-deployment apply-services apply-ingress apply-grpc install-nginx-controller

create-cluster:
	kind create cluster --config infra/kind_config.yml

delete-cluster:
	kind delete cluster --name demo

apply-deployment:
	kubectl apply -f infra/deployment.yml

apply-services:
	kubectl apply -f infra/service.yml

apply-grpc:
	openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=demo.localhost/O=demo.localhost"
	kubectl create secret tls tls-secret --key tls.key --cert tls.crt
	kubectl apply -f infra/grpc.yml

apply-ingress:
	kubectl apply -f infra/ingress.yml

install-nginx-controller:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

	kubectl wait --namespace ingress-nginx \
	  --for=condition=ready pod \
	  --selector=app.kubernetes.io/component=controller \
	  --timeout=90s
