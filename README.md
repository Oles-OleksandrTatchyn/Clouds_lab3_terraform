# Terraform Lab 3

Small AWS lab: Terraform builds a VPC (two public subnets, internet gateway, routes), a security group, and one Ubuntu EC2 instance. **user_data** runs `bootstrap.sh`, which installs Apache and serves a simple HTML page on a custom port.

## What you need

- Terraform and AWS CLI configured (credentials with rights to create these resources).
- An S3 backend set up as in `backend.tf` (bucket must exist in your account).
- Copy `terraform.tfvars` from your assignment (this repo ignores `*.tfvars` by default).

## Basic commands

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

After apply, open `website_url` from `terraform output` (wait a minute for the server script to finish).
