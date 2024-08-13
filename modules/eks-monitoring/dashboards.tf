resource "kubectl_manifest" "flux_bucket" {
  count = var.enable_dashboards ? 1 : 0

  yaml_body = <<YAML
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: Bucket
metadata:
  name: ${var.flux_bucket_name}
  namespace: flux-system
spec:
  interval: 5m0s
  provider: aws
  bucketName: ${var.flux_bucket_name}
  region: ${var.flux_bucket_region}
  prefix: ${var.flux_bucket_path}
  endpoint: s3.amazonaws.com
YAML

  depends_on = [module.external_secrets]
}

resource "kubectl_manifest" "flux_kustomization" {
  yaml_body  = <<YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: ${var.flux_kustomization_name}
  namespace: flux-system
spec:
  interval: 1m0s
  path: ${var.flux_kustomization_path}
  prune: true
  sourceRef:
    kind: Bucket
    name: ${var.flux_bucket_name}
  postBuild:
    substitute:
      AMG_AWS_REGION: ${local.managed_prometheus_workspace_region}
      AMP_ENDPOINT_URL: ${local.managed_prometheus_workspace_endpoint}
      AMG_ENDPOINT_URL: ${var.grafana_url}
      GRAFANA_CLUSTER_DASH_URL: ${format(var.grafana_cluster_dashboard_url, var.flux_bucket_name)}
      GRAFANA_KUBELET_DASH_URL: ${format(var.grafana_kubelet_dashboard_url, var.flux_bucket_name)}
      GRAFANA_NSWRKLDS_DASH_URL: ${format(var.grafana_namespace_workloads_dashboard_url, var.flux_bucket_name)}
      GRAFANA_NODEEXP_DASH_URL: ${format(var.grafana_node_exporter_dashboard_url, var.flux_bucket_name)}
      GRAFANA_NODES_DASH_URL: ${format(var.grafana_nodes_dashboard_url, var.flux_bucket_name)}
      GRAFANA_WORKLOADS_DASH_URL: ${format(var.grafana_workloads_dashboard_url, var.flux_bucket_name)}
      GRAFANA_FLEET_DASH_URL: ${format(var.grafana_fleet_dashboard_url, var.flux_bucket_name)}
      GRAFANA_LOGS_DASH_URL: ${format(var.grafana_logs_dashboard_url, var.flux_bucket_name)}
YAML
  count      = var.enable_dashboards ? 1 : 0
  depends_on = [module.external_secrets]
}

# api server dashboards
resource "kubectl_manifest" "api_server_dashboards" {
  yaml_body  = <<YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: ${local.apiserver_monitoring_config.flux_kustomization_name}
  namespace: flux-system
spec:
  interval: 1m0s
  path: ${local.apiserver_monitoring_config.flux_kustomization_path}
  prune: true
  sourceRef:
    kind: Bucket
    name: ${var.flux_bucket_name}
  postBuild:
    substitute:
      GRAFANA_APISERVER_BASIC_DASH_URL: ${format(var.grafana_apiserver_basic_dashboard_url, var.flux_bucket_name)}
      GRAFANA_APISERVER_ADVANCED_DASH_URL: ${format(var.grafana_apiserver_advanced_dashboard_url, var.flux_bucket_name)}
      GRAFANA_APISERVER_TROUBLESHOOTING_DASH_URL: ${format(var.grafana_apiserver_troubleshooting_dashboard_url, var.flux_bucket_name)}
YAML
  count      = var.enable_apiserver_monitoring ? 1 : 0
  depends_on = [module.external_secrets]
}
