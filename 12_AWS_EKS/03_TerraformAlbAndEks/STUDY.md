

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

# ```bash
# tf$ curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
# ```

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

tf$ ARN="$(jq -r '.Arn' < result_iam_policies.json)"
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

## Create IAM role using aws cli
* [How to Set Up AWS Load Balancer Controller in EKS Cluster](https://aws.plainenglish.io/how-to-setup-aws-load-balancer-controller-in-eks-cluster-682a81c4e5ca)

Create `load-balancer-role-trust-policy.json`.  
  
Get oidc issuer.
```bash
tf$ OIDC_ISSUER="$(aws eks describe-cluster --name eks-01 | jq -r '.cluster.identity.oidc.issuer')"
tf$ OIDC_ISSUER="${OIDC_ISSUER##https://}"
tf$ echo $OIDC_ISSUER
> oidc.eks.ap-northeast-1.amazonaws.com/id/00000000000000000000000000000000
```

```bash
tf$ ACCOUNT="$(aws sts get-caller-identity | jq -r '.Account')"
tf$ echo $ACCOUNT
> 000000000000
```

* 
``` bash
tf$ cat << EOF > load-balancer-role-trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT}:oidc-provider/${OIDC_ISSUER}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${OIDC_ISSUER}:aud": "sts.amazonaws.com",
                    "${OIDC_ISSUER}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                }
            }
        }
    ]
}
EOF
```

Create IAM role `AmazonEKSLoadBalancerControllerRole`.

```bash
tf$ aws iam create-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --assume-role-policy-document file://"load-balancer-role-trust-policy.json"
```

Create `AWSLoadBalancerControllerIAMPolicy`.  
* [Install AWS Load Balancer Controller with Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)  

```bash
tf$ curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
tf$ aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

```

Attach IAM policies to the role `AmazonEKSLoadBalancerControllerRole` that required Amazon EKS-manage.

```bash
tf$ aws iam attach-role-policy \
  --policy-arn arn:aws:iam::${ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy \
  --role-name AmazonEKSLoadBalancerControllerRole
```

After attached the policy, check the role from the AWS console.

### Install AWS Load Balancer Controller add-on

```bash
cat << EOF > aws-load-balancer-controller-service-account.yaml
# Create a service account "aws-load-balancer-controller" annotated with the IAM role "AmazonEKSLoadBalancerControllerRole"
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT}:role/AmazonEKSLoadBalancerControllerRole
EOF
```

Apply the service account.

```bash
tf$ kubectl apply -f aws-load-balancer-controller-service-account.yaml
```

Add `eks-charts` repository and update.

```bash
tf$ helm repo add eks https://aws.github.io/eks-charts
tf$ helm repo update
```

```bash
tf$ helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=eks-01 \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
```

```bash
tf$ kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Configuration of ingress routes
Deploy sample application.

* nginx_deploy.yml
```yaml
cat << EOF > nginx_deploy.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80

##SVC Exposing as clusterIP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  ports:
  - port: 80
    protocol: TCP
  selector:
    app: nginx
EOF
```

Deploy it.

```bash
tf$ kubectl apply -f nginx_deploy.yml
tf$ kubectl get deployment nginx
```

### Create ingress route

```bash
tf$ # You must change directory that you had built the EKS cluster with terraform.
tf$ # The directory has a file terraform.tfstate.
tf$ ls -l terraform.tfstate
> -rw-r--r-- 1 root root xxxx  terraform.tfstate

tf$ PUBLIC_SUBNET_0="$(jq -r '.outputs.public_subnet_ids.value[0]' terraform.tfstate)"
tf$ PUBLIC_SUBNET_1="$(jq -r '.outputs.public_subnet_ids.value[1]' terraform.tfstate)"
```

```bash
tf$ FQDN_EKS_NGINX="nginx-app.example.com"
tf$ #SERVICE_NAME="${FQDN_EKS_NGINX%%.*}"
tf$ SERVICE_NAME="nginx"
```

Create SSL/TLS certificate from `AWS Certificate Manager`.  
* [AWS Certificate Manager(ACM) - Top](https://aws.amazon.com/jp/certificate-manager/)  

Then you obtain the ARN of the certificate and set it to a variable.

```bash
tf$ ACM_SSL_ARN="arn:aws:acm:ap-northeast-1:012345678901:certificate/00000000-0000-0000-0000-000000000000"
```

```bash
tf$ echo "FQDN_EKS_NGINX=${FQDN_EKS_NGINX}, SERVICE_NAME=${SERVICE_NAME},PUBLIC_SUBNET_0=${PUBLIC_SUBNET_0}, PUBLIC_SUBNET_1=${PUBLIC_SUBNET_1},ACM_SSL_ARN=${ACM_SSL_ARN}"
> FQDN_EKS_NGINX=test.example.com, SERVICE_NAME=nginx,PUBLIC_SUBNET_0=subnet-00000000000000000, PUBLIC_SUBNET_1=subnet-00000000000000001,ACM_SSL_ARN=arn:aws:acm:ap-northeast-1:012345678901:certificate/00000000-0000-0000-0000-000000000000

```

```bash
cat << EOF > ingress.yml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: default
  name: ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/subnets: ${PUBLIC_SUBNET_0},${PUBLIC_SUBNET_1}
    alb.ingress.kubernetes.io/certificate-arn: ${ACM_SSL_ARN}
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/group.name: app
    alb.ingress.kubernetes.io/actions.ssl-redirect: >-
        {
            "Type": "redirect",
            "RedirectConfig": {
                "Protocol": "HTTPS",
                "Port": "443",
                "Host": "#{host}",
                "Path": "/#{path}",
                "Query": "#{query}",
                "StatusCode": "HTTP_301"
            }
        }
spec:
  rules:
     - host: ${FQDN_EKS_NGINX}
       http:
        paths:
          - path: /
            pathType: Prefix
            backend:
             service:
              name: ssl-redirect
              port:
               name: use-annotation
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${SERVICE_NAME}
                port:
                  number: 80
EOF
```

Apply the ingress route.

```bash
tf$ kubectl apply -f ingress.yml
```

