provider "aws" {
  region = local.region
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

provider "kubernetes" {
  host                   = local.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = local.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

locals {
  region               = var.aws_region
  eks_cluster_endpoint = data.aws_eks_cluster.this.endpoint
  tags = {
    Source = "github.com/aws-observability/observability-best-practices"
  }
}

module "eks_monitoring" {
  source = "../modules/eks-monitoring"

  eks_cluster_id = var.eks_cluster_name

  # reusing existing certificate manager? defaults to true
  enable_cert_manager = true

  # enable EKS API server monitoring
  enable_apiserver_monitoring = true

  # deploys external-secrets in to the cluster
  enable_external_secrets = true
  grafana_api_key         = var.grafana_api_key
  target_secret_name      = "grafana-admin-credentials"
  target_secret_namespace = "grafana-operator"
  grafana_url             = var.amg_endpoint

  # control the publishing of dashboards by specifying the boolean value for the variable 'enable_dashboards', default is 'true'
  enable_dashboards = var.enable_dashboards

  managed_prometheus_workspace_arn = var.amp_ws_arn

  # sets up the Amazon Managed Prometheus alert manager at the workspace level
  enable_alertmanager = true

  # optional, defaults to 60s interval and 15s timeout
  prometheus_config = {
    global_scrape_interval = "60s"
    global_scrape_timeout  = "15s"
  }

  enable_logs = true

  tags = local.tags
}
