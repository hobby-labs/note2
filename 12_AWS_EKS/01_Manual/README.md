# Creating VPC

* [Example: VPC with servers in private subnets and NAT](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html)  
  

* Open ` https://console.aws.amazon.com/vpc/`
* Click `Create VPC`
** On the `Create VPC` page, click `VPC and more` in `Resources to create` section
** Enter `eks-vpc-0001` as `Name tag auto-generation`
** Enter `172.30.0.0/16` as `IPv4 CIDR block`.
** Choose `2` for `Number of Availability Zones`
** Choose `2` for `Number of public subnets`
** Choose `2` for `Number of private subnets`
** Choose `1 per AZ` for `NAT gateways`
** Choose `S3 Gateway` for `VPC endpoints`
** Unchoose `Enable DNS hostnames` for `DNS options`
* Click `Create VPC`

After a few minutes, the VPC and subnets will be created.  

* VPC

| VPC              | CIDR          |
|------------------|---------------|
| eks-vpc-0001-vpc | 172.30.0.0/16 |

* Subnets

| Subnet<br />[(VPC)-subnet-(pub/prv)-(AZ)]    | CIDR            | IP range                      |
|----------------------------------------------|-----------------|-------------------------------|
| eks-vpc-0001-subnet-public1-ap-northeast-1a  | 172.30.0.0/20   | 172.30.0.0   - 172.30.15.255  |
| eks-vpc-0001-subnet-public2-ap-northeast-1c  | 172.30.16.0/20  | 172.30.16.0  - 172.30.31.255  |
| eks-vpc-0001-subnet-private1-ap-northeast-1a | 172.30.128.0/20 | 172.30.128.0 - 172.30.143.255 |
| eks-vpc-0001-subnet-private2-ap-northeast-1c | 172.30.144.0/20 | 172.30.144.0 - 172.30.159.255 |

* Nat Gateways

| Nat Gateway<br />[(VPC)-nat-(pub)-(AZ)]  | Private IP    | Public IP |
|------------------------------------------|---------------|-----------|
| eks-vpc-0001-nat-public1-ap-northeast-1a | 172.30.5.3    | a.a.a.a   |
| eks-vpc-0001-nat-public1-ap-northeast-1a | 172.30.24.201 | b.b.b.b   |

* Internet Gateways

| Internet Gateway<br /> [(VPC)-igw] |
|------------------------------------|
| eks-vpc-0001-igw                   |

# Create an EKS cluster

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
* In the next page, choose the VPC that previously created(`eks-vpc-0001-vpc`) as `VPC`
* Choose subnets `eks-vpc-0001-subnet-(public1|public2|private1|private2)-ap-northeast-1[ac]` (4 subnets).
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
eks-operator$ REGION_CODE="ap-northeast-1"
eks-operator$ ACCOUNT_ID="$(jq -r '.Account' < <(aws sts get-caller-identity))"
eks-operator$ CLUSTER_NAME="my-cluster-0001"
eks-operator$ echo "REGION_CODE=${REGION_CODE}, ACCOUNT_ID=${ACCOUNT_ID}, CLUSTER_NAME=${CLUSTER_NAME}"
> REGION_CODE=ap-northeast-1, ACCOUNT_ID=xxxxxxxxxxxx, CLUSTER_NAME=my-cluster-0001

eks-operator$ cat << EOF > pod-execution-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Condition": {
         "ArnLike": {
            "aws:SourceArn": "arn:aws:eks:${REGION_CODE}:${ACCOUNT_ID}:fargateprofile/${CLUSTER_NAME}/*"
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
* Click `my-cluster-0001`
* On the `my-cluster-0001` page, click `Compute` tab, Click `Add Fargate Profile` under `Fargate Profiles`
* On the `Configure Fargate Profile` page
** Type `my-fargate-0001` in `Name`
** Select `AmazonEKSFargatePodExecutionRole` in `Pod execution role`,
** Select private subnets `eks-vpc-0001-subnet-(private1|private2)-ap-northeast-1[ac]` in `Subnets`
** Ckick `Next`
* On the `Configure pod selection` page
** Type `default` in `Namespace`
** Click `Next`
* Click `Create` on the `Review and create` page

After a few minutes, status of `Fargate profile` will be `Active`.
After that, you can proceed next steps.

## Deploy Fargate

* Choose `my-fargate-0001` in the `Fargate Profile` in `Compute` tag
* Click `Add Fargate Profile`
* On the `Configure Fargate Profile` page
** Type `CoreDNS` in `Name`
** Select `AmazonEKSFargatePodExecutionRole` 
** Select private subnets `eks-vpc-0001-subnet-(private1|private2)-ap-northeast-1[ac]` in `Subnets`
** Click `Next`
* On the `Configure pod selection` page
** `kube-system` in `Namespace`
** Click `Add label` in `Match labels`
** Type `k8s-app` as key, `kube-dns` as value
** Click `Next`
* Click `Create` in the Review and create page

You have to remove an op from CoreDNS but you might not be able to currently.
We will remove it after an instruction "Add permissions to the IAM role for the Cluster" in the next section.

## Add permissions to the IAM role for the Cluster
Add permissions to the IAM user `developer` to be able to use kubectl.

* Open `https://console.aws.amazon.com/eks/home#/clusters`
* Click `my-cluster-0001`
* Click `Access` tab
* Click `Create access entry` in `IAM access entries`
* In `Configure IAM access entry` page
** Type `developer` in `IAM principal ARN` in `IAM principal`
** Choose `arn:aws:iam::xxxxxxxxxxxx:user/developer` from the list
** Click `Next`
* In `Add access policy` page
** `AmazonEKSClusterAdminPolicy` in `Policy name`
** Click `Add policy`
** Click `Next`
* In `Review and create` page
** Click `Create`

After do these instructions, you can get kubeconfig and run kubectl.

```
eks-operator$ aws eks update-kubeconfig --name my-cluster-0001
> Updated context arn:aws:eks:ap-northeast-1:xxxxxxxxxxxx:cluster/my-cluster-0001 in /root/.kube/config

eks-operator$ kubectl get services
> NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
> kubernetes   ClusterIP   x.x.x.x      <none>        443/TCP   4h
```

## Remove an op from CoreDNS

* [Patch CoreDNS command is giving error](https://repost.aws/questions/QU6WizKiheRguK_lk43cPCSg/patch-coredns-command-is-giving-error)

```
eks-operator$ kubectl describe deployment coredns -n kube-system
> ...
> Pod Template:
>   Labels:           eks.amazonaws.com/component=coredns
>                     k8s-app=kube-dns
>   Annotations:      eks.amazonaws.com/compute-type: ec2
>    Service Account:  coredns
> ...

eks-operator$ # Remove `Annotations` if you could see it
eks-operator$ kubectl patch deployment coredns -n kube-system --type json \
                  -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
```

# Deletion
If you want to delete role and policy, you can use the following commands.

```
eks-operator$ aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy --role-name AmazonEKSFargatePodExecutionRole
eks-operator$ aws iam delete-role --role-name AmazonEKSFargatePodExecutionRole
```

# Deploy a sample application

* [Deploy a sample application](https://docs.aws.amazon.com/eks/latest/userguide/sample-deployment.html)


