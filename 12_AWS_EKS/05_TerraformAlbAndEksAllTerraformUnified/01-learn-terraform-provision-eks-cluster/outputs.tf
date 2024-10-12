# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = module.vpc.public_subnets
}

output "vpc_id" {
  description = "Public Subnet IDs"
  value       = module.vpc.vpc_id
}

# Output caller identity
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
output "account_id" {
  description = "AWS Account ID"
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  description = "AWS Caller ARN"
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  description = "AWS Caller User"
  value = data.aws_caller_identity.current.user_id
}

output "oidc_provider_url" {
  description = "OIDC Provider URL"
  value = module.eks.oidc_provider
}

