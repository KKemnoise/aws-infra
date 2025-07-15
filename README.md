## Introduction

This Terraform project provisions a complete AWS EKS cluster, including:
- A dedicated VPC
- EKS control plane
- Predefined NodePools using Karpenter for On-Demand and Spot instances
- EC2NodeClass configurations optimized for multi-architecture (amd64, arm64)

Once deployed, users can use `kubectl` to apply their own Kubernetes manifests. Workloads are scheduled on the appropriate node groups using nodeSelector, taints, and labels already configured.

---

## Requirements

- Access to an AWS account with IAM permissions to create an EKS cluster
- AWS Cloud9 environment recommended (if following this guide step by step)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured
- [Kubernetes CLI (kubectl)](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) installed
- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) installed
- [Helm](https://helm.sh/docs/intro/install/) installed

---

## Supported Versions

| Resources/Tool                                                                 | Version    |
| ------------------------------------------------------------------------------ | ---------- |
| [Kubernetes](https://kubernetes.io/releases/)                                  | 1.32       |
| [Karpenter](https://github.com/aws/karpenter/releases)                         | v1.5.0     |
| [Terraform](https://github.com/hashicorp/terraform/releases)                   | v1.12.1    |
| [AWS EKS](https://github.com/terraform-aws-modules/terraform-aws-eks/releases) | v20.37.0   |
| [EKS Blueprints Addons](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/releases) | v1.21.0 |

AWS samples used for this project:  
https://github.com/aws-samples/?q=karpenter&type=all&language=&sort=