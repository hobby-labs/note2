# Creating subnets
* [Example: VPC with servers in private subnets and NAT](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html)  

Creating VPC for EKS.  

* Open `https://console.aws.amazon.com/vpc/`.
* Click `Create VPC`
* Click `VPC and more` in `Resources to create`
* Configure the VPC
** Enter name of your VPC `vpc-eks` in `Name tag auto-generation`
** Enter `172.30.0.0/16` as `IPv4 CIDR block`.
** Choose `2` for `Number of Availability Zones`
** Choose `2` for `Number of public subnets`
** Choose `2` for `Number of private subnets`
** Choose `1 per AZ` for `NAT gateways`
** Choose `S3 Gateway` for `VPC endpoints`
** Unchoose `Enable DNS hostnames` for `DNS options`

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

# Create nodes
We will create nodes with Fargate's profile.

* pod-execution-role-trust-policy.json
```
eks-operator$ ACCOUNT_ID="$(jq -r '.Account' < <(aws sts get-caller-identity))"
eks-operator$ CLUSTER_NAME="my-cluster-0001"
eks-operator$ echo "ACCOUNT_ID=$ACCOUNT_ID, CLUSTER_NAME=${CLUSTER_NAME}"

eks-operator$ cat << EOF > pod-execution-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Condition": {
         "ArnLike": {
            "aws:SourceArn": "arn:aws:eks:region-code:${ACCOUNT_ID}:fargateprofile/${CLUSTER_NAME}/*"
         }
      },
      "Principal": {
        "Service": "eks-fargate-pods.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create a Pod execution IAM role

```
eks-operator$ aws iam create-role \
                  --role-name AmazonEKSFargatePodExecutionRole \
                  --assume-role-policy-document file://"pod-execution-role-trust-policy.json"
```

Attach the required Amazon EKS managed IAM policy to the role.

```
eks-operator$ aws iam attach-role-policy \
                  --policy-arn arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy \
                  --role-name AmazonEKSFargatePodExecutionRole
```

* Open `https://console.aws.amazon.com/eks/home#/clusters`
* Click `my-cluster0001`
* On the `my-cluster0001` page, click `Compute` tab, Click `Add Fargate Profile` under `Fargate Profiles`
* On the `Configure Fargate Profile` page, fill `Name` with `my-cluster0001`, choose `AmazonEKSFargatePodExecutionRole` in `Pod execution role`, deselect any `Public` subnets(only supports private), click `Next`




# 

