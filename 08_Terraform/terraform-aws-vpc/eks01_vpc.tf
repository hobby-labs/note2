# https://spacelift.io/blog/terraform-aws-vpc

resource "aws_vpc" "eks01" {
  cidr_block = "172.30.0.0/16"
  tags = {
    Name = "eks01_vpc"
  }
}

resource "aws_subnet" "subnet01_eks01" {
  vpc_id     = aws_vpc.eks01.id
  cidr_block = "172.30.0.0/24"

  tags = {
    Name = "seg_172_30_0_0_24_eks01_vpc"
  }
}

# Public subnets is 172.30.0.0 - 172.30.127.255
variable "public_subnet_cidrs_of_eks01_vpc" {
 type        = list(string)
 description = "Public Subnet CIDR values of eks01_vpc"
 default     = ["172.30.0.0/24", "172.30.1.0/24"]
}

# Private subnet is 172.30.128.0 - 172.30.255.255
variable "private_subnet_cidrs_of_eks01_vpc" {
 type        = list(string)
 description = "Private Subnet CIDR values for eks01_vpc"
 default     = ["172.30.128.0/24", "172.30.129.0/24"]
}

resource "aws_subnet" "public_subnets_of_eks01_vpc" {
  count         = length(var.public_subnet_cidrs_of_eks01_vpc)
  vpc_id        = aws_vpc.eks01.id
  cidr_block    = var.public_subnet_cidrs_of_eks01_vpc[count.index]

  tags = {
    Name = "public_subnet_${count.index + 1}_eks01_vpc"
  }
}

resource "aws_internet_gateway" "igw_eks01" {
  vpc_id = aws_vpc.eks01.id

  tags = {
    Name = "igw_eks01"
  }
}

