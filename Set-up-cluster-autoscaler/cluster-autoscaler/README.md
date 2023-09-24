# Setup cluster-autoscaler for EKS cluster!
Autoscaling is a function that automatically scales your resources up or down to meet changing demands. This is a major Kubernetes function that would otherwise require extensive human resources to perform manually.

# Cluster Autoscaler
The Kubernetes Cluster Autoscaler automatically adjusts the number of nodes in your cluster when pods fail or are rescheduled onto other nodes. The Cluster Autoscaler is typically installed as a Deployment in your cluster. It uses leader election to ensure high availability, but scaling is done by only one replica at a time.
![](https://aws.github.io/aws-eks-best-practices/cluster-autoscaling/architecture.png)

# Overprovisioning
The Cluster Autoscaler helps to minimize costs by ensuring that nodes are only added to the cluster when they're needed and are removed when they're unused. This significantly impacts deployment latency because many pods must wait for a node to scale up before they can be scheduled. Nodes can take multiple minutes to become available, which can increase pod scheduling latency by an order of magnitude.
# Getting Started
For reference we will use AWS documentation
[User Guide](https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html#cluster-autoscaler)
Also as extra documentation to compare and check our cluster-autoscaler with examples we will  [kubecost](https://www.kubecost.com/kubernetes-autoscaling/kubernetes-cluster-autoscaler/) website
# Prerequisites
Before deploying the Cluster Autoscaler, you must meet the following prerequisites:

-  An existing Amazon EKS cluster as example we will cluster named "[EKS_centos_cluster]"
-  An existing IAM OIDC provider for your cluster. To determine whether you have one or need to create one, see Creating an IAM OIDC provider for your cluster.
# To create an IAM OIDC identity provider for your cluster with eksctl
1. Determine whether you have an existing IAM OIDC provider for your cluster.

Retrieve your cluster's OIDC provider ID and store it in a variable.
```
   oidc_id=$(aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
```
2. Determine whether an IAM OIDC provider with your cluster's ID is already in your account.
```
   aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4

```
If output is returned, then you already have an IAM OIDC provider for your cluster and you can skip the next step. If no output is returned, then you must create an IAM OIDC provider for your cluster.

3. Create an IAM OIDC identity provider for your cluster with the following command. Replace my-cluster with your own value. 
```
   eksctl utils associate-iam-oidc-provider --cluster my-cluster --approve

```

- Node groups with Auto Scaling groups tags. The Cluster Autoscaler requires the following tags on your Auto Scaling groups so that they can be auto-discovered.

If you used eksctl to create your node groups, these tags are automatically applied.

If you didn't use eksctl, you must manually tag your Auto Scaling groups with the following tags. For more information, see Tagging your Amazon EC2 resources in the Amazon EC2 User Guide for Linux Instances.
![](https://www.kubecost.com/images/outscaling-key-value.png)
# Create an IAM policy and role
Create an IAM policy that grants the permissions that the Cluster Autoscaler requires to use an IAM role. Replace all of the example values with your own values throughout the procedures.

1. Create an IAM policy.

-  a. Save the following contents to a file that's named cluster-autoscaler-policy.json. If your existing node groups were created with eksctl and you used the --asg-access option, then this policy already exists and you can skip to step 2.
```
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/k8s.io/cluster-autoscaler/my-cluster": "owned"
                }
            }
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeAutoScalingGroups",
                "ec2:DescribeLaunchTemplateVersions",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeLaunchConfigurations"
            ],
            "Resource": "*"
        }
    ]
}
```
-  b. Create the policy with the following command. You can change the value for policy-name.
    ```
   aws iam create-policy \
    --policy-name AmazonEKSClusterAutoscalerPolicy \
    --policy-document file://cluster-autoscaler-policy.json
    ```
2. You can create an IAM role and attach an IAM policy to it using eksctl or the AWS Management Console. Select the desired tab for the following instructions.
-  a. Run the following command if you created your Amazon EKS cluster with eksctl. If you created your node groups using the --asg-access option, then replace AmazonEKSClusterAutoscalerPolicy with the name of the IAM policy that eksctl created for you. The policy name is similar to eksctl-my-cluster-nodegroup-ng-xxxxxxxx-PolicyAutoScaling
    ```
  eksctl create iamserviceaccount \
  --cluster=my-cluster \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::111122223333:policy/AmazonEKSClusterAutoscalerPolicy \
  --override-existing-serviceaccounts \
  --approve
    ```
# Deploy the Cluster Autoscaler
Complete the following steps to deploy the Cluster Autoscaler. We recommend that you review Deployment considerations and optimize the Cluster Autoscaler deployment before you deploy it to a production cluster.

To deploy the Cluster Autoscaler
1. Download the Cluster Autoscaler YAML file.
```
curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```
2. Modify the YAML file and replace <YOUR CLUSTER NAME> with your cluster name. Also consider replacing the cpu and memory values as determined by your environment.
3.Apply the YAML file to your cluster.
```
kubectl apply -f cluster-autoscaler-autodiscover.yaml
```
4.Annotate the cluster-autoscaler service account with the ARN of the IAM role that you created previously. Replace the example values with your own values.
```
kubectl annotate serviceaccount cluster-autoscaler \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/AmazonEKSClusterAutoscalerRole
```
5.Patch the deployment to add the cluster-autoscaler.kubernetes.io/safe-to-evict annotation to the Cluster Autoscaler pods with the following command.
```
kubectl patch deployment cluster-autoscaler \
  -n kube-system \
  -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'
```
6. Edit the Cluster Autoscaler deployment with the following command.
```
kubectl -n kube-system edit deployment.apps/cluster-autoscaler
```
Edit the cluster-autoscaler container command to add the following options. --balance-similar-node-groups ensures that there is enough available compute across all availability zones. --skip-nodes-with-system-pods=false ensures that there are no problems with scaling to zero.

--balance-similar-node-groups

--skip-nodes-with-system-pods=false
```
    spec:
      containers:
      - command
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
```
7. Open the Cluster Autoscaler [releases]("https://github.com/kubernetes/autoscaler/releases") page from GitHub   in a web browser and find the latest Cluster Autoscaler version that matches the Kubernetes major and minor version of your cluster. For example, if the Kubernetes version of your cluster is 1.24, find the latest Cluster Autoscaler release that begins with 1.24. Record the semantic version number (1.24.n) for that release to use in the next step.
8. Set the Cluster Autoscaler image tag to the version that you recorded in the previous step with the following command. Replace 1.24.n with your own value.
```
kubectl set image deployment cluster-autoscaler \
  -n kube-system \
  cluster-autoscaler=k8s.gcr.io/autoscaling/cluster-autoscaler:v1.24.n
```
# View your Cluster Autoscaler logs
After you have deployed the Cluster Autoscaler, you can view the logs and verify that it's monitoring your cluster load.

View your Cluster Autoscaler logs with the following command.
```
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```
The example output is as follows.
![](https://www.kubecost.com/images/verify-logs.png)

# To test our cluster-autoscaler 
We can use nginx.yaml file to deploy deployment with 2 replicas and test when our cluster-autoscaler add new nodes for pednging nodes 

# Issue during completion task
-  ASG does not work proreply i was not not able to deploy my deployment because it was not enough resource for deployment have to create increase number of ec2 manually
-  Our cluster version 1.23.13 but in repository no image for exact version in this case i have to chnage right image version for my container with changing images couple times intil i finaly could find right image for container
-  Created cluster AWS recomend create two types of nodes managed and unmanaged in our cluster we have only managed notes 
-  if you do not Annotate the cluster-autoscaler service account with the ARN of the IAM role quickly pods will have error "crashloopbackoff"
