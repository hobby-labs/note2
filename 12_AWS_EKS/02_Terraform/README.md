# By using Terraform

* [Provision an EKS cluster (AWS)](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks)
* [eks module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

```bash
host$ docker run -it --rm --hostname tf --name tf -v ${PWD}:/root/work --entrypoint /bin/bash tsutomu/terraform-runner

tf$ cd /root/work
```

```
tf$ rm -rf learn-terraform-provision-eks-cluster
tf$ git clone https://github.com/hashicorp/learn-terraform-provision-eks-cluster.git
tf$ cd learn-terraform-provision-eks-cluster
tf$ git checkout -b c5c4d54 c5c4d54
```

Modify `main.tf` and `variables.tf`.

```
tf$ git diff main.tf variables.tf
```

Modified lines are as follows.

```
diff --git a/main.tf b/main.tf
index a27478e..67d5366 100644
--- a/main.tf
+++ b/main.tf
@@ -15,7 +15,7 @@ data "aws_availability_zones" "available" {
 }

 locals {
-  cluster_name = "education-eks-${random_string.suffix.result}"
+  cluster_name = "eks-01"
 }

 resource "random_string" "suffix" {
@@ -27,13 +27,13 @@ module "vpc" {
   source  = "terraform-aws-modules/vpc/aws"
   version = "5.8.1"

-  name = "education-vpc"
+  name = "eks01-vpc"

-  cidr = "10.0.0.0/16"
+  cidr = "172.30.0.0/16"
   azs  = slice(data.aws_availability_zones.available.names, 0, 3)

-  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
-  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
+  private_subnets = ["172.30.0.0/24", "172.30.1.0/24"]
+  public_subnets  = ["172.30.2.0/24", "172.30.3.0/24"]

   enable_nat_gateway   = true
   single_nat_gateway   = true
@@ -79,8 +79,8 @@ module "eks" {
       instance_types = ["t3.small"]

       min_size     = 1
-      max_size     = 3
-      desired_size = 2
+      max_size     = 2
+      desired_size = 1
     }

     two = {
diff --git a/variables.tf b/variables.tf
index 184bbb0..c99f250 100644
--- a/variables.tf
+++ b/variables.tf
@@ -4,5 +4,5 @@
 variable "region" {
   description = "AWS region"
   type        = string
-  default     = "us-east-2"
+  default     = "ap-northeast-1"
 }
```

Configure AWS credentials.
Please replace `${AWS_ACCESS_KEY_ID}` and `${AWS_SECRET_ACCESS_KEY}` with your own values.

```
tf$ aws configure --profile developer
> AWS Access Key ID [None]: ${AWS_ACCESS_KEY_ID}
> AWS Secret Access Key [None]: ${AWS_SECRET_ACCESS_KEY}
> Default region name [None]: ap-northeast-1
> Default output format [None]: json

tf$ export AWS_PROFILE=developer
```


```
tf$ terraform init
tf$ terraform plan
tf$ terraform apply
```

# Configure kubectl
Get kube-config by using parameters in outputs.tf.

* outputs.tf
```
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
```

```
tf$ aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

# Manage Kubernetes resources

* [Manage Kubernetes resources via Terraform](https://developer.hashicorp.com/terraform/tutorials/kubernetes/kubernetes-provider?variants=kubernetes%3Aeks)

```
tf$ cd /root/work
tf$ mkdir learn-terraform-deploy-nginx-kubernetes
```

Create `kubernetes.tf`.

* kubernetes.tf
```
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
    path = "../learn-terraform-provision-eks-cluster/terraform.tfstate"
  }
}

# Retrieve EKS cluster information
provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

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

resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "scalable-nginx-example"
    labels = {
      App = "ScalableNginxExample"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "ScalableNginxExample"
      }
    }
    template {
      metadata {
        labels = {
          App = "ScalableNginxExample"
        }
      }
      spec {
        container {
          image = "nginx:1.7.8"
          name  = "example"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}
```

Data `terraform_remote_state` will refer to the state file of the EKS cluster that was created in the previous step.

```
tf$ terraform init
tf$ terraform plan
tf$ terraform apply

tf$ kubectl get namespaces
> NAME              STATUS   AGE
> default           Active   71m
> kube-node-lease   Active   71m
> kube-public       Active   71m
> kube-system       Active   71m

tf$ kubectl get pod -n default
> NAME                                      READY   STATUS    RESTARTS   AGE
> scalable-nginx-example-6fb96bf75d-bsg9h   1/1     Running   0          34s
> scalable-nginx-example-6fb96bf75d-j5ksw   1/1     Running   0          34s
```

