# Setup Prometheus Monitoring On Kubernetes Cluster

Prometheus, a  [Cloud Native Computing Foundation](https://cncf.io/)  project, is a systems and service monitoring system. It collects metrics from configured targets at given intervals, evaluates rule expressions, displays the results, and can trigger alerts when specified conditions are observed.

The features that distinguish Prometheus from other metrics and monitoring systems are:

-   A  **multi-dimensional**  data model (time series defined by metric name and set of key/value dimensions)
-   PromQL, a  **powerful and flexible query language**  to leverage this dimensionality
-   No dependency on distributed storage;  **single server nodes are autonomous**
-   An HTTP  **pull model**  for time series collection
-   **Pushing time series**  is supported via an intermediary gateway for batch jobs
-   Targets are discovered via  **service discovery**  or  **static configuration**
-   Multiple modes of  **graphing and dashboarding support**
-   Support for hierarchical and horizontal  **federation**

## [](https://github.com/prometheus/prometheus#architecture-overview)Architecture overview

[![Architecture overview](https://camo.githubusercontent.com/f14ac82eda765733a5f2b5200d78b4ca84b62559d17c9835068423b223588939/68747470733a2f2f63646e2e6a7364656c6976722e6e65742f67682f70726f6d6574686575732f70726f6d65746865757340633334323537643036396336333036383564613335626365663038343633326666643564363230392f646f63756d656e746174696f6e2f696d616765732f6172636869746563747572652e737667)](https://camo.githubusercontent.com/f14ac82eda765733a5f2b5200d78b4ca84b62559d17c9835068423b223588939/68747470733a2f2f63646e2e6a7364656c6976722e6e65742f67682f70726f6d6574686575732f70726f6d65746865757340633334323537643036396336333036383564613335626365663038343633326666643564363230392f646f63756d656e746174696f6e2f696d616765732f6172636869746563747572652e737667)

## [](https://github.com/prometheus/prometheus#install)


This repository collects Kubernetes manifest files to provide easy to operate Kubernetes cluster monitoring with [Prometheus](https://prometheus.io/).


## Components included in this repo

-   [Prometheus](https://prometheus.io/)
-   [Prometheus node-exporter](https://github.com/prometheus/node_exporter)
-   [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
- [Alertmanager](https://github.com/prometheus/alertmanager) ( optional )

## Prerequisites

- Kubernetes cluster
- kubectl
- privileges to create cluster roles

# Install

You can build using  `make run`, which will take advantage of the `Makefile` and will use `kubectl` to apply files in the folders :

The Makefile provides several targets:

-   _`namespace`_:  create `monitoring` namespace in Kubernetes
-   _`volume`_: create **PersistentVolumeClaim** and **StorageClass** objects
-   _`run`_: run the **prometheus-server**, **node-exporter** and **kube-state-metrics** manifest files
-   _`stop`_: deletes **prometheus-server**, **node-exporter** and **kube-state-metrics** objects
-   _`delete`_: deletes the **PersistentVolumeClaim** and **StorageClass** objects



# Step-by-step Installation Instructions

 ### Namespace
```
kubectl apply -f namespace.yaml
```

First, we will create a Kubernetes namespace for all our monitoring components. If you don’t create a dedicated namespace, all the Prometheus kubernetes deployment objects get deployed on the default namespace.

### PersistentVolume
```
kubectl apply -f prometheus-server/sc.yaml
```
```
kubectl apply -f prometheus-server/pvc.yaml
```

If you want to preserve the data even after a pod deletion or pod failures, you should use persistent volumes. 
Storage class is a simple way of segregating the storage options. To put simply, a storage class defines what type of storage to be provisioned. 
To create a persistent volume you need to create a Persistent Volume claim.
`persistentVolumeClaim`  is the way to request storage based on a storage class and use it with a pod. The pod to Persistent volume mapping happens through PVC.

### Note
The [Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver) provides a CSI interface that allows Amazon Elastic Kubernetes Service (Amazon EKS) clusters to manage the lifecycle of Amazon EBS volumes for persistent volumes.

 [Managing the Amazon EBS CSI driver as an Amazon EKS add-on](https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html)

### clusterRole

```
kubectl apply -f prometheus-server/clusterRole.yaml
```

In the role you can see that we have added `get`, `list`, and `watch` permissions to nodes, services endpoints, pods, and ingresses. The role binding is bound to the monitoring namespace. If you have any use case to retrieve metrics from any other object, you need to add that in this cluster role.

### Create a Config Map To Externalize Prometheus Configurations
```
kubectl apply -f prometheus-server/config-map.yaml
```

All configurations for Prometheus are part of `prometheus.yaml` file and all the alert rules for Alertmanager are configured in `prometheus.rules`.
The config map with all the  [Prometheus scrape config](https://raw.githubusercontent.com/bibinwilson/kubernetes-prometheus/master/config-map.yaml) and alerting rules gets mounted to the Prometheus container in  `/etc/prometheus`  location as  `prometheus.yaml` and `prometheus.rules` files.

### Create a Prometheus Deployment
```
kubectl apply -f prometheus-server/prometheus-deployment.yaml
```

You can check the created deployment using the following command.
```
kubectl get deployments --namespace=monitoring
```

## Setup Node Exporter
```
kubectl apply -f node-exporter/daemonset.yaml
```

Deploy node exporter on all the Kubernetes nodes as a `daemonset`. Daemonset makes sure one instance of node-exporter is running in all the nodes. It exposes all the node metrics on port `9100` on the `/metrics` endpoint


```
kubectl apply -f node-exporter/service.yaml
```

Create a service that listens on port `9100` and points to all the daemonset node exporter pods. We would be monitoring the service endpoints (Node exporter pods) from Prometheus using the endpoint job config.

#### Note
For the  **production Prometheus setup**, there are more configurations and parameters that need to be considered for scaling, high availability, and storage. It all depends on your environment and data volume.
For example,  [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)  project makes it easy to automate Prometheus setup and its configurations.
Also, the CNCF project  [Thanos](https://github.com/thanos-io/thanos)  helps you aggregate metrics from multiple Kubernetes Prometheus sources and has a highly available setup with scalable storage.

## Kube State Metrics
[Kube State metrics](https://github.com/kubernetes/kube-state-metrics) is a service that talks to the Kubernetes API server to get all the details about all the API objects like deployments, pods, daemonsets, Statefulsets, etc.

Kube state metrics is available as a public docker image. You will have to deploy the following Kubernetes objects for Kube state metrics to work.

1.  A  **Service Account**
2.  **Cluster Role**  – For kube state metrics to access all the Kubernetes API objects.
3.  **Cluster Role Binding**  – Binds the service account with the cluster role.
4.  Kube State Metrics  **Deployment**
5.  **Service**  – To expose the metrics

Create all the objects by pointing to the directory.

```
kubectl apply -f kube-state-metrics/
```
Check the deployment status using the following command.

```
kubectl get deployments kube-state-metrics -n kube-system
```

## Setting Up Alert Manager (Optional)
AlertManager is an open-source alerting system that works with the Prometheus Monitoring system.

Alert Manager setup has the following key configurations.
1.  A config map for AlertManager configuration
2.  A config Map for AlertManager alert templates
3.  Alert Manager  [Kubernetes Deployment](https://devopscube.com/kubernetes-deployment-tutorial/)
4.  Alert Manager service to access the web UI.

### Create all the objects by pointing to the directory.
```
kubectl apply -f kubernetes-alert-manager/
```

## Issues

prometheus pod was failing due to access denied. `.....panic: Unable to create mmap-ed active query log....permission denied` 
[Solution](https://faun.pub/digitalocean-kubernetes-and-volume-permissions-820f46598965)
[Github](https://github.com/aws/eks-charts/issues/21)
