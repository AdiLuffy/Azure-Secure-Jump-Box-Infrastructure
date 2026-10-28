# Azure Secure Jump Box Infrastructure

This project provisions a small Azure lab environment with:

- 1 resource group
- 1 virtual network with two subnets
- 1 public Windows jump box VM
- 1 private Linux VM accessible only from the jump box
- Network security groups with restricted inbound access

## Architecture

- `vm1` is the public Windows VM used as the jump host.
- `vm2` is private-only and has no public IP.
- SSH access to `vm2` is allowed only from the private IP of `vm1`.
- The public VM has RDP enabled only from your laptop IP.

## Files

- `main.tf` — Terraform configuration for the infrastructure
- `.gitignore` — ignores Terraform state and local cache files
- `Screenshots/` — screenshots of the lab setup and resources

## Prerequisites

Before deploying, make sure you have:

- Azure CLI installed and logged in
- A valid Azure subscription
- Terraform installed
- Your laptop public IPv4 address

## Login to Azure

```bash
az login
az account set --subscription "<your-subscription-name-or-id>"
```

## Fill required Terraform variables

You must provide values for the following variables when running Terraform:

- `my_ip`
- `admin_password`

Example:

```bash
terraform init
terraform plan \
  -var="my_ip=49.37.12.34" \
  -var="admin_password=YourStrongPassword123!"
```

## Deploy

```bash
terraform apply \
  -var="my_ip=49.37.12.34" \
  -var="admin_password=YourStrongPassword123!"
```

## Optional: custom region or VM size

You can override defaults in the Terraform variables section:

```bash
terraform apply \
  -var="location=centralindia" \
  -var="vm_size=Standard_B1ms" \
  -var="my_ip=49.37.12.34" \
  -var="admin_password=YourStrongPassword123!"
```

## Outputs

After deployment, Terraform will print:

- `vm1_public_ip`
- `vm2_private_ip`

## Notes

- `my_ip` should be your actual public IP without a `/32` suffix.
- `admin_password` must meet Azure password rules.
- The configuration intentionally keeps `vm2` private to model a secure bastion/jump-box architecture.

## Cleanup

```bash
terraform destroy \
  -var="my_ip=49.37.12.34" \
  -var="admin_password=YourStrongPassword123!"
```
