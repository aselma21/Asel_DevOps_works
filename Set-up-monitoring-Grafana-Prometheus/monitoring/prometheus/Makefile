#namespace = monitoring


namespace:
	@kubectl apply -f namespace.yaml

volume: namespace
	@kubectl apply -f prometheus-server/sc.yaml
	@kubectl apply -f prometheus-server/pvc.yaml

run: volume
	@kubectl apply -f prometheus-server/clusterRole.yaml
	@kubectl apply -f prometheus-server/config-map.yaml
	@kubectl apply -f prometheus-server/prometheus-deployment.yaml
	@###
	@kubectl apply -f node-exporter/daemonset.yaml
	@kubectl apply -f node-exporter/service.yaml
	@###
	@kubectl apply -f kube-state-metrics/cluster-role-binding.yaml
	@kubectl apply -f kube-state-metrics/cluster-role.yaml
	@kubectl apply -f kube-state-metrics/deployment.yaml
	@kubectl apply -f kube-state-metrics/service-account.yaml
	@kubectl apply -f kube-state-metrics/service.yaml


stop:
	@kubectl delete -f prometheus-server/clusterRole.yaml
	@kubectl delete -f prometheus-server/config-map.yaml
	@kubectl delete -f prometheus-server/prometheus-deployment.yaml
	@###
	@kubectl delete -f node-exporter/daemonset.yaml
	@kubectl delete -f node-exporter/service.yaml
	@###
	@kubectl delete -f kube-state-metrics/cluster-role-binding.yaml
	@kubectl delete -f kube-state-metrics/cluster-role.yaml
	@kubectl delete -f kube-state-metrics/deployment.yaml
	@kubectl delete -f kube-state-metrics/service-account.yaml
	@kubectl delete -f kube-state-metrics/service.yaml

delete: stop
	@kubectl delete -f prometheus-server/pvc.yaml
	@kubectl delete -f prometheus-server/sc.yaml
	@kubectl delete -f namespace.yaml