# terraform-aws-infra

> A production-grade multi-tier AWS infrastructure provisioned entirely through reusable Terraform modules.
> Every resource — VPC, subnets, ALB, EC2 Auto Scaling, RDS PostgreSQL — is defined as code,
> versioned in Git, and deployable from zero in under 10 minutes.

---

## Live Infrastructure!

```
curl http://irfan-infra-alb-2021315130.us-east-1.elb.amazonaws.com
# <h1>Hello from ip-10-0-1-126.ec2.internal — Deployed by Terraform + GitOps</h1>
```

---

## Architecture!

```
                        Internet
                            │
                            ▼
                ┌─────────────────────┐
                │  Application Load   │
                │  Balancer (ALB)     │
                │  port 80 · public   │
                └──────────┬──────────┘
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
  ┌──────────────────┐         ┌──────────────────┐
  │  Public Subnet   │         │  Public Subnet   │
  │  us-east-1a      │         │  us-east-1b      │
  │  10.0.1.0/24     │         │  10.0.2.0/24     │
  │                  │         │                  │
  │  EC2 t3.micro    │         │  EC2 t3.micro    │
  │  Auto Scaling    │         │  Auto Scaling    │
  └────────┬─────────┘         └────────┬─────────┘
           │                            │
  ┌────────▼─────────┐         ┌────────▼─────────┐
  │  Private Subnet  │         │  Private Subnet  │
  │  us-east-1a      │         │  us-east-1b      │
  │  10.0.3.0/24     │         │  10.0.4.0/24     │
  │                  │         │                  │
  │  RDS PostgreSQL  │◄────────│  RDS (standby)   │
  │  db.t3.micro     │         │  Multi-AZ ready  │
  └──────────────────┘         └──────────────────┘

  Remote State: S3 bucket + DynamoDB locking
  All resources tagged: Project, ManagedBy, Owner
```

---

## What This Project Demonstrates

- **Infrastructure as Code** — zero manual AWS console clicks, everything in `.tf` files
- **Reusable modules** — each component (VPC, ALB, EC2, RDS) is an independent module with inputs/outputs
- **Remote state** — Terraform state stored in S3 with DynamoDB locking, safe for team use
- **Security layering** — ALB → EC2 → RDS traffic chain enforced through security groups, RDS unreachable from internet
- **Auto Scaling** — EC2 instances scale from 1 to 3 based on CPU utilization (CloudWatch alarm at 70%)
- **High availability** — resources spread across 2 availability zones
- **Immutable infrastructure** — change the code, run apply, Terraform handles the diff

---

## Module Structure

```
terraform-aws-infra/
├── main.tf                      ← root — wires all modules together
├── variables.tf                 ← all input variable definitions
├── outputs.tf                   ← ALB DNS, RDS endpoint, subnet IDs
├── versions.tf                  ← provider version locks + S3 backend
├── terraform.tfvars             ← actual values (gitignored — never committed)
└── modules/
    ├── vpc/                     ← VPC, subnets, IGW, route tables
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security_groups/         ← ALB SG, EC2 SG, RDS SG
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/                     ← ALB, target group, listener
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ec2/                     ← launch template, ASG, scaling policy
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/                     ← PostgreSQL, subnet group
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Resources Provisioned (24 total)

| Module | Resources |
|--------|-----------|
| **vpc** | VPC, 2 public subnets, 2 private subnets, IGW, 2 route tables, 4 route table associations |
| **security_groups** | ALB security group, EC2 security group, RDS security group |
| **alb** | Application Load Balancer, target group, HTTP listener |
| **ec2** | Launch template, Auto Scaling Group, scaling policy, CloudWatch alarm |
| **rds** | DB subnet group, RDS PostgreSQL instance |
| **backend** | S3 bucket (remote state), DynamoDB table (state locking) |

---

## Security Design

### Traffic flow — least privilege enforced
```
Internet → ALB SG (port 80 open)
         → EC2 SG (only accepts from ALB SG — not the internet)
         → RDS SG (only accepts port 5432 from EC2 SG — completely private)
```

No direct internet access to EC2 or RDS. The only public entry point is the ALB.

### Key security settings
- RDS `publicly_accessible = false` — unreachable from outside VPC
- RDS `storage_encrypted = true` — data encrypted at rest
- S3 state bucket `encryption = AES256` — state file encrypted
- S3 state bucket versioning enabled — recover previous state if corrupted
- `terraform.tfvars` gitignored — DB credentials never committed to Git
- All resources tagged with `ManagedBy = terraform` for cost tracking

---

## How to Deploy

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- AWS account with IAM user permissions

### Step 1 — Create the remote state backend
```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 2 — Configure variables
```bash
# Copy and edit tfvars (never commit this file)
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Step 3 — Deploy
```bash
terraform init
terraform plan
terraform apply
```

### Step 4 — Access your app
```bash
# Get the ALB DNS from outputs
terraform output alb_dns_name

# Hit the app
curl http://<alb_dns_name>
```

### Destroy (important — avoid costs)
```bash
terraform destroy
```

---

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `project_name` | Prefix for all resource names | `irfan-infra` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `asg_min_size` | Minimum EC2 instances | `1` |
| `asg_max_size` | Maximum EC2 instances | `3` |
| `asg_desired_capacity` | Desired EC2 instances | `2` |
| `db_instance_class` | RDS instance class | `db.t3.micro` |
| `db_name` | PostgreSQL database name | `irfandb` |
| `db_username` | RDS master username | `irfanadmin` |
| `db_password` | RDS master password | **required, sensitive** |

---

## Outputs

| Output | Description |
|--------|-------------|
| `alb_dns_name` | ALB DNS — open in browser to access the app |
| `vpc_id` | VPC ID |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `asg_name` | Auto Scaling Group name |
| `db_endpoint` | RDS connection endpoint |
| `db_name` | Database name |

---

## Key Engineering Decisions

### Why separate modules for each component?
Each module has its own `variables.tf`, `main.tf`, and `outputs.tf`. This means the VPC module can be reused in a completely different project with different CIDRs by just changing the inputs. Modules also make `terraform plan` output readable — you see `module.vpc.aws_subnet.public[0]` instead of a flat list of 24 resources.

### Why S3 + DynamoDB for state?
Local state (`terraform.tfstate`) is dangerous — one corrupted file and you lose track of your entire infrastructure. S3 remote state with DynamoDB locking means: (1) state is backed up and versioned, (2) two people cannot run `terraform apply` simultaneously and corrupt the state, (3) CI/CD pipelines can run Terraform safely.

### Why private subnets for RDS?
The RDS instance has `publicly_accessible = false` and sits in subnets with no route to the internet gateway. Even if the RDS security group was misconfigured, the network layer prevents any external access. Defense in depth — security at both the network and application layer.

### Why `create_before_destroy` on EC2?
```hcl
lifecycle {
  create_before_destroy = true
}
```
When updating a launch template, Terraform creates the new resource before destroying the old one. Without this, there is a window where no instances exist and the ALB returns 502 errors.

---

## What I Would Add Next

- **HTTPS** — ACM certificate + ALB HTTPS listener on port 443
- **Bastion host** — SSH access to EC2 without exposing port 22 to the internet
- **RDS Multi-AZ** — automatic failover to standby in the second AZ
- **CloudFront** — CDN in front of ALB for caching and DDoS protection
- **GitHub Actions integration** — `terraform plan` on PRs, `terraform apply` on merge to main
- **Terraform workspaces** — separate state for dev, staging, and production environments

---

## Related Project

This infrastructure is designed to host the application from
[gitops-cicd-pipeline](https://github.com/irfanjat/gitops-cicd-pipeline) —
where GitHub Actions builds Docker images and ArgoCD deploys them to Kubernetes.

---

## Author

**Irfan Ali** — CS student building production-grade DevOps infrastructure.

[![GitHub](https://img.shields.io/badge/GitHub-irfanjat-181717?logo=github)](https://github.com/irfanjat)
[![GitOps Pipeline](https://img.shields.io/badge/Related-GitOps_CI/CD_Pipeline-185FA5?logo=github)](https://github.com/irfanjat/gitops-cicd-pipeline)
