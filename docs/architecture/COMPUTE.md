## Compute Architecture Plan – EKS-Based Microservices
## Objective

Design and document the compute layer architecture for Innovate Inc.’s microservices platform using Amazon Elastic Kubernetes Service (EKS), detailing workload distribution, environment segregation, and service integrations.

⸻

## Core Platform: Amazon EKS

Why EKS?
	•	Fully managed Kubernetes control plane
	•	Seamless integration with AWS IAM, VPC, and load balancers
	•	Native support for autoscaling, rolling deployments, and observability

EKS Cluster Details

Component	Description
Cluster Location	App Account
Node Group Type	Managed Node Groups (OnDemand + Spot)
Architectures	Multi-arch support: x86_64 and ARM64
Autoscaling	Enabled via Karpenter or Cluster Autoscaler
Networking	Private subnets, public ALB via Ingress


⸻

## Workload Distribution

Backend (Flask API)
	•	Packaged as container image
	•	Deployed using Kubernetes Deployment
	•	Exposed via Service (ClusterIP or LoadBalancer)
	•	Managed ingress via NGINX or ALB Ingress Controller
	•	Communicates with PostgreSQL database in Data Account

Frontend (React SPA)
	•	Packaged as static files (e.g. built via npm build)
	•	Two deployment strategies:
	1.	As container in EKS (served via NGINX)
	2.	[Recommended] Deployed to S3 + CloudFront for better performance
	•	Ingress exposed via same ALB or separate domain/subdomain

⸻

## Inter-Service Communication

Source	Destination	Protocol	Method
Frontend Pod	Backend Service	HTTP/HTTPS	Internal DNS or Ingress
Backend Pod	RDS (Aurora)	TCP	Port 5432 via Transit Gateway
Backend Pod	Secrets Manager / IAM	HTTPS	IAM Role via IRSA


⸻

## IAM and Permissions
	•	Each microservice uses IRSA (IAM Roles for Service Accounts)
	•	Fine-grained permissions for accessing:
	•	Secrets Manager (for DB credentials)
	•	S3 buckets (if needed)
	•	CloudWatch Logs

⸻

## Observability and Resilience
	•	Logs: CloudWatch Logs via Fluent Bit or aws-for-fluent-bit
	•	Metrics: Prometheus + Grafana or CloudWatch Container Insights
	•	Health checks: Kubernetes livenessProbe and readinessProbe
	•	Autoscaling: Karpenter or HPA based on CPU/memory

⸻

## CI/CD and Deployment
	•	Code pushed to GitHub triggers CI/CD via GitHub Actions or CodePipeline
	•	Artifacts built and pushed to Amazon ECR
	•	Deployments applied using Helm or kubectl
	•	Supports blue/green or canary strategies

⸻

## Summary

This compute layer delivers a robust and cloud-native foundation for Innovate Inc.’s microservices-based application, ensuring:
	•	Separation of concerns (frontend/backend)
	•	Integration with secure and scalable PostgreSQL backend
	•	Efficient and maintainable Kubernetes operations

The EKS platform will serve as the central orchestrator for all application services while communicating securely with data and infrastructure services across accounts.

⸻

Authored by: [Your Company or Team]
Date: [Insert Date]
