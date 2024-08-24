# Create AWS IAM user

[Build infrastructure](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-build)

```
docker run -it --rm -v ${PWD}:/root --entrypoint /bin/bash tsutomu/terraform-runner
cd /root
```

```
aws configure --profile developer
> AWS Access Key ID [None]: ${AWS_ACCESS_KEY_ID}
> AWS Secret Access Key [None]: ${AWS_SECRET_ACCESS_KEY}
> Default region name [None]: ap-northeast-1
> Default output format [None]: json
```

```
mkdir learn-terraform-aws-instance
cd learn-terraform-aws-instance
```

Search an image id of Ubuntu 24.04 LTS.

```
aws ec2 describe-images --profile developer --owners amazon --region ap-northeast-1
>        {
>            "Architecture": "x86_64",
>            "CreationDate": "2024-07-04T22:57:03.000Z",
>            "ImageId": "ami-02e4eeb4aab5f1a4d",
>            "ImageLocation": "amazon/ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-minimal-20240704",
>            ......
>            "Description": "Canonical, Ubuntu Minimal, 24.04 LTS, amd64 noble image build on 2024-07-04",
>            ......
>            "Name": "ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-minimal-20240704",
>            "RootDeviceName": "/dev/sda1",
>            "RootDeviceType": "ebs",
>            "SriovNetSupport": "simple",
>            "VirtualizationType": "hvm",
>            "BootMode": "uefi-preferred",
>            "DeprecationTime": "2026-07-04T22:57:03.000Z",
>            "ImdsSupport": "v2.0"
>        },
```

```
cat << 'EOF' > main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-northeast-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-02e4eeb4aab5f1a4d"
  instance_type = "t2.micro"

  tags = {
    Name = "ExampleAppServerInstance"
  }
}
EOF
```

`ami-0cab37bd176bb80d3` is the AMI-ID of the Ubuntu 24.04 LTS.
You can find any images of Ubuntu at the [Amazon EC2 AMI Locator](https://cloud-images.ubuntu.com/locator/ec2/).

```
terraform init

> Initializing the backend...
> Initializing provider plugins...
> - Finding hashicorp/aws versions matching "~> 4.16"...
> - Installing hashicorp/aws v4.67.0...
> - Installed hashicorp/aws v4.67.0 (signed by HashiCorp)
> Terraform has created a lock file .terraform.lock.hcl to record the provider
> selections it made above. Include this file in your version control repository
> so that Terraform can guarantee to make the same selections by default when
> you run "terraform init" in the future.
> 
> Terraform has been successfully initialized!
> 
> You may now begin working with Terraform. Try running "terraform plan" to see
> any changes that are required for your infrastructure. All Terraform commands
> should now work.
> 
> If you ever set or change modules or backend configuration for Terraform,
> rerun this command to reinitialize your working directory. If you forget, other
> commands will detect it and remind you to do so if necessary.
```

* Format and validate the configuration
```
terraform fmt
> main.tf

terraform validate
> Success! The configuration is valid.
```

```
export AWS_PROFILE=developer
terraform apply
```


```
aws ec2 describe-security-groups --profile developer | jq -r '.["SecurityGroups"][] | [.["GroupName"],.["Description"]] | @csv'
> "default","default VPC security group"
aws ec2 describe-vpcs --profile developer | jq -r '.["Vpcs"][] | [.["CidrBlock"], .["VpcId"]] | @csv'
> "172.31.0.0/16","vpc-aaaaaaaaaaaaaaaaa"
aws ec2 describe-subnets --profile developer | jq -r '.["Subnets"][] | [.["CidrBlock"],.["VpcId"],.["SubnetId"]] | @csv'
> "172.31.32.0/20","vpc-aaaaaaaaaaaaaaaaa","subnet-aaaaaaaaaaaaaaaaa"
> "172.31.0.0/20","vpc-bbbbbbbbbbbbbbbbb","subnet-bbbbbbbbbbbbbbbbb"
> "172.31.16.0/20","vpc-ccccccccccccccccc","subnet-ccccccccccccccccc"
```

```
$ aws ec2 run-instance ...
```


# Reference
; Get Started - AWS
: https://developer.hashicorp.com/terraform/tutorials/aws-get-started


https://qiita.com/Mayumi_Pythonista/items/324c16ca98435df7d78d

