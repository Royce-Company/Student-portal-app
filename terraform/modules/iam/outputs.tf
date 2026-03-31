output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "eks_worker_role_arn" {
  value = aws_iam_role.eks_worker_role.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller_role.arn
}

output "ebs_csi_driver_role_arn" {
  value = aws_iam_role.ebs_csi_driver_role.arn
}

output "cloudwatch_logs_role_arn" {
  value = aws_iam_role.cloudwatch_logs_role.arn
}

output "app_secrets_role_arn" {
  value = aws_iam_role.app_secrets_role.arn
}
