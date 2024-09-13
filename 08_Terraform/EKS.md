## EKS
```
mkdir -p teraform-aws-eks
cd teraform-aws-eks

docker run -it --rm -v ${PWD}:/root --entrypoint /bin/bash tsutomu/terraform-runner
cd /root

aws configure --profile developer
> AWS Access Key ID [None]: ${AWS_ACCESS_KEY_ID}
> AWS Secret Access Key [None]: ${AWS_SECRET_ACCESS_KEY}
> Default region name [None]: ap-northeast-1
> Default output format [None]: json
```

## Create VPC

* eks01_vpc.tf
```
cat << 'EOF' > eks01_vpc.tf
resource "aws_vpc" "eks01" {
  cidr_block = "172.30.0.0/16"
  tags = {
    Name = "eks01_vpc"
  }
}
EOF
```

* subnet_172_30_0_0_24_eks01_vpc.tf
```
cat << 'EOF' > subnet_172_30_0_0_24_eks01_vpc.tf
resource "aws_subnet" "subnet01_eks01" {
  vpc_id     = aws_vpc.eks01.id
  cidr_block = "172.30.0.0/24"

  tags = {
    Name = "seg_172_30_0_0_24_eks01_vpc"
  }
}
EOF
```

```
terraform init
terraform fmt
terraform validate
export AWS_PROFILE=developer
terraform apply
```

## Create EKS

```
cat << 'EOF' > main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-cluster"
  cluster_version = "1.30"

  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  #vpc_id                   = "vpc-1234556abcdef"
  vpc_id                   = aws_vpc.eks01.id
  #subnet_ids               = ["subnet-abcde012", "subnet-bcde012a", "subnet-fghi345a"]
  subnet_ids               = [aws_subnet.subnet01_eks01.id]
  #control_plane_subnet_ids = ["subnet-xyzde987", "subnet-slkjf456", "subnet-qeiru789"]

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
  }

  eks_managed_node_groups = {
    example = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]

      min_size     = 2
      max_size     = 10
      desired_size = 2
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    # One access entry with a policy associated
    example = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::123456789012:role/something"

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
EOF
```

```
terraform init
terraform fmt
terraform validate
export AWS_PROFILE=developer
terraform apply
```


# Reference
* [terraform-aws-modules/terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks)
* [Resource: aws_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)


