# AWS Infrastructure with Terraform, Auto Scaling & Ansible

A hands-on AWS infrastructure lab built with Terraform and Ansible. The project started as a simple VPC and EC2 deployment and was gradually extended to support load balancing, automatic instance provisioning, and EC2 Auto Scaling.

The main goal was to understand how these services work together, rather than configuring each one separately.

I deployed the infrastructure in the AWS Mumbai region (`ap-south-1`), tested the Nginx application through an Application Load Balancer, verified instance health, and tested scaling the EC2 fleet from two instances to three and back.

All infrastructure was destroyed after testing to avoid leaving unnecessary AWS resources running.

## Architecture

```text
                     Internet
                        |
                        v
              Application Load Balancer
                 HTTP Listener :80
                        |
                        v
                    Target Group
                   Health Check /
                        |
           +------------+------------+
           |                         |
     Public Subnet A           Public Subnet B
      ap-south-1a               ap-south-1b
           |                         |
       Nginx EC2                 Nginx EC2
           |                         |
           +------------+------------+
                        |
                 Auto Scaling Group
                  Min: 1 / Max: 3
                  Desired: 2
                        |
                 Launch Template
                        |
                EC2 User Data
                        |
                Ansible Playbook
                        |
              Install & Start Nginx
```

Both public subnets are inside the same VPC. The ALB accepts HTTP requests and forwards them to healthy EC2 instances. Auto Scaling manages the number of EC2 instances, while Ansible configures Nginx during instance startup.

## Tools and services

- **Terraform:** Provisioning and managing AWS infrastructure
- **AWS VPC:** Network isolation, subnets, routing, and internet access
- **EC2:** Hosting the Nginx web application
- **Application Load Balancer:** Distributing HTTP requests
- **EC2 Auto Scaling:** Managing instance capacity and replacement
- **Ansible:** Installing Nginx and deploying the website
- **AWS CLI:** Checking infrastructure and testing scaling operations
- **Git and GitHub:** Source control and project history

## Infrastructure configuration

| Component | Configuration |
|---|---|
| AWS region | `ap-south-1` |
| VPC CIDR | `10.0.0.0/16` |
| Public subnet A | `10.0.1.0/24` |
| Public subnet B | `10.0.2.0/24` |
| EC2 AMI | Amazon Linux 2023 |
| EC2 instance type | `t3.micro` |
| Web server | Nginx |
| ALB listener | HTTP port 80 |
| Health check | HTTP `/`, expected status 200 |
| Minimum instances | 1 |
| Desired instances | 2 |
| Maximum instances | 3 |
| CPU scaling target | 50% average utilization |

### Networking and security

The VPC uses two public subnets in separate Availability Zones. Both subnets are associated with a route table that provides internet connectivity through an Internet Gateway.

I used separate security groups for the load balancer and application instances.

The ALB accepts HTTP traffic on port 80. The EC2 security group allows HTTP connections from the ALB security group rather than accepting direct HTTP traffic from the entire internet.

SSH access is restricted to a configurable source IPv4 CIDR. EC2 root volumes are encrypted, and the launch template requires IMDSv2.

This setup uses HTTP for the learning environment. A production deployment should use HTTPS and place application instances in private subnets.

## How Ansible is used

One issue with Auto Scaling is that instances can be launched or replaced at any time. Configuring the first EC2 instance manually would not configure future instances.

To solve this, I added an Ansible playbook that runs during instance initialization.

The launch template contains EC2 user data that:

1. Installs the required Python packages.
2. Creates a Python virtual environment and installs Ansible.
3. Retrieves the playbook content embedded by Terraform.
4. Runs the playbook locally on the instance.

The playbook installs Nginx, deploys the HTML page, starts the service, and enables it to start automatically after reboot.

This allows new Auto Scaling instances to configure themselves without manual SSH access.

The playbook is located at `ansible/deploy_nginx.yml`.

## Project structure

```text
SZ-terraform-lab/
├── ansible/
│   └── deploy_nginx.yml
├── .gitignore
├── .terraform.lock.hcl
├── alb.tf
├── autoscaling.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars.example
├── variables.tf
├── versions.tf
└── README.md
```

`main.tf` contains the VPC, subnets, internet gateway, routing, and application security group. `alb.tf` contains the ALB, target group, listener, and ALB security group.

`autoscaling.tf` defines the launch template, Auto Scaling Group, CPU target-tracking policy, and instance initialization script.

## Deploying the project

You will need Terraform, AWS CLI, an AWS account with the required permissions, and configured AWS credentials.

Clone the repository:

```bash
git clone https://github.com/Szin7/SZ-terraform-lab.git
cd SZ-terraform-lab
```

Create a local variables file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Update `ssh_allowed_cidr` with your own public IPv4 address followed by `/32`. Review the region and instance settings before continuing.

Initialize and validate Terraform:

```bash
terraform init
terraform fmt -check
terraform validate
```

Review the execution plan:

```bash
terraform plan
```

If the proposed resources and costs are acceptable, deploy:

```bash
terraform apply
```

After deployment, retrieve the load balancer URL:

```bash
terraform output website_url
```

Open the returned URL in a browser. The Nginx page should appear once the instances finish initialization and pass their health checks.

**AWS resources in this project may incur charges, including EC2 instances, EBS volumes, public IPv4 addresses, and the Application Load Balancer.**

## Testing and results

I deployed and tested this infrastructure in AWS before destroying the resources.

### 1. Terraform deployment

Terraform successfully created all 15 managed resources:

```text
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
```

### 2. Nginx application

I opened the ALB DNS address in a browser and confirmed the deployed website displayed:

```text
Welcome to SZ Terraform Lab!
Deployed using Terraform and Ansible
Application: Nginx
Infrastructure: AWS EC2 Auto Scaling
```

This confirmed the website was accessible through the load balancer and that the application configuration had been deployed.

### 3. ALB health checks

I queried the target group using the AWS CLI.

Both registered EC2 instances reported `healthy`. The Auto Scaling Group also showed both instances as `InService` and `Healthy`.

### 4. Scale-out test

The Auto Scaling Group was initially configured with a desired capacity of two instances.

I temporarily increased the desired capacity to three:

```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name SZ-terraform-lab-asg \
  --desired-capacity 3 \
  --region ap-south-1
```

AWS launched a third instance. The new instance subsequently appeared as `InService` and `Healthy`.

### 5. Scale-in test

I reduced desired capacity back to two:

```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name SZ-terraform-lab-asg \
  --desired-capacity 2 \
  --region ap-south-1
```

AWS initiated termination of one instance, returning the group toward its original capacity.

The CPU target-tracking policy was also verified as enabled, with a target of 50% average CPU utilization. I did not conduct a separate CPU-load test, so automatic CPU-triggered scaling is not claimed as a tested result.

## Issues I ran into

A few problems came up while building the lab.

**Terraform providers on Windows and WSL:** I initially initialized Terraform in Windows and later ran commands through WSL. Terraform needed the appropriate platform-specific AWS provider binaries, so I had to initialize the environment again.

**Ansible execution environment:** I first tried running Ansible directly from PowerShell. I switched to WSL Ubuntu, where Ansible was installed and the playbook syntax check succeeded.

**Removing the original EC2 resource:** After replacing the standalone EC2 instance with an Auto Scaling Group, Terraform validation failed because the outputs still referenced the removed instance. I updated the outputs to use the ALB DNS name instead.

**EC2 startup script formatting:** I corrected Windows-style line endings in the Terraform user-data script to avoid potential Linux execution issues.

These were useful reminders to validate the configuration after each change and to pay attention to differences between development environments.

## Cleanup

I ran:

```bash
terraform plan -destroy
terraform destroy
```

Terraform reported:

```text
Destroy complete! Resources: 15 destroyed.
```

I then verified that `terraform state list` returned no managed resources. A new `terraform plan` proposed creating the infrastructure again, which confirmed the environment was ready for redeployment.

Destroying the infrastructure does not delete the source code or GitHub repository.

## What I learned

This project helped me better understand the relationship between networking, compute, configuration management, and scaling in AWS.

The most useful part was seeing how the entire system behaved after deployment: instances registering with the ALB, health checks passing, an additional instance joining the Auto Scaling Group, and an instance being removed during scale-in.

It also gave me practical experience troubleshooting Terraform references, Ansible execution, startup configuration, and AWS CLI commands.

## Possible improvements

There are several things I would improve in a future iteration:

- Move the application instances to private subnets.
- Add HTTPS using AWS Certificate Manager.
- Build a reusable AMI with Ansible instead of installing Ansible during every boot.
- Add GitHub Actions to validate Terraform changes automatically.
- Add monitoring and alerting with CloudWatch.
- Test CPU-triggered scaling using a controlled workload.
- Move Terraform state to an S3 backend with appropriate access controls and state locking.

This repository is a learning project rather than a production-ready infrastructure template.