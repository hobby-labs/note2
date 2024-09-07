# 

* [Get started with Amazon EKS – AWS Management Console and AWS CLI](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html)

```
host$ docker run --rm --hostname eks-operator --name eks-operator -v ${PWD}:/root/work -ti tsutomu/terraform-runner bash

eks-operator$ aws configure --profile developer
> AWS Access Key ID [None]: ${AWS_ACCESS_KEY_ID}
> AWS Secret Access Key [None]: ${AWS_SECRET_ACCESS_KEY}
> Default region name [None]: ap-northeast-1
> Default output format [None]: json

eks-operator$ export AWS_PROFILE=developer
```

```
eks-operator$ aws sts get-caller-identity
> {
>     "UserId": "*******************",
>     "Account": "000000000000",
>     "Arn": "arn:aws:iam::000000000000:user/developer"
> }
```

// This instruction asuumes that you have already created a VPC and a subnets.  
// And the subnets are located in different availability zones.  
  
Create a cluster IAM role then attach the `AmazonEKSClusterPolicy` to it.  

* eks-cluster-role-trust-policy.json
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Create a cluster IAM role.

```
eks-operator$ aws iam create-role \
                  --role-name myAmazonEKSClusterRole \
                  --assume-role-policy-document file://"eks-cluster-role-trust-policy.json"
> {
>     "Role": {
>         "Path": "/",
>         "RoleName": "myAmazonEKSClusterRole",
>         "RoleId": "XXXXXXXXXXXXXXXXXXXXX",
>         "RoleId": "",
>         "Arn": "arn:aws:iam::000000000000:role/myAmazonEKSClusterRole",
>         "CreateDate": "2024-09-07T05:32:41+00:00",
>         "AssumeRolePolicyDocument": {
>             "Version": "2012-10-17",
>             "Statement": [
>                 {
>                     "Effect": "Allow",
>                     "Principal": {
>                         "Service": "eks.amazonaws.com"
>                     },
>                     "Action": "sts:AssumeRole"
>                 }
>             ]
>         }
>     }
> }
```

Attach the role to `AmazonEKSClusterPolicy`.

```
eks-operator$ aws iam attach-role-policy \
                  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
                  --role-name myAmazonEKSClusterRole
```

Open your web browser and navigate to the Amazon EKS console at the following URL.
* https://console.aws.amazon.com/eks/home#/clusters

* `Add Cluster` -> `Create cluster`
* Cluster Name `my-cluster-0001`. The name must be unique within your AWS account.
* Choose `myAmazonEKSClusterRole` for `Cluster Service Role`
* `Next`
* In the next page, choose the VPC and subnets that located in different availability zones
* Click `Next`.
* Click `Next` on the `Configure Observability` page.
* Click `Next` on the `Select add-ons` page
* Click `Next` on the `Configure selected add-ons settings` page
* Click `Create` on the `Review and create` page

You can proceed next steps after the cluster's status become `active`.


