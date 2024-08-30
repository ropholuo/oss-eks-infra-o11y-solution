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

/** 
  Nginx
*/
module "operator" {
  source = "./add-ons/adot-operator"
  count  = 1

  enable_cert_manager = var.enable_cert_manager
  kubernetes_version  = local.eks_cluster_version
  addon_context       = local.context
}

module "helm_addon" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons/helm-addon?ref=v4.32.1"

  helm_config = merge(
    {
      name        = local.name
      chart       = "${path.module}/otel-config"
      namespace   = local.namespace
      description = "ADOT helm Chart deployment configuration"
    },
    var.helm_config
  )

  set_values = [
    {
      name  = "ampurl"
      value = "${local.managed_prometheus_workspace_endpoint}/api/v1/remote_write"
    },
    {
      name  = "region"
      value = local.managed_prometheus_workspace_region
    },
    {
      name  = "assumeRoleArn"
      value = var.managed_prometheus_cross_account_role
    },
    {
      name  = "ekscluster"
      value = local.context.eks_cluster_id
    },
    {
      name  = "globalScrapeInterval"
      value = var.prometheus_config.global_scrape_interval
    },
    {
      name  = "globalScrapeTimeout"
      value = var.prometheus_config.global_scrape_timeout
    },
    {
      name  = "adotLoglevel"
      value = "normal"
    },
    {
      name  = "adotServiceTelemetryLoglevel"
      value = "INFO"
    },
    {
      name  = "accountId"
      value = local.context.aws_caller_identity_account_id
    },
    {
      name  = "enableTracing"
      value = var.enable_tracing
    },
    {
      name  = "otlpHttpEndpoint"
      value = var.tracing_config.otlp_http_endpoint
    },
    {
      name  = "otlpGrpcEndpoint"
      value = var.tracing_config.otlp_grpc_endpoint
    },
    {
      name  = "tracingTimeout"
      value = var.tracing_config.timeout
    },
    {
      name  = "tracingSendBatchSize"
      value = var.tracing_config.send_batch_size
    },
    {
      name  = "enableCustomMetrics"
      value = var.enable_custom_metrics
    },
    {
      name  = "customMetrics"
      value = yamlencode(var.custom_metrics_config)
    },
    {
      name  = "nginxScrapeSampleLimit"
      value = local.nginx_pattern_config.scrape_sample_limit
    },
    {
      name  = "nginxPrometheusMetricsEndpoint"
      value = local.nginx_pattern_config.prometheus_metrics_endpoint
    },
    {
      name  = "enableAdotcollectorMetrics"
      value = true
    },
    {
      name  = "serviceAccount"
      value = local.kube_service_account_name
    },
    {
      name  = "namespace"
      value = local.namespace
    }
  ]

  irsa_iam_role_name = var.irsa_iam_role_name
  irsa_config = {
    create_kubernetes_namespace       = true
    kubernetes_namespace              = local.namespace
    create_kubernetes_service_account = true
    kubernetes_service_account        = local.kube_service_account_name
    irsa_iam_policies = flatten([
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonPrometheusRemoteWriteAccess",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXrayWriteOnlyAccess",
      var.irsa_iam_additional_policies,
    ])
  }

  addon_context = local.context

  depends_on = [module.operator]
}

module "nginx_monitoring" {
  source = "./nginx"
  count  = 1

  pattern_config = local.nginx_pattern_config
}

/**
 *  FluxCD
 */

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

  depends_on = [
    kubernetes_service_account.flux_source_controller
  ]
}

data "aws_iam_policy_document" "flux_source_controller_policy" {
  statement {
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.flux_bucket_name}",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${var.flux_bucket_name}/*",
    ]
  }
}

resource "aws_iam_policy" "flux_source_controller_policy" {
  name        = "flux-source-controller-policy-${var.eks_cluster_id}"
  description = "Policy for Flux Source Controller to access S3 bucket"
  policy      = data.aws_iam_policy_document.flux_source_controller_policy.json
}

data "aws_iam_policy_document" "flux_source_controller_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:flux-system:source-controller"]
    }
  }
}

resource "aws_iam_role" "flux_source_controller_role" {
  name               = "flux-source-controller-role-${var.eks_cluster_id}"
  assume_role_policy = data.aws_iam_policy_document.flux_source_controller_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "flux_source_controller_policy_attachment" {
  role       = aws_iam_role.flux_source_controller_role.name
  policy_arn = aws_iam_policy.flux_source_controller_policy.arn
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_service_account" "flux_source_controller" {
  metadata {
    name      = "source-controller"
    namespace = "flux-system"
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.flux_source_controller_role.arn
      "meta.helm.sh/release-name"      = var.flux_config.helm_release_name
      "meta.helm.sh/release-namespace" = var.flux_config.k8s_namespace
    }
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  depends_on = [ kubernetes_namespace.flux_system ]
}

/**
 *  Grafana Operator
 */

resource "helm_release" "grafana_operator" {
  count            = var.enable_grafana_operator ? 1 : 0
  chart            = var.go_config.helm_chart
  name             = var.go_config.helm_name
  namespace        = var.go_config.k8s_namespace
  version          = var.go_config.helm_chart_version
  create_namespace = var.go_config.create_namespace
  max_history      = 3
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

/**
 *  Prometheus Scraper
 */

// AMP Scraper only accept unique subnet per AZ
locals {
  subnets_by_az = { for subnet in local.eks_cluster_subnet_ids : subnet => data.aws_subnet.this[subnet].availability_zone }
  unique_azs    = distinct(values(local.subnets_by_az))
  filtered_subnets = [
    for az in local.unique_azs :
    keys(local.subnets_by_az)[index(values(local.subnets_by_az), az)]
  ]
}

data "aws_subnet" "this" {
  for_each = toset(local.eks_cluster_subnet_ids)
  id       = each.value
}

resource "aws_prometheus_scraper" "this" {
  source {
    eks {
      cluster_arn = local.eks_cluster_arn
      // AMP Scraper only accept up to 5 subnets
      subnet_ids = slice(local.filtered_subnets, 0, min(length(local.filtered_subnets), 5))
    }
  }

  destination {
    amp {
      workspace_arn = var.managed_prometheus_workspace_arn
    }
  }

  scrape_configuration = replace(replace(file("${path.module}/amp-config/scraper-config.yaml"), "{{CLUSTER_NAME}}", var.eks_cluster_id), "{{VERSION_NUMBER}}", "3.0")
}

/**
 *  External Secrets
 */
 
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
