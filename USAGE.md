# Usage

## Cluster Creation

1. **Clone this repository and enter the `cluster/terraform` folder.**

2. **Initialize and apply Terraform modules:**
    ```sh
    helm registry logout public.ecr.aws
    export TF_VAR_region=$AWS_REGION
    terraform init
    terraform plan
    terraform apply -target="module.vpc" -auto-approve
    terraform apply -target="module.eks" -auto-approve
    terraform apply --auto-approve
    ```

3. **(Optional) Enable Spot Instances:**  
   If you have never launched a Spot instance before, run:
    ```sh
    aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
    ```
   Ignore any errors if the role already exists.

4. **Update kubeconfig:**
    ```sh
    aws eks --region $AWS_REGION update-kubeconfig --name karpenter
    ```

5. **Verify cluster and Karpenter:**
    ```sh
    kubectl get pods -n karpenter
    # Output should show Karpenter pods running
    ```

6. **List Karpenter resources:**
    ```sh
    kubectl get nodepool
    kubectl get ec2nodeclass
    ```

---

## Deploying Your Manifests

### Prerequisites

- EKS cluster deployed using Terraform
- Karpenter controller running
    ```sh
    kubectl get pods -n karpenter
    ```
- NodePools and EC2NodeClasses created
    ```sh
    kubectl get nodepool
    kubectl get ec2nodeclass
    ```

### Required Node Selectors and Tolerations

Add these to your manifest to target Spot/On-Demand and architecture:

```yaml
nodeSelector:
  karpenter.sh/capacity-type: "spot"      # or "on-demand"
  intent: "spot"                          # or "ondemand"
  kubernetes.io/arch: "arm64"             # or "amd64"

tolerations:
- key: "workload"
  operator: "Equal"
  value: "spot"                           # or "ondemand"
  effect: "NoSchedule"


Example: Create a CronJob on Spot Instances
kubectl apply -f examples/cronjob-spot.yaml
kubectl get cronjob
kubectl get jobs --watch

Example: Create a Deployment on On-Demand Instances
kubectl apply -f examples/deployment-ondemand.yaml
kubectl get deploy
kubectl get pods -o wide

Verify Node Type:
kubectl get nodes \
  --label-columns=karpenter.sh/capacity-type,kubernetes.io/arch