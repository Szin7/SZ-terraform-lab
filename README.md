# SZ-terraform-lab

## Overview

A beginner-friendly Infrastructure as Code project that provisions AWS networking and a Linux web server using Terraform.

## Resources

- Amazon VPC (`10.0.0.0/16`)
- Public subnet (`10.0.1.0/24`)
- Internet Gateway
- Public route table and subnet association
- Security group with HTTP and restricted SSH access
- Amazon Linux 2023 EC2 instance running Nginx

## Prerequisites

- Terraform CLI
- AWS CLI
- AWS account and appropriately permissioned IAM credentials
- Git

## Deploy

1. Configure AWS credentials using `aws configure` or your existing AWS profile.
2. Copy `terraform.tfvars.example` to `terraform.tfvars`.
3. Set `ssh_allowed_cidr` to your actual public IP followed by `/32`.
4. Run `terraform init`.
5. Run `terraform fmt` and `terraform validate`.
6. Review the changes using `terraform plan`.
7. Run `terraform apply` and confirm only after reviewing the plan.
8. Open the `website_url` output in a browser.

## Cleanup

Run `terraform destroy` when finished and verify the resources have been removed.

## Security

SSH is restricted to a configured source IP; HTTP is public. Never commit AWS credentials, private keys, `terraform.tfvars`, or Terraform state files.