resource "aws_subnet" "subnet01_eks01" {
  vpc_id     = aws_vpc.eks01.id
  cidr_block = "172.30.0.0/24"

  tags = {
    Name = "seg_172_30_0_0_24_eks01_vpc"
  }
}
