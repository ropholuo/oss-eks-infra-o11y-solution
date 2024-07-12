resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "${var.addon_context.eks_cluster_id}-cloudwatch-agent-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.addon_context.eks_oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
        "${var.addon_context.eks_oidc_issuer_url}:aud": "sts.amazonaws.com",
          "${var.addon_context.eks_oidc_issuer_url}:sub": "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_agent_role.name
}

resource "aws_eks_addon" "cloudwatch_observability" {
  addon_name   = "amazon-cloudwatch-observability"
  cluster_name = var.addon_context.eks_cluster_id
  service_account_role_arn = aws_iam_role.cloudwatch_agent_role.arn
  configuration_values = jsonencode(var.cloudwatch_observability_config)
}

