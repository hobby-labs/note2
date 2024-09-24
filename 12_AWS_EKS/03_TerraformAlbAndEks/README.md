# Run

* [Terraformでセキュリティグループを設定してEC2にhttp接続する](https://qiita.com/kakita-yzrh/items/6bdc11f2882c67a949ad#terraform%E3%81%A7%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E3%82%B0%E3%83%AB%E3%83%BC%E3%83%97%E3%81%AE%E5%AE%9A%E7%BE%A9%E3%82%92%E8%A1%8C%E3%81%86)
* [TerraformでALBを構築してみる](https://qiita.com/kakita-yzrh/items/27684b9c36c8be20eafd)
* [CreateTargetGroup](https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_CreateTargetGroup.html)

* [Patterns for TargetGroupBinding with AWS Load Balancer Controller](https://aws.amazon.com/jp/blogs/containers/patterns-for-targetgroupbinding-with-aws-load-balancer-controller/)
* [A deeper look at Ingress Sharing and Target Group Binding in AWS Load Balancer Controller](https://aws.amazon.com/jp/blogs/containers/a-deeper-look-at-ingress-sharing-and-target-group-binding-in-aws-load-balancer-controller/)

* [Route internet traffic with AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

```
host$ docker run -it --rm --hostname tf --name tf -v ${PWD}:/root/work --entrypoint /bin/bash tsutomu/terraform-runner
tf$ cd /root/work/01-learn-terraform-provision-eks-cluster/
```

```
tf$ aws configure --profile developer
> AWS Access Key ID [None]: ${AWS_ACCESS_KEY_ID}
> AWS Secret Access Key [None]: ${AWS_SECRET_ACCESS_KEY}
> Default region name [None]: ap-northeast-1
> Default output format [None]: json
tf$ export AWS_PROFILE=developer
```

```
tf$ terraform init
tf$ terraform plan
tf$ terraform apply
```

```
tf$ cd ../02-learn-terraform-deploy-alb-eks
tf$ terraform init
tf$ terraform plan
tf$ terraform apply
```

# Traffic ALB

* [EKS: ALB controller — how to use existing NLB](https://medium.com/@artem.hatchenko/eks-alb-controller-how-to-use-existing-nlb-4b71b91af939)
Create kubernetes manifest to receive traffic from ALB.

* manifest.yaml
```
---
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: nginx-target_group_binding
spec:
  serviceRef:
    name: nginx
    port: 30007
  targetGroupARN: arn:aws:eks:ap-northeast-1:008971668354:cluster/eks-01

---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  #namespace: playground
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-scheme: internal
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules: "true"
  labels:
    app: nginx
spec:
  selector:
    app:nginx
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    nodePort: 30007
  selector:
    #app.kubernetes.io/name: nginx
    app: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
```

