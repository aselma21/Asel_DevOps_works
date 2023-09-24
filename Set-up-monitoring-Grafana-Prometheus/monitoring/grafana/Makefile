#make sure ingress controller is installed (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/aws/deploy.yaml)
#namespace = monitoring



sa-spc:
	@kubectl apply -f secret/sa.yaml
	@kubectl apply -f secret/spc.yaml

	
run: sa-spc
	@kubectl apply -f grafana-datasource-config.yaml
	@kubectl apply -f deployment.yaml
	@kubectl apply -f service.yaml
	

delete:
	@kubectl delete -f secret/sa.yaml
	@kubectl delete -f secret/spc.yaml
	@kubectl delete -f grafana-datasource-config.yaml
	@kubectl delete -f deployment.yaml
	@kubectl delete -f service.yaml