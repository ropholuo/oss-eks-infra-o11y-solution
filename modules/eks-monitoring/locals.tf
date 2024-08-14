data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "eks_cluster" {
  name = var.eks_cluster_id
}

data "tls_certificate" "cluster" {
  url = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

locals {
  arn_parts = split(":", var.managed_prometheus_workspace_arn)
  managed_prometheus_workspace_region = local.arn_parts[3]
  managed_prometheus_workspace_id = split("/", local.arn_parts[5])[1]
  managed_prometheus_workspace_endpoint = "https://aps-workspaces.${local.managed_prometheus_workspace_region}.amazonaws.com/workspaces/${local.managed_prometheus_workspace_id}"

  name                      = "oso-observability-best-practices-prometheus"
  kube_service_account_name = try(var.helm_config.service_account, local.name)
  namespace                 = try(var.helm_config.namespace, local.name)

  eks_oidc_issuer_url  = replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")
  eks_cluster_endpoint = data.aws_eks_cluster.eks_cluster.endpoint
  eks_cluster_version  = data.aws_eks_cluster.eks_cluster.version
  eks_cluster_arn      = data.aws_eks_cluster.eks_cluster.arn
  eks_cluster_subnet_ids = data.aws_eks_cluster.eks_cluster.vpc_config[0].subnet_ids

  context = {
    aws_caller_identity_account_id = data.aws_caller_identity.current.account_id
    aws_caller_identity_arn        = data.aws_caller_identity.current.arn
    aws_eks_cluster_endpoint       = local.eks_cluster_endpoint
    aws_partition_id               = data.aws_partition.current.partition
    aws_region_name                = data.aws_region.current.name
    eks_cluster_id                 = var.eks_cluster_id
    eks_oidc_issuer_url            = local.eks_oidc_issuer_url
    eks_oidc_provider_arn          = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.eks_oidc_issuer_url}"
    tags                           = var.tags
    irsa_iam_role_path             = var.irsa_iam_role_path
    irsa_iam_permissions_boundary  = var.irsa_iam_permissions_boundary
  }

  apiserver_monitoring_config = {
    # can be overriden by providing a config
    flux_bucket_name   = try(var.apiserver_monitoring_config.flux_bucket_name, var.flux_bucket_name)
    flux_kustomization_name   = try(var.apiserver_monitoring_config.flux_kustomization_name, "grafana-dashboards-apiserver")
    flux_kustomization_path   = try(var.apiserver_monitoring_config.flux_kustomization_path, "EKS/OSS/CDK/v3.0.0/apiserver")

    dashboards = {
      basic           = try(var.apiserver_monitoring_config.dashboards.basic, var.grafana_apiserver_basic_dashboard_url)
      advanced        = try(var.apiserver_monitoring_config.dashboards.advanced, var.grafana_apiserver_advanced_dashboard_url)
      troubleshooting = try(var.apiserver_monitoring_config.dashboards.troubleshooting, var.grafana_apiserver_troubleshooting_dashboard_url)
    }
  }
}
