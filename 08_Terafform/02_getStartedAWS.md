# Create AWS IAM user


```
aws configure --profile developer
...
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

