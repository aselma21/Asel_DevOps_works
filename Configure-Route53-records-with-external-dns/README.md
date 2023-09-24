# devops-tools-22j-centos
## ExternalDNS Configuration on AWS Route53

This repository includes the necessary files and instructions to set up ExternalDNS to add DNS records on AWS Route53.

## Included Files
- Kubernetes yaml files for the ExternalDNS deployment
- ExternalDNS IAM Policy along with Trust Policy

## Instructions

## Step 1: Setting up the identity provider
To set up an identity provider, you will need to specify a type of identity provider, an audience, and a provider URL. In this case, the provider type used was OpenId Connect and the audience was sts.amazonaws.com. Follow the instructions in the following link to create an identity provider:

```https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html```

To get the provider URL, run the following command:

```aws eks describe-cluster --name EKS_centos_cluster --region us-east-1 --query "cluster.identity.oidc.issuer" --output text```

The output should look like this:

```https://oidc.eks.<region>.amazonaws.com/id/EXAMPLE86F27C29EF05B482628D9790EA7066```

With the necessary information, go to the identity provider section (https://console.aws.amazon.com/iamv2/home?#/identity_providers) of IAM in the AWS console and create a new provider.


## Step 2: Setting up the IAM Role

- Create an IAM policy that allows ExternalDNS to update Route53 Resource Record Sets.
- Create an IAM role and set the OIDC provider using the instructions in the following link:
https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html

- Attach the necessary policies (such as IAMFullAccess, ReadOnlyAccess, and AmazonEKSClusterPolicy) to the IAM role.
- Create a new service account, cluster role, and create a cluster role binding. Assign the ARN of the DnsAccessRoleForProject to the specific service account. To associate an IAM role to a service account, you can use the following link: https://docs.aws.amazon.com/eks/latest/userguide/specify-service-account-role.html or specify the ARN of the IAM role in the service account annotations inside the service account yaml file.

## ExternalDNS
The ExternalDNS architecture consists of two main components: the ExternalDNS controller and the DNS provider.
The ExternalDNS controller runs as a pod in the Kubernetes cluster and watches for changes to services and ingress resources.
When a change is detected, the controller will update the DNS provider with the updated information.
The DNS provider is the external service that ExternalDNS interacts with to manage the DNS records.

## Troubleshooting

- When creating a service account for ExternalDNS, ensure that it is updated in the deployment yaml file and the correct namespace is specified.
- The --txt-owner-id argument in the deployment yaml is not the name of the EKS cluster. 
- If you encounter issues with the cluster role binding, it may be because the ExternalDNS service account name differs from what is specified in the cluster role binding subject field.
- The ClusterRole needs to have access control policy that allows read-only access to certain resources in a Kubernetes cluster. 


## Additional Resources

Here are some links that may be helpful when setting up ExternalDNS:

[Setting up ExternalDNS for Services on AWS](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md)

[Kubernetes: update AWS Route53 DNS from an Ingress](https://itnext.io/kubernetes-update-aws-route53-dns-from-an-ingress-1c3a8068f9fe)

[Issues with connecting two accounts](https://github.com/kubernetes-sigs/external-dns/issues/1608)

[Provide external access to multiple Kubernetes services](https://aws.amazon.com/premiumsupport/knowledge-center/eks-access-kubernetes-services/)

[Setting up the identity provider](https://www.padok.fr/en/blog/external-dns-route53-eks)

[Creating an IAM role and policy for your service account](https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html)

[Create an IAM OIDC provider for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)

[Associate an IAM role to a service account](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
