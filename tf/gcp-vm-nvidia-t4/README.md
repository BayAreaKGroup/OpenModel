# GCP T4 VM (n1-standard-4) Terraform

This folder provisions a single GCP VM with one T4 GPU (`nvidia-tesla-t4`) using Terraform.

## Files

- `variables.tf` — declares input variables (currently `project_id`)
- `locals.tf` — local values (IAP SSH CIDR)
- `vm_t4-n1-standard.tf` — VM and firewall resources
- `terraform.tfvars` — values for variables (edit `project_id`)
- `README.md` — usage notes

## Quick start

1. Go to this folder:
   ```bash
   cd tf/gcp-vm-nvidia-t4
   ```

2. Edit `terraform.tfvars`:
   ```hcl
   project_id = "your-real-gcp-project-id"
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the planned changes:
   ```bash
   terraform plan
   ```

5. Apply to create the VM:
   ```bash
   terraform apply
   ```

6. If you want automatic approval:
   ```bash
   terraform apply -auto-approve
   ```

7. Confirm resources:
   ```bash
   terraform show
   ```

## Destroy

To remove the VM and firewall rule:
```bash
terraform destroy
```

## Notes

- Ensure Google Cloud auth is configured:
  ```bash
  gcloud auth application-default login
  ```
- This config sets `on_host_maintenance = "TERMINATE"` and `automatic_restart = false`.
- Firewall rule only allows SSH from `35.235.240.0/20` (IAP source range).
