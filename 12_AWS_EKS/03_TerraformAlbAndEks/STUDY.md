

* [Resource: aws_lb - Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)
* [AWS Load Balancer 削除時に delete protection でエラー](https://blog.fits-inc.jp/2021/06/05/aws-load-balancer-%E5%89%8A%E9%99%A4%E6%99%82%E3%81%AB-delete-protection-%E3%81%A7%E3%82%A8%E3%83%A9%E3%83%BC/amp/)
* [Can keep load balancer after delete service in EKS](https://stackoverflow.com/questions/74923188/can-keep-load-balancer-after-delete-service-in-eks)
* [Do I need AWS ALB for application running in EKS?](https://stackoverflow.com/questions/65529078/do-i-need-aws-alb-for-application-running-in-eks)
* [Ingress annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations/)
* [Route internet traffic with AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
* [Route application and HTTP traffic with Application Load Balancers](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

# Prepare working environment

```bash
host$ docker run -it --rm --hostname tf --name tf -v ${PWD}:/root/work --entrypoint /bin/bash tsutomu/terraform-runner

tf$ aws configure --profile developer
> AWS Access Key ID [None]: ${AWS_ACCESS_KEY_ID}
> AWS Secret Access Key [None]: ${AWS_SECRET_ACCESS_KEY}
> Default region name [None]: ap-northeast-1
> Default output format [None]: json

tf$ export AWS_PROFILE=developer
```

## Create EKS cluster

```bash
tf$ cd /root/work/${project_dir}/
tf$ terraform init
tf$ terraform plan
tf$ terraform apply
```

# Install AWS Load Balancer Controller
* [Install AWS Load Balancer Controller with Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)
* [AWS Load Balancer Controller on EKS only creates Network LB](https://repost.aws/questions/QUXhp4IIOWSpenqMqRD0Y7uQ/aws-load-balancer-controller-on-eks-only-creates-network-lb)
* [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)

Create IAM role to allow AWS Load Balancer Controller to manage AWS resources with its API.

```bash
tf$ curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
```

1. Install AWS Load Balancer Controller

```bash
tf$ aws eks update-kubeconfig --name eks-01
tf$ helm 
```

## Prepare jq function

[function parseDate](https://github.com/jqlang/jq/issues/1053#issuecomment-580100213)

~/.jq
```
cat << 'EOF' > ~/.jq
def parseDate(date):
  date |
  capture("(?<no_tz>.*)(?<tz_sgn>[-+])(?<tz_hr>\\d{2}):(?<tz_min>\\d{2})$") |
  (.no_tz + "Z" | fromdateiso8601) - (.tz_sgn + "60" | tonumber) * ((.tz_hr | tonumber) * 60 + (.tz_min | tonumber));
EOF
```

## List new IAM roles

```bash
tf$ EPOCH_YESTERDAY=$(date --utc -d '360 mins ago' '+%s')
tf$ echo $EPOCH_YESTERDAY
> ...

tf$ jq ".Roles[] | select(parseDate(.CreateDate) > ${EPOCH_YESTERDAY})" < <(aws iam list-roles) | tee result_iam_roles.json
> {
>   "Path": "/",
>   "RoleName": "AmazonEKSTFEBSCSIRole-eks-01",
>   "RoleId": "AAAAAAAAAAAAAAAAAAAAA",
>   "Arn": "arn:aws:iam::012345678901:role/AmazonEKSTFEBSCSIRole-eks-01",
>   "CreateDate": "2024-09-27T23:52:16+00:00",
>   "AssumeRolePolicyDocument": {
>     "Version": "2012-10-17",
>     "Statement": [
>       {
>         "Effect": "Allow",
>         "Principal": {
>           "Federated": "arn:aws:iam::012345678901:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/00000000000000000000000000000000"
>         },
>         "Action": "sts:AssumeRoleWithWebIdentity",
>         "Condition": {
>           "StringEquals": {
>             "oidc.eks.ap-northeast-1.amazonaws.com/id/00000000000000000000000000000000:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
>           }
>         }
>       }
>     ]
>   },
>   "MaxSessionDuration": 3600
> }
> {
>   "Path": "/",
>   "RoleName": "eks-01-cluster-20240927000000000000000000",
>   "RoleId": "BBBBBBBBBBBBBBBBBBBBB",
>   "Arn": "arn:aws:iam::012345678901:role/eks-01-cluster-20240927000000000000000000",
>   "CreateDate": "2024-09-27T23:42:58+00:00",
>   "AssumeRolePolicyDocument": {
>     "Version": "2012-10-17",
>     "Statement": [
>       {
>         "Sid": "EKSClusterAssumeRole",
>         "Effect": "Allow",
>         "Principal": {
>           "Service": "eks.amazonaws.com"
>         },
>         "Action": "sts:AssumeRole"
>       }
>     ]
>   },
>   "MaxSessionDuration": 3600
> }
...
```

```bash
tf$ jq -r '.RoleName' result_iam_roles.json
> AmazonEKSTFEBSCSIRole-eks-01
> eks-01-cluster-20240927000000000000000000
> node-group-1-eks-node-group-20240927000000000000000000
> node-group-2-eks-node-group-20240927000000000000000000

tf$ aws iam get-role --role-name AmazonEKSTFEBSCSIRole-eks-01
> {
>     "Role": {
>         "Path": "/",
>         "RoleName": "AmazonEKSTFEBSCSIRole-eks-01",
>         "RoleId": "AAAAAAAAAAAAAAAAAAAAA",
>         "Arn": "arn:aws:iam::012345678901:role/AmazonEKSTFEBSCSIRole-eks-01",
>         "CreateDate": "2024-09-27T23:52:16+00:00",
>         "AssumeRolePolicyDocument": {
>             "Version": "2012-10-17",
>             "Statement": [
>                 {
>                     "Effect": "Allow",
>                     "Principal": {
>                         "Federated": "arn:aws:iam::012345678901:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
>                     },
>                     "Action": "sts:AssumeRoleWithWebIdentity",
>                     "Condition": {
>                         "StringEquals": {
>                             "oidc.eks.ap-northeast-1.amazonaws.com/id/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
>                         }
>                     }
>                 }
>             ]
>         },
>         "MaxSessionDuration": 3600,
>         "RoleLastUsed": {}
>     }
> }

tf$ aws iam list-attached-role-policies --role-name AmazonEKSTFEBSCSIRole-eks-01
> {
>     "AttachedPolicies": [
>         {
>             "PolicyName": "AmazonEBSCSIDriverPolicy",
>             "PolicyArn": "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
>         }
>     ]
> }

tf$ aws iam get-policy --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
> {
>     "Policy": {
>         "PolicyName": "AmazonEBSCSIDriverPolicy",
>         "PolicyId": "ANPAZKAPJZG4IV6FHD2UE",
>         "Arn": "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
>         "Path": "/service-role/",
>         "DefaultVersionId": "v2",
>         "AttachmentCount": 1,
>         "PermissionsBoundaryUsageCount": 0,
>         "IsAttachable": true,
>         "Description": "IAM Policy that allows the CSI driver service account to make calls to related services such as EC2 on your behalf.",
>         "CreateDate": "2022-04-04T17:24:29+00:00",
>         "UpdateDate": "2022-11-18T14:42:46+00:00",
>         "Tags": []
>     }
> }


```

List new IAM roles and attached policies.

```bash
tf$ ./get_policies_from_iam_role.sh AmazonEKSTFEBSCSIRole-eks-01
RoleName: AmazonEKSTFEBSCSIRole-eks-01
    PolicyName -> AmazonEBSCSIDriverPolicy
    Arn -> arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
    Description -> IAM Policy that allows the CSI driver service account to make calls to related services such as EC2 on your behalf.


tf$ ./get_policies_from_iam_role.sh eks-01-cluster-20240927000000000000000000
RoleName: eks-01-cluster-20240927000000000000000000
    PolicyName -> AmazonEKSClusterPolicy
    Arn -> arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
    Description -> This policy provides Kubernetes the permissions it requires to manage resources on your behalf. Kubernetes requires Ec2:CreateTags permissions to place identifying information on EC2 resources including but not limited to Instances, Security Groups, and Elastic Network Interfaces.

    PolicyName -> AmazonEKSVPCResourceController
    Arn -> arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
    Description -> Policy used by VPC Resource Controller to manage ENI and IPs for worker nodes.

    PolicyName -> eks-01-cluster-ClusterEncryption20240927000000000000000000
    Arn -> arn:aws:iam::012345678901:policy/eks-01-cluster-ClusterEncryption20240927000000000000000000
    Description -> Cluster encryption policy to allow cluster role to utilize CMK provided


tf$ ./get_policies_from_iam_role.sh node-group-1-eks-node-group-20240927000000000000000000
RoleName: node-group-1-eks-node-group-20240927000000000000000000
    PolicyName -> AmazonEKS_CNI_Policy
    Arn -> arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    Description -> This policy provides the Amazon VPC CNI Plugin (amazon-vpc-cni-k8s) the permissions it requires to modify the IP address configuration on your EKS worker nodes. This permission set allows the CNI to list, describe, and modify Elastic Network Interfaces on your behalf. More information on the AWS VPC CNI Plugin is available here: https://github.com/aws/amazon-vpc-cni-k8s

    PolicyName -> AmazonEC2ContainerRegistryReadOnly
    Arn -> arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
    Description -> Provides read-only access to Amazon EC2 Container Registry repositories.

    PolicyName -> AmazonEKSWorkerNodePolicy
    Arn -> arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
    Description -> This policy allows Amazon EKS worker nodes to connect to Amazon EKS Clusters.


tf$ ./get_policies_from_iam_role.sh node-group-2-eks-node-group-20240927000000000000000000
RoleName: node-group-2-eks-node-group-20240927000000000000000000
    PolicyName -> AmazonEKS_CNI_Policy
    Arn -> arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    Description -> This policy provides the Amazon VPC CNI Plugin (amazon-vpc-cni-k8s) the permissions it requires to modify the IP address configuration on your EKS worker nodes. This permission set allows the CNI to list, describe, and modify Elastic Network Interfaces on your behalf. More information on the AWS VPC CNI Plugin is available here: https://github.com/aws/amazon-vpc-cni-k8s

    PolicyName -> AmazonEC2ContainerRegistryReadOnly
    Arn -> arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
    Description -> Provides read-only access to Amazon EC2 Container Registry repositories.

    PolicyName -> AmazonEKSWorkerNodePolicy
    Arn -> arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
    Description -> This policy allows Amazon EKS worker nodes to connect to Amazon EKS Clusters.
```


## List new IAM policies

```bash
tf$ EPOCH_YESTERDAY=$(date --utc -d '360 mins ago' '+%s')
tf$ echo $EPOCH_YESTERDAY
> ...
tf$ jq ".Policies[] | select(parseDate(.CreateDate) > ${EPOCH_YESTERDAY}) | select(.PolicyName | contains(\"-cluster-ClusterEncryption\"))" < <(aws iam list-policies) | tee result_iam_policies.json
>{
>  "PolicyName": "eks-01-cluster-ClusterEncryption20240927000000000000000000",
>  "PolicyId": "XXXXXXXXXXXXXXXXXXXXX",
>  "Arn": "arn:aws:iam::012345678901:policy/eks-01-cluster-ClusterEncryption20240927000000000000000000",
>  "Path": "/",
>  "DefaultVersionId": "v1",
>  "AttachmentCount": 1,
>  "PermissionsBoundaryUsageCount": 0,
>  "IsAttachable": true,
>  "CreateDate": "2024-09-27T23:43:20+00:00",
>  "UpdateDate": "2024-09-27T23:43:20+00:00"
>}

tf$ ARN="$(jq -r '.Arn' < jresult_iam_policies.json)"
tf$ echo $ARN
> ...
tf$ aws iam get-policy --policy-arn "${ARN}"
>{
>    "Policy": {
>        "PolicyName": "eks-01-cluster-ClusterEncryption20240927000000000000000000",
>        "PolicyId": "XXXXXXXXXXXXXXXXXXXXX",
>        "Arn": "arn:aws:iam::012345678901:policy/eks-01-cluster-ClusterEncryption20240927000000000000000000",
>        "Path": "/",
>        "DefaultVersionId": "v1",
>        "AttachmentCount": 1,
>        "PermissionsBoundaryUsageCount": 0,
>        "IsAttachable": true,
>        "Description": "Cluster encryption policy to allow cluster role to utilize CMK provided",
>        "CreateDate": "2024-09-27T23:43:20+00:00",
>        "UpdateDate": "2024-09-27T23:43:20+00:00",
>        "Tags": []
>    }
>}
```

