variable "eks_cluster_id" {
  description = "EKS Cluster Id"
  type        = string
}

variable "enable_managed_prometheus" {
  description = "Creates a new Amazon Managed Service for Prometheus Workspace"
  type        = bool
  default     = true
}

variable "enable_alertmanager" {
  description = "Creates Amazon Managed Service for Prometheus AlertManager for all workloads"
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Allow reusing an existing installation of cert-manager"
  type        = bool
  default     = true
}

variable "helm_config" {
  description = "Helm Config for Prometheus"
  type        = any
  default     = {}
}

variable "irsa_iam_role_name" {
  description = "IAM role name for IRSA roles"
  type        = string
  default     = ""
}

variable "irsa_iam_role_path" {
  description = "IAM role path for IRSA roles"
  type        = string
  default     = "/"
}

variable "irsa_iam_permissions_boundary" {
  description = "IAM permissions boundary for IRSA roles"
  type        = string
  default     = null
}

variable "irsa_iam_additional_policies" {
  description = "IAM additional policies for IRSA roles"
  type        = list(string)
  default     = []
}

variable "managed_prometheus_workspace_endpoint" {
  description = "Amazon Managed Prometheus Workspace Endpoint"
  type        = string
  default     = ""
}

variable "managed_prometheus_workspace_id" {
  description = "Amazon Managed Prometheus Workspace ID"
  type        = string
  default     = null
}

variable "managed_prometheus_workspace_region" {
  description = "Amazon Managed Prometheus Workspace's Region"
  type        = string
  default     = null
}

variable "managed_prometheus_cross_account_role" {
  description = "Amazon Managed Prometheus Workspace's Account Role Arn"
  type        = string
  default     = ""
}

variable "enable_alerting_rules" {
  description = "Enables or disables Managed Prometheus alerting rules"
  type        = bool
  default     = true
}

variable "enable_recording_rules" {
  description = "Enables or disables Managed Prometheus recording rules"
  type        = bool
  default     = true
}

variable "enable_dashboards" {
  description = "Enables or disables curated dashboards"
  type        = bool
  default     = true
}

variable "flux_bucket_name" {
  description = "Flux bucket name"
  type        = string
  # default     = "aws-observability-solutions"
  default = "obs-solutions"
}

variable "flux_bucket_region" {
  description = "Flux bucket region"
  type        = string
  default     = "us-east-1"
}

variable "flux_bucket_path" {
  description = "Flux bucket prefix path"
  type        = string
  default     = "EKS/OSS/CDK/v3.0.0"
}

variable "flux_bucket_endpoint" {
  description = "Flux bucket endpoint"
  type        = string
  default     = "s3.us-east-1.amazonaws.com"
}

variable "flux_kustomization_name" {
  description = "Flux Kustomization name"
  type        = string
  default     = "grafana-dashboards-infrastructure"
}

variable "flux_kustomization_path" {
  description = "Flux Kustomization Path"
  type        = string
  default     = "EKS/OSS/CDK/v3.0.0/infrastructure"
}

variable "enable_kube_state_metrics" {
  description = "Enables or disables Kube State metrics exporter. Disabling this might affect some data in the dashboards"
  type        = bool
  default     = true
}

variable "ksm_config" {
  description = "Kube State metrics configuration"
  type = object({
    create_namespace   = optional(bool, true)
    k8s_namespace      = optional(string, "kube-system")
    helm_chart_name    = optional(string, "kube-state-metrics")
    helm_chart_version = optional(string, "5.15.2")
    helm_release_name  = optional(string, "kube-state-metrics")
    helm_repo_url      = optional(string, "https://prometheus-community.github.io/helm-charts")
    helm_settings      = optional(map(string), {})
    helm_values        = optional(map(any), {})

    scrape_interval = optional(string, "60s")
    scrape_timeout  = optional(string, "15s")
  })

  default  = {}
  nullable = false
}

variable "enable_node_exporter" {
  description = "Enables or disables Node exporter. Disabling this might affect some data in the dashboards"
  type        = bool
  default     = true
}

variable "ne_config" {
  description = "Node exporter configuration"
  type = object({
    create_namespace   = optional(bool, true)
    k8s_namespace      = optional(string, "prometheus-node-exporter")
    helm_chart_name    = optional(string, "prometheus-node-exporter")
    helm_chart_version = optional(string, "4.24.0")
    helm_release_name  = optional(string, "prometheus-node-exporter")
    helm_repo_url      = optional(string, "https://prometheus-community.github.io/helm-charts")
    helm_settings      = optional(map(string), {})
    helm_values        = optional(map(any), {})

    scrape_interval = optional(string, "60s")
    scrape_timeout  = optional(string, "60s")
  })

  default  = {}
  nullable = false
}

variable "tags" {
  description = "Additional tags (e.g. `map('BusinessUnit`,`XYZ`)"
  type        = map(string)
  default     = {}
}

variable "prometheus_config" {
  description = "Controls default values such as scrape interval, timeouts and ports globally"
  type = object({
    global_scrape_interval = optional(string, "120s")
    global_scrape_timeout  = optional(string, "15s")
  })

  default  = {}
  nullable = false
}

variable "enable_apiserver_monitoring" {
  description = "Enable EKS kube-apiserver monitoring, alerting and dashboards"
  type        = bool
  default     = true
}

variable "apiserver_monitoring_config" {
  description = "Config object for API server monitoring"
  type = object({
    flux_bucket_name        = string
    flux_kustomization_name = string
    flux_kustomization_path = string

    dashboards = object({
      basic           = string
      advanced        = string
      troubleshooting = string
    })
  })

  # defaults are pre-computed in locals.tf, provide a full definition to override
  default = null
}

variable "enable_tracing" {
  description = "Enables tracing with OTLP traces receiver to X-Ray"
  type        = bool
  default     = true
}

variable "tracing_config" {
  description = "Configuration object for traces collection to AWS X-Ray"
  type = object({
    otlp_grpc_endpoint = optional(string, "0.0.0.0:4317")
    otlp_http_endpoint = optional(string, "0.0.0.0:4318")
    send_batch_size    = optional(number, 50)
    timeout            = optional(string, "30s")
  })

  default  = {}
  nullable = false
}

variable "enable_custom_metrics" {
  description = "Allows additional metrics collection for config elements in the `custom_metrics_config` config object. Automatic dashboards are not included"
  type        = bool
  default     = false
}

variable "custom_metrics_config" {
  description = "Configuration object to enable custom metrics collection"
  type = map(object({
    enableBasicAuth       = bool
    path                  = string
    basicAuthUsername     = string
    basicAuthPassword     = string
    ports                 = string
    droppedSeriesPrefixes = string
  }))

  default = null
}

variable "enable_logs" {
  description = "Using AWS For FluentBit to collect cluster and application logs to Amazon CloudWatch"
  type        = bool
  default     = true
}

variable "logs_config" {
  description = "Configuration object for logs collection"
  type = object({
    cw_log_retention_days = number
  })

  default = {
    # Valid values are  [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653]
    cw_log_retention_days = 90
  }
}

variable "enable_fluxcd" {
  description = "Enables or disables FluxCD. Disabling this might affect some data in the dashboards"
  type        = bool
  default     = true
}

variable "flux_config" {
  description = "FluxCD configuration"
  type = object({
    create_namespace   = optional(bool, true)
    k8s_namespace      = optional(string, "flux-system")
    helm_chart_name    = optional(string, "flux2")
    helm_chart_version = optional(string, "2.12.2")
    helm_release_name  = optional(string, "observability-fluxcd-addon")
    helm_repo_url      = optional(string, "https://fluxcd-community.github.io/helm-charts")
    helm_settings = optional(map(string), {
      "serviceAccount.create" = "false"
      "serviceAccount.name"   = "source-controller"
    })
    helm_values = optional(map(any), {})
  })

  default  = {}
  nullable = false
}

variable "enable_grafana_operator" {
  description = "Deploys Grafana Operator to EKS Cluster"
  type        = bool
  default     = true
}

variable "go_config" {
  description = "Grafana Operator configuration"
  type = object({
    create_namespace   = optional(bool, true)
    helm_chart         = optional(string, "oci://ghcr.io/grafana-operator/helm-charts/grafana-operator")
    helm_name          = optional(string, "grafana-operator")
    k8s_namespace      = optional(string, "grafana-operator")
    helm_release_name  = optional(string, "grafana-operator")
    helm_chart_version = optional(string, "v5.5.2")
  })

  default  = {}
  nullable = false
}

variable "enable_external_secrets" {
  description = "Installs External Secrets to EKS Cluster"
  type        = bool
  default     = true
}

variable "grafana_api_key" {
  description = "Grafana API key for the Amazon Managed Grafana workspace. Required if `enable_external_secrets = true`"
  type        = string
  default     = ""
}

variable "grafana_url" {
  description = "Endpoint URL of Amazon Managed Grafana workspace. Required if `enable_grafana_operator = true`"
  type        = string
  default     = ""
}

variable "grafana_cluster_dashboard_url" {
  description = "Dashboard URL for Cluster Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/cluster.json"
}

variable "grafana_kubelet_dashboard_url" {
  description = "Dashboard URL for Kubelet Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/kubelet.json"
}

variable "grafana_namespace_workloads_dashboard_url" {
  description = "Dashboard URL for Namespace Workloads Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/namespace-workloads.json"
}

variable "grafana_node_exporter_dashboard_url" {
  description = "Dashboard URL for Node Exporter Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/nodeexporter-nodes.json"
}

variable "grafana_nodes_dashboard_url" {
  description = "Dashboard URL for Nodes Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/nodes.json"
}

variable "grafana_workloads_dashboard_url" {
  description = "Dashboard URL for Workloads Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/workloads.json"
}

variable "grafana_fleet_dashboard_url" {
  description = "Dashboard URL for Fleet Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/fleet-monitoring.json"
}

variable "grafana_logs_dashboard_url" {
  description = "Dashboard URL for Logs Grafana Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/infrastructure/logs.json"
}

variable "grafana_apiserver_basic_dashboard_url" {
  description = "Dashboard URL for API Server Basic Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/apiserver/apiserver-basic.json"
}

variable "grafana_apiserver_advanced_dashboard_url" {
  description = "Dashboard URL for API Server Advanced Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/apiserver/apiserver-advanced.json"
}

variable "grafana_apiserver_troubleshooting_dashboard_url" {
  description = "Dashboard URL for API Server Troubleshooting Dashboard JSON"
  type        = string
  default     = "https://%s.s3.amazonaws.com/EKS/OSS/CDK/v3.0.0/grafana-dashboards/apiserver/apiserver-troubleshooting.json"
}

variable "target_secret_name" {
  description = "Target secret in Kubernetes to store the Grafana API Key Secret"
  type        = string
  default     = "grafana-admin-credentials"
}

variable "target_secret_namespace" {
  description = "Target namespace of secret in Kubernetes to store the Grafana API Key Secret"
  type        = string
  default     = "grafana-operator"
}
