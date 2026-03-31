# Getting Started: Production Deployment Guide

Complete this guide to deploy the Student Portal application to AWS EKS in production. Estimated time: 2-4 hours (including waiting for resource creation).

## Prerequisites Setup (30 minutes)

### 1. Install Required Tools

```bash
# On Windows (using PowerShell or Chocolatey)
choco install aws-cli kubectl helm terraform git -y

# Or manually:
# - AWS CLI: https://aws.amazon.com/cli/
# - kubectl: https://kubernetes.io/docs/tasks/tools/
# - Helm: https://helm.sh/docs/intro/install/
# - Terraform: https://www.terraform.io/downloads.html
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI with your credentials
aws configure

# Enter:
# AWS Access Key ID: [your-key]
# AWS Secret Access Key: [your-secret]
# Default region: us-east-1
# Default output format: json

# Verify connectivity
aws sts get-caller-identity
# Should return your account ID, user ARN, etc.
```

### 3. Clone Repository

```bash
git clone https://github.com/your-org/student-portal.git
cd student-portal
```

### 4. Create S3 Bucket for Terraform State

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="student-portal-terraform-state-$ACCOUNT_ID"

# Create bucket
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 5. Create DynamoDB Lock Table

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 6. Setup GitHub Actions OIDC (for CI/CD)

```bash
# Set your GitHub repository details
GITHUB_ORG="your-github-org"
GITHUB_REPO="student-portal"

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create IAM role for GitHub Actions
POLICY_JSON='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:GITHUB_ORG/GITHUB_REPO:*"
        }
      }
    }
  ]
}'

# Replace placeholders
POLICY_JSON=${POLICY_JSON//ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)}
POLICY_JSON=${POLICY_JSON//GITHUB_ORG/$GITHUB_ORG}
POLICY_JSON=${POLICY_JSON//GITHUB_REPO/$GITHUB_REPO}

# Create role
aws iam create-role \
  --role-name github-actions-role \
  --assume-role-policy-document "$POLICY_JSON"

# Attach permissions policy
aws iam put-role-policy \
  --role-name github-actions-role \
  --policy-name github-actions-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole"
        ],
        "Resource": "arn:aws:iam::ACCOUNT_ID:role/github-actions-role"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource": "arn:aws:ecr:us-east-1:ACCOUNT_ID:repository/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "terraform:*"
        ],
        "Resource": "*"
      }
    ]
  }'
```

### 7. Add GitHub Repository Secrets

Go to GitHub Settings → Secrets and add:

```
AWS_ROLE_TO_ASSUME: arn:aws:iam::ACCOUNT_ID:role/github-actions-role
AWS_REGION: us-east-1
RDS_MASTER_PASSWORD: YourStrongPassword123!@#
```

---

## Infrastructure Deployment (30-60 minutes)

### Step 1: Initialize Terraform

```bash
cd terraform

# Initialize with S3 backend
terraform init \
  -backend-config="bucket=$BUCKET_NAME" \
  -backend-config="key=production/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="encrypt=true"
```

### Step 2: Review & Apply Terraform

```bash
# Validate configuration
terraform validate

# Plan changes
terraform plan -out=tfplan -var-file=environments/production/terraform.tfvars

# Review the plan carefully (20-30 minutes to create)

# Apply
terraform apply tfplan
```

### Step 3: Save Outputs

```bash
# Save important information
terraform output -json > outputs.json

# Extract key values
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
ECR_BACKEND=$(terraform output -raw ecr_backend_url)
ECR_FRONTEND=$(terraform output -raw ecr_frontend_url)

echo "EKS Cluster: $EKS_CLUSTER_NAME"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "ECR Backend: $ECR_BACKEND"
echo "ECR Frontend: $ECR_FRONTEND"

# Save to file for later reference
cat > deployment-info.sh <<EOF
export EKS_CLUSTER_NAME=$EKS_CLUSTER_NAME
export RDS_ENDPOINT=$RDS_ENDPOINT
export ECR_BACKEND=$ECR_BACKEND
export ECR_FRONTEND=$ECR_FRONTEND
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EOF

chmod +x deployment-info.sh
```

### Step 4: Update Kubeconfig

```bash
# Update kubectl configuration
aws eks update-kubeconfig \
  --name $EKS_CLUSTER_NAME \
  --region us-east-1

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

---

## Application Deployment (45 minutes)

### Step 1: Create Namespace & RBAC

```bash
# Apply namespace configuration
kubectl apply -f student-portal/namespace.yaml

# Verify
kubectl get namespace student-portal
kubectl get sa -n student-portal
```

### Step 2: Create RDS Secrets

```bash
# Get RDS credentials from Terraform outputs
RDS_HOST=$(terraform output -raw rds_endpoint)
RDS_USER="admin"
RDS_PASSWORD=$(terraform output -raw rds_password)
RDS_DB="student_portal"

# Create Kubernetes secret
kubectl create secret generic student-portal-db \
  --from-literal=DB_HOST=$RDS_HOST \
  --from-literal=DB_USER=$RDS_USER \
  --from-literal=DB_PASSWORD=$RDS_PASSWORD \
  --from-literal=DB_NAME=$RDS_DB \
  -n student-portal

# Verify
kubectl get secrets -n student-portal
```

### Step 3: Build & Push Container Images

#### Option A: Via GitHub Actions (Recommended)

```bash
# Push code to main branch (triggers automatic build)
git push origin main

# Check GitHub Actions tab to monitor build progress
# Once complete, images will be in ECR
```

#### Option B: Manual Build

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_BACKEND

# Build backend image
docker build -t $ECR_BACKEND:latest backend/
docker push $ECR_BACKEND:latest

# Build frontend image
docker build -t $ECR_FRONTEND:latest frontend/
docker push $ECR_FRONTEND:latest
```

### Step 4: Update Helm Values

Edit `helm-charts/student-portal/values.yaml`:

```yaml
# Update image URLs
backend:
  image: $ECR_BACKEND:latest

frontend:
  image: $ECR_FRONTEND:latest
```

### Step 5: Deploy with Helm

```bash
# Deploy the application
helm install student-portal helm-charts/student-portal \
  --namespace student-portal \
  --values helm-charts/student-portal/values.yaml

# Wait for rollout to complete
kubectl rollout status deployment/backend -n student-portal
kubectl rollout status deployment/frontend -n student-portal

# Verify pods are running
kubectl get pods -n student-portal
```

### Step 6: Verify Deployment

```bash
# Check pod status
kubectl get pods -n student-portal
# Expected: All pods Running (3 backend, 2 frontend)

# Check logs
kubectl logs -n student-portal -l app=backend --tail=50
kubectl logs -n student-portal -l app=frontend --tail=50

# Test connectivity
kubectl exec -it <backend-pod> -n student-portal -- curl http://localhost:5000/health
# Expected: HTTP 200 response
```

---

## Ingress & DNS Setup (15 minutes)

### Step 1: Install NGINX Ingress Controller

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Step 2: Get Load Balancer DNS

```bash
# Wait for external IP (may take 1-2 minutes)
kubectl get svc -n ingress-nginx --watch

# Once available, save the external DNS
INGRESS_DNS=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Ingress DNS: $INGRESS_DNS"
```

### Step 3: Create Ingress Resource

```bash
cat > student-portal/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: student-portal-ingress
  namespace: student-portal
spec:
  ingressClassName: nginx
  rules:
  - host: app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 5000
EOF

# Apply ingress
kubectl apply -f student-portal/ingress.yaml
```

### Step 4: Update DNS Records

In Route53 (or your DNS provider):

```
Record Type: CNAME
Name: app.yourdomain.com
Value: <INGRESS_DNS>
TTL: 300
```

### Step 5: Verify Access

```bash
# Test DNS resolution
nslookup app.yourdomain.com

# Test HTTP access (should redirect to HTTPS eventually)
curl http://app.yourdomain.com

# Test HTTPS (once certificate is ready)
curl https://app.yourdomain.com
```

---

## Monitoring Setup (30 minutes)

### Step 1: Install Prometheus Stack

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus, Grafana, AlertManager
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace prometheus \
  --create-namespace
```

### Step 2: Access Grafana

```bash
# Port forward to local machine
kubectl port-forward svc/prometheus-grafana 3000:80 -n prometheus &

# Open browser: http://localhost:3000
# Default credentials: admin/prom-operator

# Change password immediately!
```

### Step 3: Import Dashboards

In Grafana:

1. Go to Dashboards → Import
2. Search for ID: **6417** (Kubernetes Cluster Monitoring)
3. Import
4. Repeat for ID: **8588** (Pod Monitoring)

### Step 4: Setup Alerts

See [MONITORING_SETUP.md](MONITORING_SETUP.md) for detailed alert configuration.

---

## Post-Deployment Validation

### Smoke Tests

```bash
#!/bin/bash

echo "=== Production Deployment Validation ==="

# Test frontend
echo "1. Testing Frontend..."
curl -s https://app.yourdomain.com | grep -q "<html>" && echo "✓ Frontend accessible" || echo "✗ Frontend error"

# Test backend
echo "2. Testing Backend..."
curl -s https://app.yourdomain.com/api/health | grep -q "healthy" && echo "✓ Backend healthy" || echo "✗ Backend error"

# Test ingress
echo "3. Testing Ingress..."
kubectl get ingress -n student-portal && echo "✓ Ingress configured" || echo "✗ Ingress error"

# Test pods
echo "4. Checking Pod Status..."
kubectl get pods -n student-portal | grep -i running && echo "✓ Pods running" || echo "✗ Pod error"

# Test database connection
echo "5. Testing Database..."
kubectl exec -it $(kubectl get pods -n student-portal -l app=backend -o name | head -1) -n student-portal -- \
  curl -s http://localhost:5000/health | grep -q "healthy" && echo "✓ Database connected" || echo "✗ Database error"

echo "=== Validation Complete ==="
```

Save as `test-deployment.sh` and run:

```bash
chmod +x test-deployment.sh
./test-deployment.sh
```

---

## Troubleshooting

### Pods not starting?

```bash
# Check pod status
kubectl describe pod <pod-name> -n student-portal

# Check logs
kubectl logs <pod-name> -n student-portal

# Check events
kubectl get events -n student-portal --sort-by='.lastTimestamp'
```

### Application not accessible?

```bash
# Check ingress
kubectl get ingress -n student-portal

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app=ingress-nginx --tail=50

# Test DNS resolution
nslookup app.yourdomain.com

# Test ingress controller endpoint
kubectl exec -it $(kubectl get pods -n ingress-nginx -o name | head -1) -n ingress-nginx -- \
  curl -H "Host: app.yourdomain.com" http://localhost
```

### High memory/CPU usage?

```bash
# Check resource usage
kubectl top pods -n student-portal
kubectl top nodes

# Check HPA status
kubectl get hpa -n student-portal

# If scaling not working, check metrics server
kubectl get deployment metrics-server -n kube-system
```

For more detailed troubleshooting, see [QUICK_REFERENCE.md](QUICK_REFERENCE.md).

---

## Next Steps

1. **Setup Backups**: Follow [BACKUP_AND_DISASTER_RECOVERY.md](BACKUP_AND_DISASTER_RECOVERY.md)
2. **Load Testing**: Run performance baseline tests (see [PRODUCTION_READINESS_CHECKLIST.md](PRODUCTION_READINESS_CHECKLIST.md))
3. **Team Documentation**: Share [QUICK_REFERENCE.md](QUICK_REFERENCE.md) with on-call team
4. **Monitoring**: Configure alerts and dashboards in Grafana
5. **Scheduled Reviews**: Weekly health checks, monthly capacity planning

---

## Support & Escalation

- **Technical Issues**: Check QUICK_REFERENCE.md troubleshooting section
- **Infrastructure Problems**: Contact Cloud Platform team
- **Application Bugs**: File GitHub issue with reproduction steps
- **On-Call Escalation**: See runbook for contact info

---

**Document Version**: 1.0  
**Last Updated**: [Date]  
**Estimated Time to Deployment**: 2-4 hours  
**Estimated Cost**: $200-500/month (production + staging)
