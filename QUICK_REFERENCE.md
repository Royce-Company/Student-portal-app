# Quick Reference Guide

## Deployments

### Deploy to Production
```bash
git push origin main
# Automatically builds, tests, and deploys via GitHub Actions
```

### Deploy to Staging
```bash
git push origin develop
# Automatically deploys to staging environment
```

### Manual Helm Deployment
```bash
helm upgrade --install student-portal ./helm-charts/student-portal \
  --namespace student-portal \
  --values helm-charts/student-portal/values.yaml
```

### Rollback Deployment
```bash
helm rollback student-portal -n student-portal
kubectl rollout undo deployment/student-portal-backend -n student-portal
```

## Cluster Access

### Configure kubectl
```bash
aws eks update-kubeconfig --name student-portal-production --region us-east-2
kubectl cluster-info
```

### Port Forwarding
```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Backend
kubectl port-forward -n student-portal svc/student-portal-backend 5000:5000
```

## Scaling

### Auto-scaling Status
```bash
kubectl get hpa -n student-portal
kubectl describe hpa student-portal-backend-hpa -n student-portal
```

### Manual Pod Scaling
```bash
kubectl scale deployment student-portal-backend -n student-portal --replicas=5
```

### Node Scaling
```bash
# Check node group
aws eks describe-nodegroup --cluster-name student-portal-production \
  --nodegroup-name student-portal-production-node-group

# Update desired capacity
aws eks update-nodegroup-config --cluster-name student-portal-production \
  --nodegroup-name student-portal-production-node-group \
  --scaling-config desiredSize=4
```

## Logs and Monitoring

### View Pod Logs
```bash
# Real-time logs
kubectl logs -f deployment/student-portal-backend -n student-portal

# Specific pod
kubectl logs <pod-name> -n student-portal

# All containers
kubectl logs <pod-name> --all-containers -n student-portal
```

### Check Pod Status
```bash
kubectl get pods -n student-portal
kubectl describe pod <pod-name> -n student-portal
kubectl get events -n student-portal
```

### Database Logs
```bash
aws rds describe-db-log-files --db-instance-identifier student-portal-production-db
```

## Incidents and Troubleshooting

### Restart Pods
```bash
kubectl rollout restart deployment/student-portal-backend -n student-portal
kubectl rollout restart deployment/student-portal-frontend -n student-portal
```

### Check Ingress
```bash
kubectl get ingress -n student-portal
kubectl describe ingress student-portal -n student-portal
```

### Verify Connectivity
```bash
# Test backend
curl https://student-portal.giize.com/api/health

# Direct pod
kubectl exec -it <pod-name> -n student-portal -- curl localhost:5000/health
```

### Check Resource Usage
```bash
kubectl top nodes
kubectl top pods -n student-portal
```

## Database Management

### Backup RDS
```bash
aws rds create-db-snapshot \
  --db-instance-identifier student-portal-production-db \
  --db-snapshot-identifier student-portal-$(date +%s)
```

### Check RDS Status
```bash
aws rds describe-db-instances --db-instance-identifier student-portal-production-db
```

### Database Metrics
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=student-portal-production-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Secrets Management

### View Secrets
```bash
# List secrets
kubectl get secrets -n student-portal

# View specific secret
kubectl get secret student-portal-secrets -n student-portal -o yaml

# Decode value
kubectl get secret student-portal-secrets -n student-portal \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

### Update Secrets
```bash
kubectl create secret generic student-portal-secrets \
  --from-literal=DB_PASSWORD="newpassword" \
  -n student-portal \
  --dry-run=client -o yaml | kubectl apply -f -
```

### AWS Secrets Manager
```bash
# List secrets
aws secretsmanager list-secrets

# Get secret
aws secretsmanager get-secret-value --secret-id student-portal/db-password

# Update secret
aws secretsmanager update-secret --secret-id student-portal/db-password \
  --secret-string "newpassword"
```

## Terraform Commands

### Plan Changes
```bash
cd terraform/environments/production
terraform plan -var-file=terraform.tfvars -out=tfplan
```

### Apply Changes
```bash
terraform apply tfplan
```

### Destroy Infrastructure
```bash
# CAUTION: This will destroy all resources
terraform destroy -var-file=terraform.tfvars
```

### State Management
```bash
# List state
terraform state list

# Show resource
terraform state show aws_eks_cluster.main

# Backup state
terraform state pull > terraform.tfstate.backup
```

## GitHub Actions

### View Workflows
```bash
gh workflow list
gh run list --workflow=docker-build.yml
```

### Manually Trigger Workflow
```bash
gh workflow run deploy-eks.yml
```

### View Workflow Output
```bash
gh run view <run-id> --log
```

## Cost Monitoring

### View AWS Costs
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-03-01,End=2024-03-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

### Set Budget Alert
```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file:///tmp/budget.json
```

## Emergency Procedures

### Pod Stuck in Crash Loop
```bash
# Check logs
kubectl logs <pod-name> -n student-portal --previous

# Describe pod
kubectl describe pod <pod-name> -n student-portal

# Delete and recreate
kubectl delete pod <pod-name> -n student-portal
```

### Database Connection Failed
```bash
# Check security groups
aws ec2 describe-security-groups --group-ids <SG-ID>

# Test RDS connectivity
kubectl run mysql-cli --image=mysql:8.0 -it --rm \
  -- mysql -h<RDS-ENDPOINT> -u admin -p

# Check RDS status
aws rds describe-db-instances --db-instance-identifier student-portal-production-db
```

### Stuck Terraform Lock
```bash
# List DynamoDB locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### OutOfMemory Error
```bash
# Check node resources
kubectl describe nodes

# Increase pod memory limit
kubectl set resources deployment student-portal-backend \
  -n student-portal --limits memory=2Gi
```

## Common Commands Cheat Sheet

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes
kubectl top nodes

# Namespace operations
kubectl create namespace <name>
kubectl get namespaces
kubectl delete namespace <name>

# Pod operations
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Deployment operations
kubectl get deployments -n <namespace>
kubectl scale deployment <name> -n <namespace> --replicas=<number>
kubectl rollout status deployment/<name> -n <namespace>
kubectl rollout restart deployment/<name> -n <namespace>

# Service operations
kubectl get svc -n <namespace>
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>

# Resource quotas
kubectl describe resourcequota -n <namespace>

# Events
kubectl get events -n <namespace>
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

## Emergency Contacts

- **On-call DevOps**: [Slack Channel]
- **AWS Support**: [Support Case URL]
- **Database Admin**: [Contact Info]
- **Dashboard**: [Grafana URL]

## Further Reading

- [Kubernetes Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Command Reference](https://helm.sh/docs/helm/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Terraform CLI](https://www.terraform.io/cli/commands)

---

**Last Updated**: March 30, 2026  
**Maintained By**: DevOps Team
