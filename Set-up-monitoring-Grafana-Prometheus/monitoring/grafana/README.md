# Setup Grafana On Kubernetes Cluster

Grafana is an open-source lightweight dashboard tool. It can be integrated with many data sources like Prometheus, [AWS cloud watch](https://devopscube.com/how-to-setup-and-push-serverapplication-logs-to-aws-cloudwatch/), Stackdriver, etc. Running Grafana on Kubernetes
Using Grafana you can simplify Kubernetes monitoring dashboards from Prometheus metrics.


## Prerequisites

- Kubernetes cluster
- kubectl
- [Prometheus on Kubernetes](https://devopscube.com/setup-prometheus-monitoring-on-kubernetes/)
- Ingress NGINX Controller
- Secrets Store CSI Driver

# Install

You can build using  `make run`, which will take advantage of the `Makefile` and will use `kubectl` to apply files in the folders :

The Makefile provides several targets:

-   _`sa-spc`_:  create **ServiceAccount** and **SecretProviderClass**
-   _`run`_: run the **ConfigMap**, **Deployment** and **Service** manifest files
-   _`delete`_: deletes all the objects



# Step-by-step Installation Instructions

### Secrets Store CSI Driver
The AWS provider for the Secrets Store CSI Driver allows you to fetch secrets from AWS Secrets Manager and AWS Systems Manager Parameter Store, and mount them into Kubernetes pods.
- [github repo](https://github.com/aws/secrets-store-csi-driver-provider-aws)
- [AWS documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html)

We will store the credentials for the Grafana UI in AWS Secrets Manager.
- #### Note: follow the links above and create secret, IAM role, etc. 


### Service Account
```
kubectl apply -f secret/sa.yaml
```

Create Service Account to be used by the pod and associate the  IAM policy (an access policy for the pod scoped down to just the secrets, created following AWS Documentation or github repo) it should have with that service account.

### Secret Provider Class
```
kubectl apply -f secret/spc.yaml
```

Now create the SecretProviderClass which tells the AWS provider which secrets are to be mounted in the pod.

 ### Data Source Configuration
```
kubectl apply -f grafana-datasource-config.yaml
```

**Note:** The following data source configuration is for Prometheus. If you have more data sources, you can add more data sources with different YAMLs under the data section.

### Deployment
```
kubectl apply -f deployment.yaml
```
**Note:** This Grafana deployment **does not use a persistent volume**. If you restart the pod all changes will be gone. Use a persistent volume if you are deploying Grafana for your project requirements. It will persist all the configs and data that Grafana uses.

**Note:** If you can successfully see mounted secrets within the pod but kubernetes secret object not being created when mounting volume for a env var.  ( pod is stuck in creation) -  fixed by enabling syncsecret on helm instantiation (if you used helm for that purpose). 
```
helm upgrade --install -n kube-system --set syncSecret.enabled=true csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
```
**Note:** We mounted Secrets Store CSI Driver Volume inside the pod and we synced it with Kubernetes Secrets using `secretObjects:` in our **spc.yaml** file created above. Refer to [AWS documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html) for more info. 
Also, secrets will be exposed as [environment variables](https://kubernetes.io/docs/concepts/containers/container-environment/) to be used by a container in a Pod. 
-   _**GF_SECURITY_ADMIN_USER**_  has a default value of "admin". We will overwrite with our `username` value.
-   _**GF_SECURITY_ADMIN_PASSWORD**_  has a default value of "admin". We will overwrite with our `password` value.


### Service
This will expose Grafana [using ingress](https://devopscube.com/setup-ingress-kubernetes-nginx-controller/). 
```
kubectl apply -f service.yaml
```
- Make sure to change your hostname.

Now you should be able to access the Grafana dashboard **using DNS name** on port `80`. Make sure the port is allowed in the firewall to be accessed from your workstation.

![UI](https://xpresservers.com/wp-content/uploads/2019/09/How-To-Install-and-Secure-Grafana-on-Ubuntu-18.04.png)

## Create Kubernetes Dashboards on Grafana

**Creating a Kubernetes dashboard**  from the Grafana template is pretty easy. There are many prebuilt Grafana templates available for Kubernetes. You can easily have prebuilt dashboards for ingress controllers, volumes, API servers, Prometheus metrics, and much more. To know more, see  [Grafana templates for Kubernetes monitoring](https://grafana.com/grafana/dashboards/?search=kubernetes)
### We will use 2 templates for now:
1. ID: `8588` to monitor kubernetes deployments.
2. ID: `1860` to visualise the node exporter metrics.

Head over to the Grafana dashbaord and select the import option.
Enter the dashboard ID.
Grafana will automatically fetch the template from the Grafana website. 
Make sure to select the correct data source ( prometheus in our case).
> **Note**: If you are behind the corporate firewall and cannot download the template using id, you can download the template JSON and paste the JSON in the text box to import it.
> 
You should see the dashboard immediately.

> **Note**: When Grafana is used with Prometheus, it uses PromQL to query metrics from Prometheus. You can use the same PromQL Prometheus queries to  **build custom dashboards on Grafana**.
> 


![GUI](https://grafana.com/api/dashboards/1860/images/7994/image)

## Additional Considerations

### Rotation

When using the optional alpha [rotation reconciler](https://secrets-store-csi-driver.sigs.k8s.io/topics/secret-auto-rotation.html) feature of the Secrets Store CSI driver the driver will periodically remount the secrets in the SecretProviderClass. This will cause additional API calls which results in additional charges. Applications should use a reasonable poll interval that works with their rotation strategy. A one hour poll interval is recommended as a default to reduce excessive API costs.

Anyone wishing to test out the rotation reconciler feature can enable it using helm:

`helm upgrade -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --set enableSecretRotation=true --set rotationPollInterval=3600s`

### Issues
1. The path in the default grafana-datasource ConfigMap is incorrect (service name and port was wrong).  Changed it to the correct values. Found the solution [here](https://www.youtube.com/watch?v=YDtuwlNTzRc&ab_channel=ThatDevOpsGuy)
2. I was able to access the Grafana UI when port-forwarding. But when accessing through DNS ( with ingress) - 404.
The **`grafana-ingress`** didn’t have an address, so it wasn’t mapping to the ingress-nginx.
Fixed by putting this line in the annotation of the ingress-resource **`kubernetes.io/ingress.class: nginx`**
3. PVC was in pending state. The problem was a permission issues and lack of ebs csi driver (on EKS).
4. I'm trying to use the value of that csi volume as an env inside the pod in order to change the default Grafana credentials to the ones we define in the AWS secret. I modified my SecretProviderClass and Deployment. As i understood the secret will be created itself when pod is created, however in my case it didn't happened and pod is in CreateContainerConfigError. 
Fixed by running ( `--set syncSecret.enabled=true` in helm)
**`helm upgrade --install -n kube-system --set syncSecret.enabled=true csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver`**
5. AWS Secrets Store driver cannot pass multiple key=value pairs into the k8s secret. When mounting the secret as `env`, the value was mapped together with a key ( `"key=value"`, instead of just `"value"`)
used `jmesPath:`
https://github.com/aws/secrets-store-csi-driver-provider-aws/issues/46
https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html