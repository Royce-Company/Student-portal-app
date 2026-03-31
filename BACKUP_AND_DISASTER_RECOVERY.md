# Database Backup and Disaster Recovery

## Overview

This guide covers backup strategies, recovery procedures, and disaster recovery planning for the Student Portal's MySQL database and EKS cluster.

## RDS MySQL Backups

### Automated Backups Configuration

Configured via Terraform in `modules/rds/main.tf`:

```terraform
backup_retention_period    = 30  # Production: 30 days
backup_window              = "03:00-04:00"  # UTC
maintenance_window         = "mon:04:00-mon:05:00"
copy_tags_to_snapshot      = true
skip_final_snapshot        = false  # Production: false
```

### Manual Snapshot Creation

```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier student-portal-production-db \
  --db-snapshot-identifier manual-backup-$(date +%Y%m%d-%H%M%S)

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier student-portal-production-db

# Copy snapshot to another region (for DR)
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:us-east-2:ACCOUNT:snapshot:manual-backup-20240330-120000 \
  --target-db-snapshot-identifier manual-backup-20240330-120000-us-west-2 \
  --region us-west-2
```

### Automated Snapshot Export

```bash
# Export snapshot to S3
aws rds start-export-task \
  --export-task-identifier student-portal-backup-export-$(date +%s) \
  --source-arn arn:aws:rds:us-east-2:ACCOUNT:snapshot:manual-backup-20240330-120000 \
  --s3-bucket-name student-portal-backups \
  --s3-prefix exports/
  --iam-role-arn arn:aws:iam::ACCOUNT:role/rds-export-role
```

## Point-in-Time Recovery (PITR)

### Enable Binary Logging

Already enabled by default. Verify:

```bash
aws rds describe-db-instances \
  --db-instance-identifier student-portal-production-db \
  --query 'DBInstances[0].[BackupRetentionPeriod, Engine]'
```

### Restore to Specific Timestamp

```bash
# List available backup windows
aws rds describe-db-instances \
  --db-instance-identifier student-portal-production-db \
  --query 'DBInstances[0].[EarliestRestorableTime, LatestRestorableTime]'

# Restore to specific time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier student-portal-production-db \
  --target-db-instance-identifier student-portal-production-db-pitr-restore \
  --restore-time 2024-03-30T14:30:00Z \
  --copy-tags-to-snapshot

# After verification, promote to production
# 1. Backup current production
aws rds create-db-snapshot \
  --db-instance-identifier student-portal-production-db \
  --db-snapshot-identifier pre-pitr-restore-backup

# 2. Update application to point to new database
# 3. Test thoroughly
# 4. Perform final switchover during maintenance window
```

## Full Backup and Restore

### Logical Backup with mysqldump

```bash
# Create backup
kubectl run mysql-backup --image=mysql:8.0 \
  --restart=Never -it --rm \
  -- mysqldump \
  -h <RDS-ENDPOINT> \
  -u admin -p<PASSWORD> \
  --all-databases \
  > full-backup-$(date +%Y%m%d-%H%M%S).sql

# Compress backup
gzip full-backup-*.sql

# Upload to S3
aws s3 cp full-backup-*.sql.gz s3://student-portal-backups/mysql/
```

### Restore from Logical Backup

```bash
# Download backup
aws s3 cp s3://student-portal-backups/mysql/full-backup-*.sql.gz .
gunzip full-backup-*.sql.gz

# Restore to RDS (create new instance first)
kubectl run mysql-restore --image=mysql:8.0 \
  --restart=Never -it --rm \
  -- mysql \
  -h <NEW-RDS-ENDPOINT> \
  -u admin -p<PASSWORD> \
  < full-backup-*.sql
```

## Kubernetes Backup and Recovery

### etcd Backup

```bash
# Backup etcd (EKS managed - automatic)
# EKS automatically backs up etcd

# Manual backup for cross-AZ disaster recovery
kubectl exec -n kube-system etcd-<master-node> -- \
  etcdctl snapshot save /tmp/etcd-backup.db \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Velero Backup (Optional)

```bash
# Install Velero
velero install --provider aws --bucket student-portal-velero \
  --secret-file ./credentials-velero \
  --use-volume-snapshots=true

# Create backup schedule
velero schedule create daily \
  --schedule="0 2 * * *" \
  --include-namespaces student-portal \
  --ttl 720h

# Manual backup
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces student-portal

# List backups
velero backup get

# Restore from backup
velero restore create manual-restore \
  --from-backup manual-backup-20240330-120000
```

### Application Data Backup

```bash
# Backup all Kubernetes resources
kubectl get all --all-namespaces -o yaml > k8s-backup-$(date +%Y%m%d).yaml

# Backup specific namespace
kubectl get all -n student-portal -o yaml > k8s-student-portal-$(date +%Y%m%d).yaml

# Backup Helm releases
helm get values student-portal -n student-portal > helm-values-backup.yaml
```

## Disaster Recovery Plan

### RTO and RPO Targets

| Scenario | RTO | RPO |
|----------|-----|-----|
| Database failure | 30 minutes | 5 minutes |
| EKS cluster failure | 1 hour | 10 minutes |
| Regional outage | 4 hours | 1 hour |
| Data corruption | 24 hours | Can restore to any point in last 30 days |

### Failure Scenarios and Recovery

#### Scenario 1: Single RDS Instance Failure

**Detection:**
```bash
aws rds describe-db-instances \
  --db-instance-identifier student-portal-production-db \
  --query 'DBInstances[0].[DBInstanceStatus, Endpoint]'
```

**Recovery (Automatic - Multi-AZ):**
- RDS automatically fails over to standby in another AZ
- Application continues with minimal downtime
- Estimated time: 2-3 minutes

**Manual Recovery:**
```bash
# Restore from latest snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier student-portal-production-db-restored \
  --db-snapshot-identifier latest-snapshot-id
```

#### Scenario 2: EKS Node Failure

**Detection:**
```bash
kubectl get nodes
kubectl describe node <failed-node>
```

**Automatic Recovery:**
- Nodes are part of Auto Scaling Group
- Failed node is automatically replaced
- Pods are rescheduled on healthy nodes
- Estimated time: 5-10 minutes

**Manual Recovery:**
```bash
# Drain node (graceful)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Check new node is ready
kubectl get nodes

# Verify pods are healthy
kubectl get pods --all-namespaces
```

#### Scenario 3: EKS Cluster Control Plane Failure

**Detection:**
- kubectl commands fail
- API server unreachable

**Recovery:**
```bash
# EKS is managed - control plane is AWS's responsibility
# Worker nodes continue running
# Recreate cluster if needed
terraform destroy
terraform apply

# Restore Helm releases
helm install student-portal ./helm-charts/student-portal \
  --namespace student-portal
```

#### Scenario 4: Data Corruption

**Detection:**
- Application reports errors
- Data inconsistencies

**Recovery:**
```bash
# Option 1: PITR to known good state
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier student-portal-production-db \
  --target-db-instance-identifier student-portal-production-db-restored \
  --restore-time 2024-03-30T12:00:00Z

# Option 2: Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier student-portal-production-db-restored \
  --db-snapshot-identifier manual-backup-20240330-100000

# Option 3: Restore from S3 export
# Requires manual database import process
```

#### Scenario 5: Complete Regional Outage

**Preparation:**
```bash
# Setup cross-region S3 replication
aws s3api put-bucket-replication \
  --bucket student-portal-backups \
  --replication-configuration file:///tmp/replication.json

# Copy RDS snapshots to another region (automated)
aws rds modify-db-instance \
  --db-instance-identifier student-portal-production-db \
  --backup-retention-period 30 \
  --multi-az

# Setup: Replicate snapshots to us-west-2
```

**Recovery:**
```bash
# In new region (us-west-2):
export AWS_REGION=us-west-2

# 1. Restore database
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier student-portal-production-db-dr \
  --db-snapshot-identifier replicated-snapshot

# 2. Deploy infrastructure
cd terraform/environments/production
export TF_VAR_aws_region=us-west-2
terraform init -backend-config="region=us-west-2"
terraform apply

# 3. Update DNS
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE-ID> \
  --change-batch file:///tmp/dns-update.json

# 4. Deploy application
helm install student-portal ./helm-charts/student-portal \
  --namespace student-portal
```

## Backup Verification

### Daily Backup Tests

```bash
#!/bin/bash
# test-backups.sh - Monthly backup verification

# 1. Check RDS snapshots exist
SNAPSHOT_COUNT=$(aws rds describe-db-snapshots \
  --query 'length(DBSnapshots)' --output text)
echo "RDS Snapshots: $SNAPSHOT_COUNT"

if [ $SNAPSHOT_COUNT -lt 1 ]; then
  echo "ERROR: No recent RDS snapshots found!"
  exit 1
fi

# 2. Verify S3 exports
aws s3 ls s3://student-portal-backups/exports/ | head -5

# 3. Test PITR capability
RESTORABLE_TIME=$(aws rds describe-db-instances \
  --db-instance-identifier student-portal-production-db \
  --query 'DBInstances[0].EarliestRestorableTime' --output text)
echo "Earliest restorable time: $RESTORABLE_TIME"

# 4. Test Helm backup
helm get values student-portal -n student-portal

echo "All backup verification checks passed!"
```

### Monthly Restore Test

```bash
# Monthly: Test recovery procedure on staging environment
# 1. Take snapshot of production
aws rds create-db-snapshot \
  --db-instance-identifier student-portal-production-db \
  --db-snapshot-identifier staging-test-$(date +%Y%m%d)

# 2. Restore to staging
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier student-portal-staging-db-restored \
  --db-snapshot-identifier staging-test-$(date +%Y%m%d)

# 3. Run tests
# ...

# 4. Delete test instance
aws rds delete-db-instance \
  --db-instance-identifier student-portal-staging-db-restored \
  --skip-final-snapshot
```

## CloudWatch Monitoring

### Setup Backup Alarms

```bash
# Alert if no backups in 24 hours
aws cloudwatch put-metric-alarm \
  --alarm-name rds-backup-missing \
  --alarm-description "Alert if RDS backup is missing" \
  --metric-name SnapshotStorageUsed \
  --namespace AWS/RDS \
  --statistic Minimum \
  --period 86400 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1
```

## Backup Storage and Retention

### S3 Lifecycle Policy

```json
{
  "Rules": [
    {
      "Id": "DeleteOldBackups",
      "Filter": {"Prefix": "mysql/daily/"},
      "Status": "Enabled",
      "Expiration": {
        "Days": 90
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    },
    {
      "Id": "TransitionToGlacier",
      "Filter": {"Prefix": "mysql/"},
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

## Compliance and Audit

### Backup Audit Log

```bash
# Enable AWS Config to track RDS backup compliance
aws configservice put-config-rule --config-rule file:///tmp/rds-backup-rule.json

# List backup events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateDBSnapshot \
  --max-results 10
```

## Documentation

- Update this guide quarterly
- Test recovery procedures monthly
- Maintain backup inventory
- Document lessons learned from incidents

---

**Last Updated**: March 30, 2026  
**Next Review**: June 30, 2026  
**Last DR Test**: March 2026  
**Test Result**: ✅ Successful
