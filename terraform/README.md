# Terraform Infrastructure for Student Portal

This Terraform configuration sets up a production-ready AWS infrastructure for the Student Portal application on EKS (Elastic Kubernetes Service).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Region                           │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐ │
│  │                      VPC (10.0.0.0/16)                 │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Public Subnets (NAT Gateway)                    │  │ │
│  │  │  ┌─────────────────────────────────────────────┐ │  │ │
│  │  │  │  Internet Gateway (IGW)                     │ │  │ │
│  │  │  └─────────────────────────────────────────────┘ │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Private Subnets                                │  │ │
│  │  │  ┌────────────────────────────────────────────┐ │  │ │
│  │  │  │  EKS Cluster                              │ │  │ │
│  │  │  │  ├─ Master Nodes                          │ │  │ │
│  │  │  │  └─ Worker Nodes (Auto-scaling)          │ │  │ │
│  │  │  └────────────────────────────────────────────┘ │  │ │
│  │  │  ┌────────────────────────────────────────────┐ │  │ │
│  │  │  │  RDS MySQL Instance                       │ │  │ │
│  │  │  │  ├─ Multi-AZ Deployment                   │ │  │ │
│  │  │  │  ├─ Automated Backups                     │ │  │ │
│  │  │  │  └─ Encryption at Rest                    │ │  │ │
│  │  │  └────────────────────────────────────────────┘ │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ECR Repositories                                      │ │
│  │  ├─ Backend Container Images                         │ │
│  │  └─ Frontend Container Images                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  CloudWatch                                            │ │
│  │  ├─ EKS Cluster Logs                                 │ │
│  │  ├─ RDS Monitoring & Alarms                          │ │
│  │  └─ Application Logs                                 │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Networking Module (`modules/networking/`)
- **VPC**: Custom VPC with configurable CIDR blocks
- **Public Subnets**: For NAT Gateways and load balancers
- **Private Subnets**: For EKS nodes and RDS
- **NAT Gateways**: Enable outbound internet access for private resources
- **Security Groups**: 
  - EKS Cluster SG: API access on port 443
  - EKS Nodes SG: Worker node communication
  - RDS SG: MySQL access from EKS nodes

### 2. IAM Module (`modules/iam/`)
- **EKS Cluster Role**: Service role for EKS control plane
- **EKS Worker Role**: Service role for worker nodes
- **OIDC Provider**: Enables IRSA (IAM Roles for Service Accounts)
- **Addon Roles**:
  - ALB Controller: For ingress management
  - EBS CSI Driver: For persistent storage
  - CloudWatch Logs: For log streaming
  - Application Secrets: For accessing AWS Secrets Manager

### 3. EKS Module (`modules/eks/`)
- **EKS Cluster**: Kubernetes control plane
  - Version: 1.28 (production) - configurable
  - API logging enabled for audit trail
  - Encryption at rest using KMS
  - VPC CNI for networking
- **Managed Node Group**: Auto-scaling EC2 instances
  - Configurable instance types (default: t3.medium)
  - Spot instances for cost optimization (staging/dev only)
  - CloudWatch monitoring enabled
  - Auto-scaling based on metrics

### 4. RDS Module (`modules/rds/`)
- **MySQL Database**: Managed relational database
  - Version: 8.0.35 (configurable)
  - Multi-AZ deployment for high availability
  - Automated backups (30 days retention for production)
  - Encryption at rest + SSL/TLS support
  - CloudWatch monitoring and performance insights
  - Enhanced monitoring with IAM role
- **Secrets Manager Integration**: Credentials stored securely
- **CloudWatch Alarms**: CPU, connections, and storage alerts

### 5. ECR Module (`modules/ecr/`)
- **Backend Repository**: For backend service images
- **Frontend Repository**: For frontend service images
- **Image Scanning**: Vulnerability scanning on push
- **Lifecycle Policies**: Automatic cleanup of old images
- **Immutable Tags**: Prevent accidental image overwrites

## Prerequisites

1. **AWS Account**: With appropriate permissions
2. **Terraform**: v1.5 or higher
3. **AWS CLI**: Configured with credentials
4. **kubectl**: For Kubernetes management (v1.26+)
5. **helm**: For Helm chart deployments (v3.0+)

## Installation

### Step 1: Initialize Terraform Backend

Before deploying, create the S3 bucket and DynamoDB table for state management:

```bash
# From root terraform directory
aws s3api create-bucket \
  --bucket student-portal-terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 2: Initialize Terraform

```bash
cd environments/production
terraform init
```

### Step 3: Configure Variables

Set the RDS master password as an environment variable:

```bash
export TF_VAR_rds_master_password="YourSecurePassword123!"
```

### Step 4: Plan and Apply

```bash
# Review the plan
terraform plan -var-file=terraform.tfvars

# Apply the configuration
terraform apply -var-file=terraform.tfvars
```

## Usage

### Retrieve Outputs

```bash
terraform output

# Get specific outputs
terraform output eks_cluster_id
terraform output rds_endpoint
terraform output ecr_backend_repository_url
```

### Configure kubectl

```bash
# Configure kubectl to use the new EKS cluster
aws eks update-kubeconfig \
  --region us-east-2 \
  --name student-portal-production

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### Deploy to EKS

```bash
# Install Helm charts
helm install student-portal helm-charts/student-portal/ \
  --namespace student-portal \
  --create-namespace \
  -f helm-charts/student-portal/values.yaml
```

## Environment Management

### Production Environment

```bash
cd terraform/environments/production
terraform init
terraform apply -var-file=terraform.tfvars

# Configuration:
# - 3 desired nodes, min 2, max 10
# - db.t3.small RDS instance with Multi-AZ
# - 100GB allocated storage
# - 30-day backup retention
# - ON_DEMAND instances for stability
```

### Staging Environment

```bash
cd terraform/environments/staging
terraform init
terraform apply -var-file=terraform.tfvars

# Configuration:
# - 2 desired nodes, min 1, max 5
# - db.t3.micro RDS instance (no Multi-AZ)
# - 50GB allocated storage
# - 7-day backup retention
# - SPOT instances for cost savings
```

## State Management

Terraform state is stored in S3 with:
- **Versioning**: Enabled for disaster recovery
- **Encryption**: AES-256 for data at rest
- **Locking**: DynamoDB table prevents concurrent modifications
- **Access Control**: Private bucket with restricted ACLs

### Backup State

```bash
# Manually backup state
aws s3 cp s3://student-portal-terraform-state/production/terraform.tfstate ./terraform.tfstate.backup

# List state versions
aws s3api list-object-versions --bucket student-portal-terraform-state
```

## Monitoring and Maintenance

### CloudWatch Logs

View cluster logs:
```bash
aws logs tail /aws/eks/student-portal-production --follow
```

### RDS Monitoring

```bash
# Check RDS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=student-portal-production-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Auto-scaling Status

```bash
# Check EKS node group scaling
aws eks describe-nodegroup \
  --cluster-name student-portal-production \
  --nodegroup-name student-portal-production-node-group
```

## Troubleshooting

### EKS Cluster Access Issues

```bash
# Verify IAM permissions
aws sts get-caller-identity

# Check cluster security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=student-portal-*-eks-cluster-*"

# View cluster events
kubectl describe nodes
kubectl get events --all-namespaces
```

### RDS Connection Issues

```bash
# Check database availability
aws rds describe-db-instances \
  --db-instance-identifier student-portal-production-db

# View RDS security group
aws ec2 describe-security-groups \
  --group-ids <RDS-SG-ID>
```

### Terraform State Issues

```bash
# List available state versions
aws s3api list-object-versions \
  --bucket student-portal-terraform-state \
  --prefix production/

# Recover previous state
aws s3api get-object \
  --bucket student-portal-terraform-state \
  --key production/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.previous
```

## Cost Optimization

### Recommendations

1. **Spot Instances**: Use for non-production workloads (20-70% savings)
2. **Reserved Instances**: For production baseline capacity
3. **Auto-scaling**: Configure HPA to scale up/down based on load
4. **RDS Parameter**: Consider db.t3.micro for dev/staging
5. **NAT Gateway**: Single per AZ in production reduces data transfer costs
6. **ECR Lifecycle**: Automatic cleanup reduces storage costs

## Security Best Practices

1. **Secrets Management**:
   ```bash
   # Store RDS password in Secrets Manager
   aws secretsmanager create-secret --name student-portal/rds \
     --secret-string '{"password":"..."}'
   ```

2. **Network Security**:
   - Restrict security group ingress
   - Use VPC endpoints for AWS services
   - Enable VPC Flow Logs

3. **IAM**:
   - Use IRSA for pod authentication
   - Implement least privilege policies
   - Enable CloudTrail for audit logs

4. **Database**:
   - Enable encryption at rest and in transit
   - Use secrets rotation
   - Regular backups and testing

## Backup and Disaster Recovery

### RDS Backups

```bash
# Automated backups configured (30 days production)
# No manual action required

# Manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier student-portal-production-db \
  --db-snapshot-identifier manual-backup-$(date +%s)
```

### Terraform State Backups

```bash
# Automated with S3 versioning
# Manual backup of critical state
aws s3 sync s3://student-portal-terraform-state/production ./terraform-backups/
```

## Cleanup

### Delete All Resources

```bash
# WARNING: This will destroy all infrastructure

cd environments/production

# Remove all resources except state bucket
terraform destroy -var-file=terraform.tfvars

# Manually delete state bucket (if needed)
aws s3 rm s3://student-portal-terraform-state-<ACCOUNT_ID>/ --recursive
```

## Additional Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/best-practices/)
- [Helm Chart Development](https://helm.sh/docs/chart_template_guide/)

## Support and Contribution

For issues or improvements, please:
1. Check existing documentation
2. Review CloudWatch logs
3. Check Terraform state consistency
4. Contact DevOps team

---

**Last Updated**: March 30, 2026
**Terraform Version**: v1.5.0+
**AWS Provider Version**: ~5.0
