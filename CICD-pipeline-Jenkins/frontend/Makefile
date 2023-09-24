account = $(shell aws sts get-caller-identity --query "Account" --output text)
region = us-east-1
repo = versus-fe
appname = versus-fe
port = 8080
stage = dev

include configs/$(stage)

build:
	docker build -t $(repo):$(version) .

login:
	aws ecr get-login-password --region $(region) | docker login --username AWS --password-stdin $(account).dkr.ecr.us-east-1.amazonaws.com

push: login
	docker tag $(repo):$(version) $(account).dkr.ecr.$(region).amazonaws.com/$(repo):$(version)
	docker push $(account).dkr.ecr.us-east-1.amazonaws.com/$(repo):$(version)

deploy:
	helm upgrade --install $(appname) helm-chart/ --namespace=$(namespace) --create-namespace \
		--set applicationName=$(appname) \
		--set replicaCount=$(replicas) \
		--set image.repository=$(account).dkr.ecr.$(region).amazonaws.com/$(repo) \
		--set image.tag=$(version) \
		--set port=$(port) \
		--set hostname=$(hostname)