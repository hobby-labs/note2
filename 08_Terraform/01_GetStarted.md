# Reference

* Dockerfile
```
FROM ubuntu:24.04
MAINTAINER "Tsutomu Nakamura"
RUN \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl vim unzip && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/
```

```
docker build -t tsutomu/dind-ubuntu2404 .
```

Create Ubuntu docker container on docker.

```
docker run --privileged --rm \
        --name terraform-docker \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v ${PWD}:/root \
        --entrypoint /bin/bash -ti tsutomu/dind-ubuntu2404

cd /root
```

# Instructions to prepare terraform

```
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg software-properties-common wget
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

apt-get update
apt-get install terraform
terraform --help
terraform -help plan
```

Enable completion.

```bash
# For bash
touch ~/.bashrc
terraform -install-autocomplete
```

## Prepare first terraform project

```
mkdir learn-terraform-docker-container
cd learn-terraform-docker-container
```

* main.tf
```
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx"
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "tutorial"

  ports {
    internal = 80
    external = 8000
  }
}
```

Initialize the project.
A command below will start downloading plugin that called provider that lets Terraform interact with Docker.

```
terraform init
...

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

Provision the NGINX server container with apply.

```
terraform apply
```

```
docker ps
...
CONTAINER ID   IMAGE                     COMMAND                  CREATED         STATUS         PORTS                  NAMES
aa1680699cab   e0c9858e10ed              "/docker-entrypoint.…"   9 seconds ago   Up 9 seconds   0.0.0.0:8000->80/tcp   tutorial
```

Open the browser and access to http://localhost:8000

```
terraform destroy
```

```
```

; Get Started - AWS
: https://developer.hashicorp.com/terraform/tutorials/aws-get-started

; What is Infrastructure as Code with Terraform?
: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/infrastructure-as-code


