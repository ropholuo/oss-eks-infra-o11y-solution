resource "aws_prometheus_workspace" "this" {
  count = var.enable_managed_prometheus ? 1 : 0

  alias = local.name
  tags  = var.tags
}

resource "helm_release" "kube_state_metrics" {
  count            = var.enable_kube_state_metrics ? 1 : 0
  chart            = var.ksm_config.helm_chart_name
  create_namespace = var.ksm_config.create_namespace
  namespace        = var.ksm_config.k8s_namespace
  name             = var.ksm_config.helm_release_name
  version          = var.ksm_config.helm_chart_version
  repository       = var.ksm_config.helm_repo_url

  dynamic "set" {
    for_each = var.ksm_config.helm_settings
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "helm_release" "prometheus_node_exporter" {
  count            = var.enable_node_exporter ? 1 : 0
  chart            = var.ne_config.helm_chart_name
  create_namespace = var.ne_config.create_namespace
  namespace        = var.ne_config.k8s_namespace
  name             = var.ne_config.helm_release_name
  version          = var.ne_config.helm_chart_version
  repository       = var.ne_config.helm_repo_url

  dynamic "set" {
    for_each = var.ne_config.helm_settings
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "helm_release" "fluxcd" {
  count            = var.enable_fluxcd ? 1 : 0
  chart            = var.flux_config.helm_chart_name
  create_namespace = var.flux_config.create_namespace
  namespace        = var.flux_config.k8s_namespace
  name             = var.flux_config.helm_release_name
  version          = var.flux_config.helm_chart_version
  repository       = var.flux_config.helm_repo_url

  dynamic "set" {
    for_each = var.flux_config.helm_settings
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "helm_release" "grafana_operator" {
  count            = var.enable_grafana_operator ? 1 : 0
  chart            = var.go_config.helm_chart
  name             = var.go_config.helm_name
  namespace        = var.go_config.k8s_namespace
  version          = var.go_config.helm_chart_version
  create_namespace = var.go_config.create_namespace
  max_history      = 3
}

resource "aws_prometheus_scraper" "this" {
  source {
    eks {
      cluster_arn = local.eks_cluster_arn

      // AMP scraper only takes up to 5 subnets
      subnet_ids  = slice(tolist(local.eks_cluster_subnet_ids), 0, min(length(local.eks_cluster_subnet_ids), 4))
    }
  }

  destination {
    amp {
      workspace_arn = local.managed_prometheus_workspace_arn
    }
  }

  scrape_configuration = replace(replace(file("${path.module}/amp-config/scraper-config.yaml"), "{{CLUSTER_NAME}}", var.eks_cluster_id), "{{VERSION_NUMBER}}", "3.0")
}

resource "kubernetes_deployment" "jmx_exporter" {
  count = var.jmx_exporter_img_url != "" ? 1 : 0

  metadata {
    name = "jmx-exporter"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "jmx-exporter"
      }
    }
    template {
      metadata {
        labels = {
          app = "jmx-exporter"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "1234"
        }
      }
      spec {
        container {
          name  = "jmx-prometheus-exporter"
          image = var.jmx_exporter_img_url
          port {
            container_port = 1234
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "load_balancer" {
  count = var.jmx_exporter_img_url != "" ? 1 : 0

  metadata {
    name = "jmx-exporter-service"
  }
  spec {
    type = "LoadBalancer"
    port {
      port        = 1234
      target_port = 1234
    }
    selector = {
      app = "jmx-exporter"
    }
  }
}

module "external_secrets" {
  source = "./add-ons/external-secrets"
  count  = var.enable_external_secrets ? 1 : 0

  enable_external_secrets = var.enable_external_secrets
  grafana_api_key         = var.grafana_api_key
  addon_context           = local.context
  target_secret_namespace = var.target_secret_namespace
  target_secret_name      = var.target_secret_name

  depends_on = [resource.helm_release.grafana_operator]
}

module "amazon_cloudwatch_observability" {
  source = "./add-ons/amazon-cloudwatch-observability"
  count  = var.enable_logs ? 1 : 0

  addon_context = local.context
}