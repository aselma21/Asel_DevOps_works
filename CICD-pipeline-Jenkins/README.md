<h1 align="center"><b>VERSUS</b></h3>

<p>Versus is a global comparison platform, providing unbiased and user-friendly comparisons across various categories. By providing accurate and objective information, as well as structured, easy-to-visualize data, we aim to ease decision-making. It is Open source web application to make comparisons between whatever you want.</p>

&nbsp;

## How it works
- Python based app that has Frontend App, and Backend App that connects to a DB.
- DB stores a list of Colleges and Restaurants, with all of their details such as Tuition cost, programs offered, degrees, and many other details.
- Frontend is the UI website, Backend receives API requests from clients directly (when they click certain buttons on the frontend website) and retrieves data from DB based on the request, which is then rendered and displayed on the website. So Backend is a Public API application.

### Prerequisites and basic installation instructions if those are not yet present

- [AWS EKS Cluster](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html) and configurations to use it
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) user credentials with the right permissions
- [Ingress NGINX Controller](https://github.com/kubernetes/ingress-nginx)
- [AWS RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html) MySQL Database with credentials as Secret in [AWS Secrets Manager](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)
- [Secrets Store CSI driver](https://github.com/aws/secrets-store-csi-driver-provider-aws) (sync with Kubernetes secrets) - will be described below
- [Jenkins Master](https://www.jenkins.io/doc/book/installing/kubernetes/) configured and running in the cluster

### Secrets store CSI Driver

The Secrets Store CSI Driver will allow secrets from AWS Secrets Manager to be mounted to your pod. 
Install the CSI driver and AWS provider before deploying the Backend application to ensure it will pick up the secrets.

- Through HELM
```
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system --set syncSecret.enabled=true
```
Note: `syncSecret.enabled=true` must be explicitly enabled in order to ensure that a kubernetes secret will be created.
```
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```
- Alternatively, through yaml files in the project's `csi-driver` directory. The file `csi-driver` file contains Kubernetes secret syncing feature.
```
kubectl apply -f csi-driver-aws/csi-driver.yaml
kubectl apply -f csi-driver-aws/csi-secrets-store-provider-aws.yaml
```
### IAM role for your Service Account that will read AWS DB secret

You can follow these [instructions](https://github.com/aws/secrets-store-csi-driver-provider-aws#usage) or the steps below through the AWS Console:
1. In your EKS Console, go to your Cluster details, and copy the OpenID Connect provider URL
2. Go to IAM, under Identity Proiders - create new provider, choose OpenID, enter your OpenID URL, and click Get Thumbprint. Set sts.amazonaws.com as audience for now.
3. Go to Policies, and create a json policy that will allow reading secrets:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "YOUR-SECRET-FULL-ARN"
            ]
        }
    ]
}
```
4. Create a new role. Trusted entity type = web identity, and as Identity provider choose the OIDC created earlier. Add the permission policy you just created.
5. After the role is created, go to Trust relationships and Edit Trust Policy. Edit the Condition to add your Service Account, used by the Pods, to assume this role (change `aud` to `sub` and change `sts.amazonaws.com` to your Service Account as the trusted entity):
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "YOUR-OICD-FULL-ARN"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "YOUR-OICD-FULL-ARN:sub": "system:serviceaccount:YOUR-NAMESPACE:YOUR-SA-NAME"
                }
            }
        }
    ]
}
```
The ARN of this role is be used as value in Backend's configs/ under env `sa_secret_role`. 

### Getting your Database ready
1. Connect to your private MySQL database through a Bastion Host
2. Create a new database and provide its credentials as Env Var in your configs/ and/or Makefile
```
> CREATE DATABASE DATABASE_NAME
```

```
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
MYSQL_HOST
MYSQL_PORT
```
You will migrate your data once, when the Backend will be deployed for the first time.

## Multi-environment deployment automation into Kubernetes using Jenkins CI/CD (AWS EKS)

## Backend deployment with Helm and Makefile
### Helm
For Helm multi-environment deployment, a Helm chart is used that contains the templates for the Kubernetes resources you are launching.
Create a new chart for this purpose in backend/. You can create a new directory from scratch, and will have a templates/ directory and Chart.yaml file.
templates/ includes the templates of the resources that will be created in order to run the application:
- deployment;
- ingress;
- service account;
- service;
- secret provider class;

The templates use variable values that are set up in Configs/ and are applied for the separate environment chosen. Ensure that the namespace and service account that you use as Env Var match the ones you create the IAM role with.

Overview of the resources:
- The Ingress file will pass rules where the traffic will be redirected when a client accesses your host. 
  - If your EKS Cluster is configured to automatically create Route 53 records from Ingress' annotations, you will pass your new hostname into:
```
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.hostname }}
```
  Otherwise, use as host an existing Route 53 record that points to the ELB created by your ingress controller.
  
- The Service file will create a ClusterIP Service for internal network. Your ingress will redirect traffic to this service.

- The Service Account file will create the SA used by your pods. This SA will have a role to allow reading of Kubernetes secrets, which will mirror the AWS secrets thanks to the CSI driver installed.

- The [Secret Provider Class](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver_SecretProviderClass.html) will describe which secrets to mount to your pods.

- The Deployment will create pods where your application will run.


### configs/
configs/ is used to set up variables that will be picked up my Makefile and applied in the helm templates when deploying the application.
The environments (dev and prod) are separated and isolated through dev and prod stage files in configs/, where the values for each variable are called by Helm.

### Makefile
The Makefile is the main configuration file where Jenkins will pick up instructions from.
The Makefile will contain instructions to build the new image from Dockerfile, to push this image to public ECR, to deploy helm and all the kubernetes resources.
Variables that are to be picked up for the deployment are set up in the Makefile, which is instructed to also include extra variables from configs/ and apply them based on the stage/environment.

### When all the variables have been set, the Backend application is ready to be deployed.
### Backend data migration to your Database
When the Backend pod is up and running, exec into it:
```
kubectl exec -it -n NAMESPACE - POD_NAME -- sh
```
Then run migrations:
```
./manage.py migrate
```

Seed fixtures:
```
./manage.py loaddata data.json
```

## Frontend deployment with Helm and Makefile
### Before deploying Frontend to Kubernetes
Before building a frontend Docker image you should make appropriate changes in `.env.production` file in `frontend` folder . The `.env.production` file contains a **REACT_APP_API_URL** variable with a domain address. This domain is a production **backend** domain address. To send requests from the frontend service you should replace the **REACT_APP_API_URL** value with your Backend's Route53 record. For example:
```
REACT_APP_API_URL=http://vs-backend.example.com
```
### Helm
For Helm multi-environment deployment, a Helm chart is used that contains the templates for the Kubernetes resources you are launching.
Create a new chart for this purpose in frontend/. You can create a new directory from scratch, and will have a templates/ directory and Chart.yaml file.
templates/ includes the templates of the resources that will be created in order to run the application:
- deployment;
- ingress;
- service;

The templates use variable values that are set up in Configs/ and are applied for the separate environment chosen. 

Overview of the resources:
- The Ingress file will pass rules where the traffic will be redirected when a client accesses your host. 
  - If your EKS Cluster is configured to automatically create Route 53 records from Ingress' annotations, you will pass your new hostname into:
```
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.hostname }}
```
  Otherwise, use as host an existing Route 53 record that points to the ELB created by your ingress controller.
  
- The Service file will create a ClusterIP Service for internal network. Your ingress will redirect traffic to this service.

- The Deployment will create pods where your application will run.


### configs/
configs/ is used to set up variables that will be picked up my Makefile and applied in the helm templates when deploying the application.
The environments (dev and prod) are separated and isolated through dev and prod stage files in configs/, where the values for each variable called by helm are called.

### Makefile
The Makefile is the main configuration file where Jenkins will pick up instructions from.
The Makefile will contain instructions to build the new image from Dockerfile, to push this image to public ECR, to deploy helm and all the kubernetes resources.
Variables that are to be picked up for the deployment are set up in the Makefile, which is also instructed to include extra variables from configs/ and apply them based on the stage/environment.

### When all the variables have been set, the Frontend application is ready to be deployed.

## Jenkinsfile
To deploy the application via Jenkins CICD, you need the Jenkinsfile created in the project's directory.
The CICD pipeline will have configured a Jenkins agent container in Kubernetes that will run deployment jobs.
In `stages`, the Jenkins agent is instructed to go through backend/ and frontend/ directories and apply `make` commands that will build, push images, and will deploy the resources with Helm.

The Jenkinsfile is configured to deploy in a specific stage/environment through the `stage` variable (from Makefile). It is currently set to pick up variables and resources for `dev` stage. The needed stage can be set/overwritten by passing stage=YOUR_STAGE on `make` commands in the Jenkinsfile:
```
make build stage=YOUR_STAGE
make push stage=YOUR_STAGE
make deploy stage=YOUR_STAGE
```

The pipeline is currently configured to run jobs when it's triggered manually by clicking "Build now". 
Optionally, automatic triggers can be configured.

Examples:
Option 1: To configure Scheduled Polling
- Add the following lines to your Jenkinsfile 
```
  properties ([
    pipelineTriggers ([
    // build job if there was a github push 
    [sclass: 'GitHubPushTrigger'],
    pollSCM('*/1 * * * *'), // poll every 1 minute
    ])
])
```
- then make sure Jenkins has picked up those settings
  - Jenkins should read your Jenkinsfile at least once to memorize these settings - hit the Scan or Build buttons in Jenkins UI for forcing it to read Jenkinsfile from repo branch

Option 2: To configure GitHub Webhooks
- Add the following lines to your Jenkinsfile
```
  properties (I
    pipelineTriggers(I
    // build job if there was a github push
    [class: 'GitHubPushTrigger', 
    ])
])
```
- Configure GitHub webhook in GitHub repo settings
  - https://docs.github.com/en/developers/webhooks-and-events/webhooks/creating-webhooks
  - You should provide DNS or IP address of your Jenkins master where GitHub will send notification events of changes in GitHub repo
  - You might also need to whitelist GitHub webhook IPs in firewalls that might prevent network access to Jenkins

For more information see [pipeline triggers](https://www.jenkins.io/doc/pipeline/steps/params/pipelinetriggers/)

### The application should be accessible through its hostname and be able to process comparisons. 

<img width="1505" alt="image" src="https://user-images.githubusercontent.com/114625725/212576962-c88a0433-2cfc-493d-af98-69a7e55e435d.png">
<img width="1505" alt="image" src="https://user-images.githubusercontent.com/114625725/212577012-1cabfe56-e5a8-4f54-8605-2d731547598e.png">


