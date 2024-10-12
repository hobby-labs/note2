# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

locals {
  cluster_name = "eks-01"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "eks01-vpc"

  cidr = "172.30.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["172.30.0.0/24", "172.30.1.0/24"]
  public_subnets  = ["172.30.2.0/24", "172.30.3.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }

    two = {
      name = "node-group-2"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}


# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  #cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

resource "aws_security_group" "permit_http_https_all" {
  name = "permit_http_https_all"
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "permit_http_https_all"
  }
}

resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.permit_http_https_all.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.permit_http_https_all.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.permit_http_https_all.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb" "global_alb" {
  name               = "global-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.permit_http_https_all.id]
  #subnets            = data.terraform_remote_state.eks.outputs.public_subnet_ids
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "global-alb"
  }
}

output "global_alb" {
  description = "Global Application Load Balancer"
  value       = aws_lb.global_alb.dns_name
}

resource "aws_lb_target_group" "global_alb_target_group" {
  #name             = "global-alb-target-group"
  name             = "nginx"
  # Supported target_type values are (instance | ip | lambda | alb).
  target_type      = "ip"
  protocol_version = "HTTP1"
  #port             = 80
  port             = 30007
  protocol         = "HTTP"

  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "nginx"
  }

  health_check {
    interval            = 30
    path                = "/"
    port                = "30007"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200,301"
  }
}

resource "aws_iam_role" "AmazonEKSLoadBalancerControllerRole" {
  name = "AmazonEKSLoadBalancerControllerRole"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
        },

        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

data "http" "aws_load_balancer_controller_iam_policy_json" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "aws_load_balancer_controller_iam_policy" {
  name        = "AWSEKSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for the AWS Load Balancer Controller on EKS"
  policy      = data.http.aws_load_balancer_controller_iam_policy_json.body
}



