locals {
  karpenter_namespace = "karpenter"
}

################################################################################
# Controller & Node IAM roles, SQS Queue, Eventbridge Rules
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.37.0"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true
  namespace             = local.karpenter_namespace

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = local.name
  create_pod_identity_association = true

  tags = local.tags
}

################################################################################
# Helm charts
################################################################################

resource "helm_release" "karpenter" {
  name                = "karpenter"
  namespace           = local.karpenter_namespace
  create_namespace    = true
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.5.0"
  wait                = false

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: karpenter.sh/controller
        operator: Exists
        effect: NoSchedule
    webhook:
      enabled: false
    EOT
  ]

  lifecycle {
    ignore_changes = [
      repository_password
    ]
  }
}

# Karpenter  EC2NodeClass and NodePool arm mixed and for ondemand and spot

resource "kubectl_manifest" "karpenter_ec2_node_class_spot" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: karpenter-spot-class
    spec:
      role: "${module.karpenter.node_iam_role_name}"
      amiSelectorTerms:
        - alias: al2023@latest
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        intent: spot
        karpenter.sh/discovery: ${module.eks.cluster_name}
        project: karpenter
  YAML

  depends_on = [
    helm_release.karpenter,
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_spot" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: karpenter-spot-pool
    spec:
      template:
        metadata:
          labels:
            intent: spot
        spec:
          taints:
            - key: workload
              value: spot
              effect: NoSchedule
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64", "arm64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["m", "c", "t"]
            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["large", "xlarge"]
          nodeClassRef:
            name: karpenter_ec2_node_class_spot
            group: karpenter.k8s.aws
            kind: EC2NodeClass
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 60s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_ec2_node_class_spot
  ]
}

resource "kubectl_manifest" "karpenter_ec2_node_class_ondemand" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: karpenter-ondemand-class
    spec:
      role: "${module.karpenter.node_iam_role_name}"
      amiSelectorTerms:
        - alias: al2023@latest
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        intent: ondemand
        karpenter.sh/discovery: ${module.eks.cluster_name}
        project: karpenter
  YAML

  depends_on = [
    helm_release.karpenter,
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_ondemand" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: karpenter-ondemand-pool
    spec:
      template:
        metadata:
          labels:
            intent: ondemand
        spec:
          taints:
            - key: workload
              value: ondemand
              effect: NoSchedule
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64", "arm64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r", "t", "i"] # Categorías recomendadas para on-demand
            - key: karpenter.k8s.aws/instance-cpu
              operator: Gt
              values: ["2"]
          nodeClassRef:
            name: karpenter_ec2_node_class_ondemand
            group: karpenter.k8s.aws
            kind: EC2NodeClass
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 60s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_ec2_node_class_ondemand
  ]
}