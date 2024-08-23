variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster-with-vpc"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "amp_ws_arn" {
  description = "Amazon Managed Service for Prometheus Workspace ARN"
  type        = string
  default     = ""
}

variable "amg_endpoint" {
  description = "Amazon Managed Grafana Workspace Endpoint"
  type        = string
}

variable "grafana_api_key" {
  description = "API key for authorizing the Grafana provider to make changes to Amazon Managed Grafana"
  type        = string
  sensitive   = true
}

variable "enable_dashboards" {
  description = "Enables or disables curated dashboards. Dashboards are managed by the Grafana Operator"
  type        = bool
  default     = true
}

variable "access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "access_key" {
  
}
