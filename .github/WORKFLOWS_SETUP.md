# GitHub Actions CI/CD Setup Guide

## Overview

This project uses GitHub Actions for automated CI/CD workflows including:
- Docker image building and pushing to Amazon ECR
- Kubernetes deployments to EKS
- Infrastructure management with Terraform
- Code quality and security scanning
- Integration testing

## Prerequisites

1. **GitHub Repository**: This code must be on GitHub
2. **AWS Account**: With appropriate IAM permissions
3. **OpenID Connect (OIDC)**: Configured for GitHub Actions

## Setup Instructions

### Step 1: Configure AWS IAM for GitHub Actions

Create an IAM Identity Provider for GitHub:

```bash
# Create the OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create IAM role for GitHub Actions
GITHUB_REPO="yourusername/your-repo"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

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

aws iam create-role \
  --role-name github-actions-student-portal \
  --assume-role-policy-document file:///tmp/trust-policy.json
```

### Step 2: Create IAM Policies

```bash
# Create policy for ECS/ECR access
cat > /tmp/ecr-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchCheckLayerAvailability",
        "ecr:DescribeImages",
        "ecr:ListImages"
      ],
      "Resource": "arn:aws:ecr:*:${ACCOUNT_ID}:repository/student-portal/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name github-actions-student-portal \
  --policy-name github-actions-ecr \
  --policy-document file:///tmp/ecr-policy.json

# Create policy for EKS access
cat > /tmp/eks-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:AccessKubernetesApi"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name github-actions-student-portal \
  --policy-name github-actions-eks \
  --policy-document file:///tmp/eks-policy.json

# Create policy for Terraform
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

### Step 3: Add GitHub Repository Secrets

1. Go to repository Settings > Secrets and variables > Actions
2. Add the following secrets:

```
AWS_ROLE_TO_ASSUME=arn:aws:iam::<ACCOUNT_ID>:role/github-actions-student-portal
DB_PASSWORD=<your-secure-password>
JWT_SECRET=<your-jwt-secret>
SLACK_WEBHOOK=<your-slack-webhook-url> (optional)
```

### Step 4: Configure kubeconfig for EKS

The EKS cluster needs to be configured to trust the GitHub Actions IAM role:

```bash
# Add the GitHub Actions role to the aws-auth ConfigMap
kubectl edit configmap aws-auth -n kube-system

# Add this mapping under mapRoles:
- groups:
  - system:masters
  rolearn: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-student-portal
  username: github-actions
```

## Workflows

### 1. Docker Build Workflow (`docker-build.yml`)

**Trigger**: Push to main/develop branches with changes to backend or frontend

**Steps**:
- Build backend Docker image and push to ECR
- Build frontend Docker image and push to ECR
- Scan images for vulnerabilities using ECR
- Tag images with commit SHA, branch, and date

**Outputs**:
- ECR repositories: `<account>.dkr.ecr.us-east-2.amazonaws.com/student-portal/backend:<tag>`
- ECR repositories: `<account>.dkr.ecr.us-east-2.amazonaws.com/student-portal/frontend:<tag>`

### 2. Deploy to EKS Workflow (`deploy-eks.yml`)

**Trigger**: After Docker build completes

**Steps**:
- Determine target environment (production for main branch, staging for develop)
- Update kubeconfig for EKS cluster
- Create namespace if needed
- Store database and JWT secrets in Kubernetes
- Deploy using Helm charts
- Verify rollout status
- Run smoke tests
- Send Slack notification

**Environments**:
- **Production**: Triggered on main branch
- **Staging**: Triggered on develop branch

### 3. Terraform CI/CD Workflow (`terraform.yml`)

**Trigger**: Push to main branch with Terraform changes

**Steps**:
- Validate Terraform formatting
- Initialize Terraform
- Validate Terraform configuration
- Create Terraform plan
- Post plan results to PR (for pull requests)
- Apply Terraform (on main branch pushes)
- Store outputs in artifacts

### 4. Code Quality Workflow (`code-quality.yml`)

**Trigger**: Every push and PR to main/develop branches

**Steps**:
- Trivy vulnerability scanning
- ESLint for backend code
- NPM audit for dependencies
- Dockerfile linting
- HTML validation for frontend
- Generate SBOM (Software Bill of Materials)

### 5. Integration Tests Workflow (`integration-tests.yml`)

**Trigger**: Every push and PR to main/develop branches

**Steps**:
- Spin up MySQL test database
- Install dependencies
- Run backend tests
- Start backend server
- Run API endpoint tests
- Run frontend tests
- Upload test results

## Common Issues and Troubleshooting

### Issue: `Unable to assume role`

**Solution**: 
1. Verify OIDC provider thumbprint
2. Check trust policy condition
3. Ensure GitHub repository name is correct

```bash
# Verify OIDC provider
aws iam list-open-id-connect-providers

# Get thumbprint
curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq '.jwks_uri'
```

### Issue: `ECR authentication failed`

**Solution**:
1. Verify AWS credentials are configured correctly
2. Check IAM policy permissions
3. Ensure ECR repository exists

```bash
# List ECR repositories
aws ecr describe-repositories --repository-names student-portal/backend student-portal/frontend

# Get ECR auth token
aws ecr get-authorization-token
```

### Issue: `Deployment fails with `ImagePullBackOff``

**Solution**:
1. Verify image tag matches in Helm values
2. Ensure image exists in ECR
3. Check Kubernetes imagePullSecrets

```bash
# Check pod events
kubectl describe pod <pod-name> -n student-portal

# List images in ECR
aws ecr list-images --repository-name student-portal/backend
```

### Issue: `Terraform state lock timeout`

**Solution**:
1. Check for stuck Terraform processes
2. Unlock state manually (use with caution)

```bash
# List DynamoDB items
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (only if absolutely necessary)
terraform force-unlock <LOCK_ID>
```

## Manual Workflow Triggers

You can manually trigger workflows from the Actions tab:

```bash
# Using GitHub CLI
gh workflow run docker-build.yml
gh workflow run deploy-eks.yml
gh workflow run terraform.yml
```

## Monitoring and Logs

### View Workflow Logs

1. Go to Actions tab in GitHub
2. Select workflow
3. Click on run to see detailed logs

### Download Artifacts

```bash
# Using GitHub CLI
gh run download <run-id> --dir ./artifacts

# Example: Get Terraform outputs
gh run download -n terraform-outputs
```

## Best Practices

1. **Secrets Management**:
   - Rotate secrets regularly
   - Use AWS Secrets Manager integration
   - Never commit secrets to repository

2. **Branch Protection**:
   - Require status checks to pass before merging
   - Require code reviews
   - Dismiss stale reviews when new commits pushed

3. **Environment Separation**:
   - Use separate IAM roles per environment
   - Different S3 backends for state files
   - Namespace isolation in Kubernetes

4. **Cost Optimization**:
   - Set workflow timeout limits
   - Use self-hosted runners for heavy workloads
   - Cache Docker layers in ECR

5. **Audit and Logging**:
   - Enable CloudTrail for AWS API calls
   - Keep GitHub Actions logs for audit
   - Monitor ECR image scans

## Integration with External Tools

### Slack Notifications

Update webhook URL in repository secrets and modify workflows to send status:

```yaml
- uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Email Notifications

Enable in GitHub repository settings under "Security & analysis"

### GitHub Status Checks

Workflows automatically create status checks. View in branch protection rules.

## Performance Optimization

### Docker Layer Caching

```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Concurrent Workflows

Specify multiple jobs to run in parallel (already configured in workflows)

### Self-Hosted Runners

For better performance:

```bash
# Add self-hosted runner label
runs-on: [self-hosted, linux, x64]
```

## Next Steps

1. Commit all workflow files to repository
2. Create AWS OIDC provider and IAM role
3. Add GitHub secrets
4. Update kubeconfig trust
5. Push changes to main branch to trigger workflows
6. Monitor first deployment in Actions tab

---

**Last Updated**: March 30, 2026
**supported GitHub Actions Version**: v4.x
**Tested Environments**: Production, Staging
