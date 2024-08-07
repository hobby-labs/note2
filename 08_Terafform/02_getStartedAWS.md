# Create AWS IAM user

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
  ami           = "ami-0cab37bd176bb80d3"
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

```



```
$ aws ec2 describe-security-groups --profile developer | jq -r '.["SecurityGroups"][] | [.["GroupName"],.["Description"]] | @csv'
```


```
$ aws ec2 describe-vpcs --profile developer | jq -r '.["Vpcs"][] | [.["CidrBlock"],.["VpcId"],.["Tags"][]["Value"]] | @csv'
```

```
$ aws ec2 describe-subnets --profile developer | jq -r '.["Subnets"][] | [.["CidrBlock"],.["VpcId"],.["SubnetId"]] | @csv'
```

```
$ aws ec2 run-instance ...
```


# Reference
; Get Started - AWS
: https://developer.hashicorp.com/terraform/tutorials/aws-get-started


https://qiita.com/Mayumi_Pythonista/items/324c16ca98435df7d78d

