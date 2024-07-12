variable "irsa_policies" {
  description = "Additional IAM policies for a IAM role for service accounts"
  type        = list(string)
  default     = []
}

variable "addon_context" {
  description = "Input configuration for the addon"
  type = object({
    aws_caller_identity_account_id = string
    aws_caller_identity_arn        = string
    aws_eks_cluster_endpoint       = string
    aws_partition_id               = string
    aws_region_name                = string
    eks_cluster_id                 = string
    eks_oidc_issuer_url            = string
    eks_oidc_provider_arn          = string
    irsa_iam_role_path             = string
    irsa_iam_permissions_boundary  = string
    tags                           = map(string)
  })
}

variable "cloudwatch_observability_config" {
  description = "Configuration for the Amazon CloudWatch Observability addon"
  type        = any
  default     = {
    "agent" : {
      "config" : {
        "logs" : {
          "metrics_collected" : {
            "application_signals" : {},
            "kubernetes" : {}
          }
        },
        "traces" : {
          "traces_collected" : {
            "application_signals": {}
          }
        }
      }
    }
  }
}
