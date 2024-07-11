resource "kubectl_manifest" "flux_gitrepository" {
  count = var.enable_dashboards ? 1 : 0

  yaml_body = <<YAML
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: ${var.flux_gitrepository_name}
  namespace: flux-system
spec:
  interval: 5m0s
  url: ${var.flux_gitrepository_url}
  ref:
    branch: main
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
    kind: GitRepository
    name: ${var.flux_gitrepository_name}
  postBuild:
    substitute:
      AMG_AWS_REGION: ${local.managed_prometheus_workspace_region}
      AMP_ENDPOINT_URL: ${local.managed_prometheus_workspace_endpoint}
      AMG_ENDPOINT_URL: ${var.grafana_url}
      GRAFANA_CLUSTER_DASH_URL: ${var.grafana_cluster_dashboard_url}
      GRAFANA_KUBELET_DASH_URL: ${var.grafana_kubelet_dashboard_url}
      GRAFANA_NSWRKLDS_DASH_URL: ${var.grafana_namespace_workloads_dashboard_url}
      GRAFANA_NODEEXP_DASH_URL: ${var.grafana_node_exporter_dashboard_url}
      GRAFANA_NODES_DASH_URL: ${var.grafana_nodes_dashboard_url}
      GRAFANA_WORKLOADS_DASH_URL: ${var.grafana_workloads_dashboard_url}
      GRAFANA_FLEET_DASH_URL: ${var.grafana_fleet_dashboard_url}
      GRAFANA_LOGS_DASH_URL: ${var.grafana_logs_dashboard_url}
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
    kind: GitRepository
    name: ${local.apiserver_monitoring_config.flux_gitrepository_name}
  postBuild:
    substitute:
      GRAFANA_APISERVER_BASIC_DASH_URL: ${local.apiserver_monitoring_config.dashboards.basic}
      GRAFANA_APISERVER_ADVANCED_DASH_URL: ${local.apiserver_monitoring_config.dashboards.advanced}
      GRAFANA_APISERVER_TROUBLESHOOTING_DASH_URL: ${local.apiserver_monitoring_config.dashboards.troubleshooting}
YAML
  count      = var.enable_apiserver_monitoring ? 1 : 0
  depends_on = [module.external_secrets]
}