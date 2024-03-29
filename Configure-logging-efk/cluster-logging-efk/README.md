# Project Cluster Logging with EFK!

With the combination of Elasticsearch, Fluentd, and Kibana (EFK), we can create a powerful stack to collect, store, and visualize data in a centralized location.

Let’s start by defining each component to get the big picture. Elasticsearch is an open source distributed, RESTful search and analytics engine, or simply an object store where all logs are stored. Fluentd is an open source data collector that lets you unify the data collection and consumption for better use and understanding of data. And finally, Kibana is a web UI for Elasticsearch.

Before starting, let's have a look at what we will be creating.

![](img/efk-img.png)


## Creating Secrets Store CSI Driver
AWS Secrets Manager now enables you to securely retrieve secrets from AWS Secrets Manager for use in your Amazon Elastic Kubernetes Service (Amazon EKS) Kubernetes pods. For more information read [AWS documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html)

Helpful link for creating and mounting a secret to pod:
https://www.eksworkshop.com/beginner/194_secrets_manager/prepare-secret/

### Create Service Account
```shell
$ kubectl apply -f secret/service-acc.yaml
```


### Create Secret Provider Class
```shell
$ kubectl apply -f secret/secret-provider-class.yaml
```

Now we can create our Elasticsearch cluster.

## Creating the cluster namespace

To view the current active namespaces: 
```shell
$ kubectl get namespaces
```
Now that we have seen the list, let us start by creating our first own namespace:
```shell
$ kubectl apply -f config/1-ns.yaml
```
Let us confirm the namespace is created:
```shell
$ kubectl get namespaces
```

## Creating the Elasticsearch cluster
We will be creating a 3-node Elasticsearch cluster. 
It's a best practice to create a 3-node cluster, and prevents the "split-brain" situation in a highly available multi-node cluster. In short, "split-brain" arises when one or more nodes can't communicate with each other (i.e. node failure, network disconnect, etc) and a new master can't be elected. 
With a 3-node cluster if one of the nodes get disconnected then by election a new master can be assigned from the remaining nodes.

For more information read [Designing for resilience](https://www.elastic.co/guide/en/elasticsearch/reference/current/high-availability-cluster-design.html).

### Headless Service
Before we create our 3-node Elasticsearch cluster, we will need to create a Kubernetes headless service. This headlessservice will not act as a loadbalancer and will not return a single IP address. Instead, it will return all the IP's of the associated Pod's. Headless Services do not have a ClusterIP allocated, will not be proxied by kube-proxy but in this case it will allow Elasticsearch to handle service discovery. We achieve this by setting the `ClusterIP` configuration to `None`.

Create the headless service:
```shell
$ kubectl apply -f config/2-elasticsearch-svc.yaml
```
Read [Headless Services & Service Types](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) for more information.


### Elasticsearch StatefulSet
Rolling out the 3-node Elasticsearch cluster in Kubernetes requires a different type of resource also known as the StatefulSet. It provides pods with a stable identity and grants them stable persistent storage. Elasticsearch requires stable persistent storage to persist data between Pod rescheduling and restarts. To learn more about [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) visit the kubernetes.io website.

To create the Elasticsearch StatefulSet:
```shell
$ kubectl apply -f config/3-elasticsearch-sts.yaml
```
We can follow the creation by running the following command: 
```shell
$ kubectl rollout status sts/es-cluster -n logging
```
We should also be able to see all elasticsearch pods running in the provided namespace:
```shell
$ kubectl get pods -n logging
```

#### Init Containers 
Using the `initContainers` section in the StatefulSet we can apply [Important System Configuration](https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html) 
settings before launching the ElasticSearch containers. We need to do this according to the documentation to prevent issues when running the Elasticsearch cluster.

#### Volume Claim Templates
The StatefulSet needs some form of storage which is defined under `volumeClaimTemplates`. Under the hood Kubernetes creates the PersistentVolumeClaim and PersistentVolume resources.

To get information about the PersistentVolumeClaim pvc, run:
```shell
$ kubectl get pvc -n logging
```
The following will display the PersistentVolume pv:
```shell
$ kubectl get pv -n logging
```
As a result we should have ended up with 3 pvc's total, one for each node in the Elasticsearch cluster.


#### Resolving DNS
Prior to rolling out the StatefulSet we talked about a headless service not returning a single IP address. We can verify this by running a special Pod with DNS utilities, and run a command to perform a service lookup to obtain all the Pod IP addresses backing the headless service:
```shell
# install & run the DNSUtilities Pod in the correct namespace, so that it has access to the headless service!
$ kubectl run dnsutilities --image=tutum/dnsutils -n logging -- sleep infinity
# run nslookup command against the elasticsearch service, should return multiple IP's
$ kubectl exec dnsutilities -n logging -- nslookup elasticsearch
```
The endpoint resource can also provide us with IP address information:
```shell
# checking the service endpoints
$ kubectl get endpoints elasticsearch -n logging
# or running describe to get the complete output of the service endpoints
$ kubectl describe endpoints elasticsearch -n logging
```
Not only will Kubernetes assign each Service/Pod with its own IP address it also adds DNS records. This makes it easier
for clients to find those services instead of using IP addresses. Go to kubernetes.io to learn more about
[Kubernetes DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/).

Using the same DNSUtilities Pod we can extract DNS information by running a nslookup on one of the Elasticsearch Pods:
```shell
# returns the FQDN for the pod, remember to run nslookup first on the headless service
$ kubectl exec dnsutilities -n logging -- nslookup <pod-ip-address>
```
The result should follow a pattern that looks like this: `{pod-name}.{service-name}.{namespace}.svc.cluster.local`. In our case it should resemble the following values: `es-cluster-[0,1,2].elasticsearch.logging.svc.cluster.local`. Running the StatefulSet with multiple replicas creates Pods with the supplied name followed by an ordinal number, as can be seen in the DNS entries. Kubernetes also uses this number when doing RollingUpdates as it will start with the highest number and ending with 0.

### Elasticsearch cluster REST-API
Now that our Elasticsearch cluster is running we can access its REST API and verify everything is running as expected. Doing so allows us to see how our running cluster configuration looks like and what the health state is. To make this REST API available we made `port 9200` available while creating the headless service. Since we cannot access the REST API service directly we will `port-forward` it and make it available outside the cluster.

Port-forwarding is as easy as running one single command:
```shell
$ kubectl port-forward es-cluster-0 -n logging 9200:9200
```
Open a new Terminal window so that we can query the REST API interface:
```shell
$ curl -XGET 'localhost:9200/_cluster/health?pretty'
# we can also ask information about the running nodes on our cluster
$ curl -X GET "localhost:9200/_cluster/state/nodes?pretty"
```
To get some cluster topology in view, run:
```shell
# the result contains IP addresses, roles and metrics
curl -X GET "localhost:9200/_cat/nodes?v"
```
We should see node- IP addresses, metrics, roles and current master node. See
`cat nodes` from [CAT API](https://www.elastic.co/guide/en/elasticsearch/reference/7.x/cat-nodes.html) and customize the output by adding headers to the request.

The above examples only touch the `Cluster API/CAT API` but there are more, go to [REST API](https://www.elastic.co/guide/en/elasticsearch/reference/7.x/rest-apis.html) for more information.

## Creating the Service, Ingress & Kibana Deployment
In this section we will create the Kibana Service, Ingress and Deployment resources and execute them to have a running Kibana pod. Kibana will then provide us with the centralized interface where we can analyze application logs. 

We will rollout a single Kibana pod:
```shell
$ kubectl apply -f config/4-kibana-ingress.yaml
$ kubectl apply -f config/5-kibana-deployment.yaml
```
Verify rollout is succesful:
```shell
$ kubectl rollout status deployment/kibana -n logging
```
Kibana should now be running on the Kubernetes cluster, and to be able to access the dashboard we will also need to apply port-forwarding.

```shell
# first we must retrieve the pod name
$ kubectl get pods -n logging
# copy-past the kibana-{id} node name in the following command
$ kubectl port-forward <kibana-pod> -n logging 5601:5601
# verify the secret mounted as a file by executing the command within the pod
$ kubectl exec -it <kibana-pod> -n logging -- cat /mnt/secrets/efk-secret-22; echo
```
Open a browser and go to <http://localhost:5601>, you should see Kibana loading up. 

## Creating the FluentD DaemonSet
In this final step we will start rolling out the FluentD log collector. We will do this by introducing, yet again, a new resource type, the DaemonSet. Kubernetes will roll out a copy of this Pod(node-logging agent) on each node in the Kubernetes cluster. The idea behind this solution is that the logging-agent running as a container in a Pod will have access toa directory with log files from all the application containers on that Kubernetes node. The logging-agent will collect and parse (supports formats like MySQL, Apache and many more) them and ship them to a new destination like Elasticsearch, Amazone S3 or a third-party log management solution.

Read [Cluster-level logging](https://kubernetes.io/docs/concepts/cluster-administration/logging/#cluster-level-logging-architectures) for other approaches.

To roll out the FluentD DaemonSet, run the following command:
```shell
$ kubectl apply -f config/6-fluentd.yaml
```
Looking at the FluentD DaemonSet configuration we just rolled out, you'll see that other resource types were needed, like the ServiceAccount, ClusterRole and ClusterRoleBinding. All these resources are needed to cover the following:
* ServiceAccount: Provides FluentD with access to the Kubernetes-API
* ClusterRole: Grants permissions (get, list and watch) on the Pods and Namespaces. In other words grants access to other
cluster-scoped Kubernetes resources like Nodes
* ClusterRoleBinding: Binds ServiceAccount to the ClusterRole. Grants ServiceAccount permissions listed in the ClusterRole

Let's verify the DaemonSet was rolled out successfully:
```shell
# should return FluentD pods
$ kubectl get ds -n logging
```

## Analyze logs with Kibana
Now it is time to verify log data is collected properly and shipped to Elasticsearch. Before doing so we must first define an index pattern we would like to explore in Kibana. Simply put an index in Elasticsearch is a collection of related JSON documents. FluentD provides us with those JSON documents and enriches it with Kubernetes fields we can use.

In Kibana we need to click on the `Discover` icon on the left-hand navigation, this starts the Index creation process.

You can then match your index pattern based on that, and in our case that would be `logstash-*`.

In the second and last step we need to define the filter time field Kibana will use to filter log data. Choose `@timestamp` from the drop-down and click on the `Create index pattern` button.

Click the `Discover` button again, the output should resemble some type of diagram.

![Discover Index](img/Kibana-logs.png)


Read the [Kibana Guide](https://www.elastic.co/guide/en/kibana/current/index.html) to learn more about Kibana, includes a Quick Start section and other useful information like, how to create dashboards to visualize your log data.

Final step complete! The 3-node Elasticsearch cluster is up and running and integrated with FluentD to capture log data.

## Creating test-log pod for testing purposes (Optional step)

Let’s begin by creating the Pod. This is a minimal Pod called test-log that runs a while loop, printing numbers sequentially.

Deploy the Pod using kubectl:
```shell
$ kubectl apply -f config/7-test-log.yaml
```

Once the Pod has been created and is running, navigate back to your Kibana dashboard.

From the Discover page, in the search bar enter kubernetes.pod_name:test-log. This filters the log data for Pods named test-log.

You should then see a list of log entries for the Pod:

![test](img/kibana-test.png)



