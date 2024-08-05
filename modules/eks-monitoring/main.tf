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
  name        = "flux-source-controller-policy"
  description = "Policy for Flux Source Controller to access S3 bucket"
  policy      = data.aws_iam_policy_document.flux_source_controller_policy.json
}

data "aws_iam_policy_document" "flux_source_controller_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", "")}:sub"
      values   = ["system:serviceaccount:flux-system:source-controller"]
    }
  }
}

resource "aws_iam_role" "flux_source_controller_role" {
  name               = "flux-source-controller-role"
  assume_role_policy = data.aws_iam_policy_document.flux_source_controller_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "flux_source_controller_policy_attachment" {
  role       = aws_iam_role.flux_source_controller_role.name
  policy_arn = aws_iam_policy.flux_source_controller_policy.arn
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

resource "aws_iam_openid_connect_provider" "cluster" {
  count = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer != "" ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  lifecycle {
    ignore_changes = [url, thumbprint_list]
  }
}

resource "aws_prometheus_scraper" "this" {
  source {
    eks {
      cluster_arn = local.eks_cluster_arn

      // AMP scraper only accepts up to 5 subnets
      subnet_ids = slice(tolist(local.eks_cluster_subnet_ids), 0, min(length(local.eks_cluster_subnet_ids), 5))
    }
  }

  destination {
    amp {
      workspace_arn = local.managed_prometheus_workspace_arn
    }
  }

  scrape_configuration = replace(replace(file("${path.module}/amp-config/scraper-config.yaml"), "{{CLUSTER_NAME}}", var.eks_cluster_id), "{{VERSION_NUMBER}}", "2.0")
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
