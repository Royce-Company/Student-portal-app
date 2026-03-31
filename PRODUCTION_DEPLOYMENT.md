# Production Deployment Guide

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Infrastructure Deployment](#infrastructure-deployment)
3. [Application Deployment](#application-deployment)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Scaling and Performance Tuning](#scaling-and-performance-tuning)
6. [Disaster Recovery](#disaster-recovery)
7. [Troubleshooting](#troubleshooting)

## Pre-Deployment Checklist

### AWS Account Setup
- [ ] AWS account created and access configured
- [ ] IAM user/role with appropriate permissions
- [ ] Budget alerts configured
- [ ] CloudTrail enabled for audit logging
- [ ] VPC and networking planned

### Tools Installation
- [ ] Terraform v1.5.0+ installed
- [ ] AWS CLI v2 configured
- [ ] kubectl v1.26+ installed
- [ ] helm v3.0+ installed
- [ ] Git configured

### Repository Setup
- [ ] GitHub repository created
- [ ] Branch protection rules configured
- [ ] CODEOWNERS file created
- [ ] GitHub Actions secrets configured

### DNS and SSL
- [ ] Domain name registered (e.g., student-portal.giize.com)
- [ ] Route53 hosted zone configured
- [ ] SSL certificate request prepared
- [ ] Email verification domains configured

### Environment Configuration
- [ ] RDS password generated (22+ characters with mixed case, numbers, symbols)
- [ ] JWT secret generated (32+ characters)
- [ ] API keys generated
- [ ] Docker registry credentials prepared

## Infrastructure Deployment

### Step 1: Initialize Terraform Backend

```bash
# Create S3 bucket for state
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="student-portal-terraform-state-${ACCOUNT_ID}"

aws s3api create-bucket \
  --bucket $S3_BUCKET \
  --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $S3_BUCKET \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $S3_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 2: Deploy Infrastructure

```bash
# Navigate to production environment
cd terraform/environments/production

# Export RDS password securely
export TF_VAR_rds_master_password="<your-secure-password>"

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review plan
terraform plan -var-file=terraform.tfvars -out=tfplan

# Apply configuration
terraform apply tfplan

# Export outputs
terraform output -json > terraform-outputs.json
```

### Step 3: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region us-east-2 \
  --name student-portal-production

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 4: Setup GitHub Actions OIDC

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
GITHUB_REPO="yourusername/your-repo"

# Create IAM role trust policy
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name github-actions-student-portal \
  --assume-role-policy-document file:///tmp/trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name github-actions-student-portal \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-role-policy \
  --role-name github-actions-student-portal \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSFullAccess

# Add custom policy for Terraform
cat > /tmp/terraform-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "rds:*",
        "ecr:*",
        "iam:*",
        "s3:*",
        "dynamodb:*",
        "cloudwatch:*",
        "logs:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name github-actions-student-portal \
  --policy-name github-actions-terraform \
  --policy-document file:///tmp/terraform-policy.json
```

## Application Deployment

### Step 1: Create Namespace and RBAC

```bash
kubectl apply -f helm-charts/student-portal/templates/namespace.yaml
```

### Step 2: Setup AWS Secrets Manager Integration

```bash
# Store RDS credentials in Secrets Manager
aws secretsmanager create-secret \
  --name student-portal/db-password \
  --secret-string "<your-db-password>"

aws secretsmanager create-secret \
  --name student-portal/jwt-secret \
  --secret-string "<your-jwt-secret>"

# Update EKS aws-auth ConfigMap to trust GitHub Actions role
kubectl edit configmap aws-auth -n kube-system

# Add this under mapRoles:
- groups:
  - system:masters
  rolearn: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-student-portal
  username: github-actions
```

### Step 3: Install Helm Chart

```bash
# Add Helm repository (if using public charts)
helm repo add student-portal https://charts.example.com

# Create secrets (override values)
kubectl create secret generic student-portal-secrets \
  --from-literal=DB_PASSWORD="<your-db-password>" \
  --from-literal=JWT_SECRET="<your-jwt-secret>" \
  -n student-portal

# Deploy using Helm
helm install student-portal ./helm-charts/student-portal \
  --namespace student-portal \
  --values helm-charts/student-portal/values.yaml \
  --set backend.image.registry="<your-ecr-registry>" \
  --set backend.image.tag="latest" \
  --set backend.env.dbHost="<terraform-rds-endpoint>" \
  --set frontend.image.registry="<your-ecr-registry>" \
  --set frontend.image.tag="latest" \
  --wait --timeout 10m
```

### Step 4: Setup Ingress and TLS

```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Create ClusterIssuer for Let's Encrypt
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Step 5: Configure DNS

```bash
# Get LoadBalancer public IP
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller

# Create Route53 record
LOAD_BALANCER_IP=$(kubectl get svc -n ingress-nginx \
  nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_HOSTED_ZONE_ID> \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"student-portal.giize.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"${LOAD_BALANCER_IP}\"}]
      }
    }]
  }"
```

## Post-Deployment Verification

### Step 1: Verify Cluster Health

```bash
# Check nodes
kubectl get nodes -o wide

# Check all pods
kubectl get pods --all-namespaces

# Check services
kubectl get svc --all-namespaces

# Check deployments
kubectl get deployments --all-namespaces
```

### Step 2: Verify Application Endpoints

```bash
# Backend health check
curl https://student-portal.giize.com/api/health

# Frontend reachability
curl https://student-portal.giize.com/

# Verify database connectivity
kubectl logs -n student-portal deployment/student-portal-backend | grep -i database
```

### Step 3: Verify Monitoring

```bash
# Check Prometheus scraping
kubectl get servicemonitor -n student-portal

# Verify metrics collection
kubectl exec -n monitoring prometheus-0 -- \
  curl -s http://localhost:9090/api/v1/status/targets
```

### Step 4: Run Integration Tests

```bash
# Run smoke tests
kubectl run smoke-test \
  --image=curlimages/curl \
  --restart=Never \
  --rm -i --stdin \
  -- sh -c 'curl https://student-portal.giize.com/api/health'

# Check logs
kubectl logs -n student-portal -l app=student-portal-backend --tail=100
```

## Scaling and Performance Tuning

### Horizontal Scaling

```bash
# Check HPA status
kubectl get hpa -n student-portal

# Manually scale deployment
kubectl scale deployment student-portal-backend \
  -n student-portal \
  --replicas=5

# Update HPA limits
kubectl patch hpa student-portal-backend-hpa \
  -n student-portal \
  --type json \
  -p '[{"op": "replace", "path": "/spec/maxReplicas", "value": 20}]'
```

### Vertical Scaling

```bash
# Update resource requests/limits
helm upgrade student-portal ./helm-charts/student-portal \
  --namespace student-portal \
  --set backend.resources.requests.cpu=500m \
  --set backend.resources.requests.memory=1Gi \
  --set backend.resources.limits.cpu=1000m \
  --set backend.resources.limits.memory=2Gi
```

### RDS Performance Tuning

```bash
# Check RDS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=student-portal-production-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Enable Performance Insights
aws rds modify-db-instance \
  --db-instance-identifier student-portal-production-db \
  --enable-performance-insights \
  --performance-insights-retention-period 7
```

## Disaster Recovery

### Backup Strategy

```bash
# RDS Automated Backups (configured via Terraform)
# Manual snapshot creation
aws rds create-db-snapshot \
  --db-instance-identifier student-portal-production-db \
  --db-snapshot-identifier student-portal-backup-$(date +%s)

# Backup Kubernetes state
kubectl create namespace backup
etcdctl --endpoints=$ETCD_ENDPOINT snapshot save $(date +%s).db
```

### Restore Procedure

```bash
# Restore RDS from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier student-portal-restored \
  --db-snapshot-identifier student-portal-backup-<timestamp>

# Restore Kubernetes cluster
eksctl delete cluster --name student-portal-production
# Re-apply Terraform
terraform apply -var-file=terraform.tfvars
```

### Failover Strategy

```bash
# Multi-AZ failover is automatic for RDS

# For EKS, monitor ASG health
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names student-portal-production-node-group

# Force failover if needed
kubernetes_node=$(kubectl get nodes | awk 'NR==2 {print $1}')
kubectl drain $kubernetes_node --ignore-daemonsets --delete-emptydir-data
```

## Troubleshooting

### Pod Issues

```bash
# Check pod status
kubectl describe pod <pod-name> -n student-portal

# View pod logs
kubectl logs <pod-name> -n student-portal

# Check events
kubectl get events -n student-portal --sort-by='.lastTimestamp'

# Debug with exec
kubectl exec -it <pod-name> -n student-portal -- /bin/sh
```

### Database Issues

```bash
# Check RDS instance
aws rds describe-db-instances \
  --db-instance-identifier student-portal-production-db

# Check security group
aws ec2 describe-security-groups \
  --group-ids <RDS-SG-ID>

# Test connectivity
kubectl run mysql-test --image=mysql:8.0 -it --rm \
  -- mysql -h<RDS-ENDPOINT> -u admin -p <DATABASE>
```

### Ingress Issues

```bash
# Check ingress status
kubectl get ingress -n student-portal
kubectl describe ingress -n student-portal

# Check cert-manager
kubectl get certificate -n student-portal
kubectl describe certificate <cert-name> -n student-portal

# Verify NGINX controller
kubectl logs -n ingress-nginx -l app=nginx-ingress
```

### Performance Issues

```bash
# Check node capacity
kubectl top nodes
kubectl describe nodes

# Check pod resource usage
kubectl top pods -n student-portal

# Check HPA status
kubectl describe hpa -n student-portal

# View metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/student-portal/pods
```

## Maintenance Windows

### Planned Updates

```bash
# Scale down before maintenance
kubectl scale deployment student-portal-backend -n student-portal --replicas=0
kubectl scale deployment student-portal-frontend -n student-portal --replicas=0

# Perform maintenance
# ...

# Scale back up
kubectl scale deployment student-portal-backend -n student-portal --replicas=3
kubectl scale deployment student-portal-frontend -n student-portal --replicas=2
```

### RDS Maintenance

```bash
# Check maintenance window
aws rds describe-db-instances \
  --db-instance-identifier student-portal-production-db \
  --query 'DBInstances[0].[PreferredMaintenanceWindow]'

# Modify maintenance window
aws rds modify-db-instance \
  --db-instance-identifier student-portal-production-db \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --apply-immediately
```

---

**Last Updated**: March 30, 2026
**Tested Production Deploy Date**: March 2026
**Recommended Review**: Quarterly
