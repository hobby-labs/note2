# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-01"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "eks01-vpc"
}

variable "vpc_ip_cidr" {
  description = "IP CIDR for the VPC"
  type        = string
  default     = "172.30.0.0/16"
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(string)
  default     = ["172.30.0.0/24", "172.30.1.0/24"]
}

variable "public_subnets" {
  description = "List of public subnets"
  type        = list(string)
  default     = ["172.30.2.0/24", "172.30.3.0/24"]
}

