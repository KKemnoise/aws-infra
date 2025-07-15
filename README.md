### Requirements

* You need access to an AWS account with IAM permissions to create an EKS cluster, and an AWS Cloud9 environment if you're running the commands listed in this tutorial.
* Install and configure the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* Install the [Kubernetes CLI (kubectl)](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* Install the [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
* Install Helm ([the package manager for Kubernetes](https://helm.sh/docs/intro/install/))


#### Create an EKS Cluster using Terraform (Optional)

You'll create an Amazon EKS cluster. The Terraform template included in this repository is going to create a VPC, an EKS control plane, and a Kubernetes service account along with the IAM role and associate them using IAM Roles for Service Accounts (IRSA) to let Karpenter launch instances. Additionally, the template configures the Karpenter node role to the `aws-auth` configmap to allow nodes to connect, and creates an On-Demand managed node group for the `kube-system` and `karpenter` namespaces.

To create the cluster, clone this repository and open the `cluster/terraform` folder. Then, run the following commands:

```sh
helm registry logout public.ecr.aws
export TF_VAR_region=$AWS_REGION
terraform init
terraform plan
terraform apply -target="module.vpc" -auto-approve
terraform apply -target="module.eks" -auto-approve
terraform apply --auto-approve
```

Before you continue, you need to enable your AWS account to launch Spot instances if you haven't launch any yet. To do so, create the [service-linked role for Spot](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-requests.html#service-linked-roles-spot-instance-requests) by running the following command:

```sh
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
```

You might see the following error if the role has already been successfully created. You don't need to worry about this error, you simply had to run the above command to make sure you have the service-linked role to launch Spot instances:

```console
An error occurred (InvalidInput) when calling the CreateServiceLinkedRole operation: Service role name AWSServiceRoleForEC2Spot has been taken in this account, please try a different suffix.
```

Once complete (after waiting about 15 minutes), run the following command to update the `kube.config` file to interact with the cluster through `kubectl`:

```sh
aws eks --region $AWS_REGION update-kubeconfig --name karpenter
```

You need to make sure you can interact with the cluster and that the Karpenter pods are running:

```sh
$> kubectl get pods -n karpenter
NAME                       READY STATUS  RESTARTS AGE
karpenter-5f97c944df-bm85s 1/1   Running 0        15m
karpenter-5f97c944df-xr9jf 1/1   Running 0        15m
```

You can now proceed to deploy the default Karpenter NodePool, and deploy any blueprint you want to test.

#### Deploy a Karpenter Default EC2NodeClass and NodePool

```sh
kubectl get nodepool
```

```sh
kubectl get ec2nodeclass
```


You can now proceed to deploy any blueprint you want to test.


## Deploying your manifest with kubectl

PREREQUISITES
-------------
- EKS cluster deployed using Terraform
- Karpenter controller running:
    kubectl get pods -n karpenter
- NodePools and EC2NodeClasses created:
    kubectl get nodepool
    kubectl get ec2nodeclass

REQUIRED NODE SELECTORS
-----------------------
To ensure pods are scheduled correctly, set the following selectors and tolerations in your manifests:

nodeSelector:
  karpenter.sh/capacity-type: "spot"         # or "on-demand"
  intent: "spot"                              # or "ondemand"
  kubernetes.io/arch: "arm64"                 # or "amd64"

tolerations:
- key: "workload"
  operator: "Equal"
  value: "spot"                               # or "ondemand"
  effect: "NoSchedule"

CREATE A CRONJOB ON SPOT INSTANCES
----------------------------------
kubectl apply -f examples/cronjob-spot.yaml

Verify:
kubectl get cronjob
kubectl get jobs --watch

CREATE A DEPLOYMENT ON ON-DEMAND INSTANCES
------------------------------------------
kubectl apply -f examples/deployment-ondemand.yaml

Verify:
kubectl get deploy
kubectl get pods -o wide

VERIFY NODE TYPE
----------------
kubectl get nodes \
  --label-columns=karpenter.sh/capacity-type,kubernetes.io/arch

Expected labels:
karpenter.sh/capacity-type = spot / on-demand
kubernetes.io/arch         = arm64 / amd64

CLEANUP
-------
kubectl delete -f examples/cronjob-spot.yaml
kubectl delete -f examples/deployment-ondemand.yaml

#### Terraform Cleanup  (Optional)

Once you're done with testing , if you used the Terraform template from this repository, you can proceed to remove all the resources that Terraform created. To do so, run the following commands:

```sh
kubectl delete --all nodeclaim
kubectl delete --all nodepool
kubectl delete --all ec2nodeclass
export TF_VAR_region=$AWS_REGION
terraform destroy -target="module.eks_blueprints_addons" --auto-approve
terraform destroy -target="module.eks" --auto-approve
terraform destroy --auto-approve
```



## Supported Versions

The following table describes the list of resources along with the versions where the blueprints in this repo have been tested.

| Resources/Tool  | Version             |
| --------------- | ------------------- |
| [Kubernetes](https://kubernetes.io/releases/)      | 1.32                |
| [Karpenter](https://github.com/aws/karpenter/releases)       | v1.5.0            |
| [Terraform](https://github.com/hashicorp/terraform/releases)       | v1.12.1            |
| [AWS EKS](https://github.com/terraform-aws-modules/terraform-aws-eks/releases)  | v20.37.0             |
| [EKS Blueprints Addons](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/releases)  | v1.21.0              |

