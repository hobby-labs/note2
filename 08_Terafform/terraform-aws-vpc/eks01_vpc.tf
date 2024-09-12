resource "aws_vpc" "eks01" {
  cidr_block = "172.30.0.0/16"
  tags = {
    Name = "eks01_vpc"
  }
}
