terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.48.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16.1"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../01-learn-terraform-provision-eks-cluster/terraform.tfstate"
  }
}

# Retrieve EKS cluster information
provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

data "aws_eks_cluster" "cluster" {
  name              = data.terraform_remote_state.eks.outputs.cluster_name
  account_id        = data.terraform_remote_state.eks.outputs.account_id
  oidc_provider_url = data.terraform_remote_state.eks.outputs.oidc_provider_url
}

#data "aws_subnet" "public_subnet_ids" {
#  id = data.terraform_remote_state.eks.outputs.public_subnet_ids
#}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "aws_security_group" "permit_http_https_all" {
  name = "permit_http_https_all"
  vpc_id = data.terraform_remote_state.eks.outputs.vpc_id

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
  subnets            = data.terraform_remote_state.eks.outputs.public_subnet_ids

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

  vpc_id = data.terraform_remote_state.eks.outputs.vpc_id

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

# IAM roles
#{
#    "Version": "2012-10-17",
#    "Statement": [
#        {
#            "Effect": "Allow",
#            "Principal": {
#                "Federated": "arn:aws:iam::${ACCOUNT}:oidc-provider/${OIDC_ISSUER}"
#            },
#            "Action": "sts:AssumeRoleWithWebIdentity",
#            "Condition": {
#                "StringEquals": {
#                    "${OIDC_ISSUER}:aud": "sts.amazonaws.com",
#                    "${OIDC_ISSUER}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
#                }
#            }
#        }
#    ]
#}
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
          Federated = "arn:aws:iam::${data.aws_eks_cluster.cluster.account_id}:oidc-provider/${OIDC_ISSUER}"
        },

        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${data.aws_eks_cluster.cluster.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${data.aws_eks_cluster.cluster.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

