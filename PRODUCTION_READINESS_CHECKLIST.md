# Production Readiness Checklist

Use this checklist to validate the application is ready for production deployment. Check off each item before proceeding to the next deployment phase.

## Pre-Deployment Phase (1-2 weeks before)

### Infrastructure Setup
- [ ] **AWS Account & Permissions**: Production AWS account created, IAM roles configured
- [ ] **VPC Planning**: CIDR blocks assigned (10.0.0.0/16 for VPC, 10.0.1.0/24 - 10.0.11.0/24 for subnets)
- [ ] **S3 Bucket**: `student-portal-terraform-state-<ACCOUNT_ID>` created with versioning enabled
- [ ] **DynamoDB**: `terraform-state-lock` table created (hash key: LockID)
- [ ] **Route53 Domain**: Domain registered or transferred to Route53
- [ ] **TLS Certificate**: ACM certificate imported or created for domain
- [ ] **ECR Repositories**: Confirmed repositories exist (backend, frontend)

### Terraform Validation
- [ ] **Format Check**: `terraform fmt -recursive` passes
- [ ] **Validation**: `terraform validate` passes all checks
- [ ] **Plan Review**: `terraform plan` reviewed and approved by team lead
- [ ] **Cost Estimate**: Infrastructure costs reviewed (~$200-500/month for staging+prod)
- [ ] **Outputs**: Terraform outputs visible (cluster endpoint, RDS endpoint, ECR URLs)

### GitHub Actions Setup
- [ ] **OIDC Provider**: GitHub OIDC provider created in IAM
- [ ] **IAM Role**: `github-actions-role` created with trust policy
- [ ] **Policies**: Attached policies for ECR, EKS, Terraform, Secrets Manager
- [ ] **Secrets**: Configured repository secrets:
  - [ ] `AWS_ROLE_TO_ASSUME`: ARN of github-actions-role
  - [ ] `AWS_REGION`: Production region (e.g., us-east-1)
  - [ ] `RDS_MASTER_PASSWORD`: Strong password (min 16 chars, special chars)
  - [ ] `SLACK_WEBHOOK_URL`: For deployment notifications (optional)
- [ ] **Workflow Permissions**: Repository settings allow workflow read/write
- [ ] **Kubeconfig**: Added to secrets if needed for initial cluster access

### Container Images
- [ ] **Backend Dockerfile**: Multi-stage build validation
  - [ ] Alpine 3.19 base (or latest)
  - [ ] Non-root user (uid=1000)
  - [ ] dumb-init installed
  - [ ] Health check configured
  - [ ] Metadata labels present
- [ ] **Frontend Dockerfile**: Nginx-based validation
  - [ ] Nginx 1.25 base (or latest)
  - [ ] Multi-stage build
  - [ ] Non-root user
  - [ ] nginx config files in place
  - [ ] Health check configured
- [ ] **.dockerignore**: Both files reduce unnecessary layer bloat

## Infrastructure Deployment Phase (Day of deployment)

### Terraform Apply
- [ ] **Pre-check**: `terraform init` successful with S3 backend
- [ ] **Secrets**: RDS password injected via `TF_VAR_rds_master_password`
- [ ] **Apply**: `terraform apply` executed (takes ~20-30 minutes)
  - [ ] VPC created with subnets and security groups
  - [ ] EKS cluster created (1-2 pods already running for system services)
  - [ ] RDS instance created and accessible
  - [ ] ECR repositories configured with lifecycle policies
  - [ ] CloudWatch log groups created
  - [ ] IAM roles and IRSA configured
- [ ] **Outputs Captured**: Save terraform outputs to outputs.json
  - [ ] eks_cluster_endpoint
  - [ ] rds_endpoint
  - [ ] ecr_backend_url
  - [ ] ecr_frontend_url
  - [ ] security_group_ids

### EKS Cluster Validation
- [ ] **Kubeconfig Updated**: `aws eks update-kubeconfig --name student-portal-production --region us-east-1`
- [ ] **Cluster Access**: `kubectl cluster-info` returns valid endpoint
- [ ] **Nodes Ready**: `kubectl get nodes` shows all nodes in Ready state
  - [ ] Expected: 3 nodes for production
  - [ ] All nodes: cpu/memory allocated
- [ ] **System Pods**: `kubectl get pods -n kube-system` shows kube-proxy, coredns running
- [ ] **Cluster Version**: `kubectl version --short` confirms 1.28+
- [ ] **API Server**: `kubectl api-resources` returns full resource list

### RDS Validation
- [ ] **Instance Status**: AWS Console → RDS → Instances shows "available"
- [ ] **Connectivity**: `mysql -h <rds-endpoint> -u admin -p<password> -e "SELECT 1"`
- [ ] **Database Created**: student_portal database exists
- [ ] **Backups Configured**: Automated backups enabled, retention = 30 days
- [ ] **Encryption**: Storage encryption enabled via KMS
- [ ] **Monitoring**: Enhanced monitoring enabled, CloudWatch alarms configured

## Application Deployment Phase

### Namespace & RBAC
- [ ] **Namespace**: `kubectl apply -f student-portal/namespace.yaml` creates student-portal namespace
- [ ] **ServiceAccount**: Service account student-portal-sa created with IRSA annotation
- [ ] **RBAC Role**: View-only role and RoleBinding applied
- [ ] **NetworkPolicy**: Namespace-level network policies enforced
- [ ] **ResourceQuota**: Quota limits enforced (100m CPU, 512Mi memory requests)

### Secrets & ConfigMaps
- [ ] **RDS Credentials**: Secrets stored in AWS Secrets Manager:
  - [ ] Secret name: `student-portal/rds`
  - [ ] Contains: host, port, username, password, dbname
- [ ] **Kubernetes Secrets**: `kubectl apply -f backend/secret.yaml` creates Kubernetes secrets
- [ ] **ConfigMaps**: Backend and frontend configmaps created with environment settings
- [ ] **Secret Injection**: IRSA pod can retrieve secrets from Secrets Manager

### Image Scanning
- [ ] **ECR Scan Results**: Both backend and frontend images scanned
  - [ ] No CRITICAL vulnerabilities
  - [ ] HIGH vulnerabilities: Documented exceptions or remediated
  - [ ] ECR scan status: PASSED
- [ ] **Image Tags**: Using semantic versioning (v1.0.0, not latest)
- [ ] **Image Immutability**: ECR repositories have image_tag_mutability=IMMUTABLE

### Helm Deployment
- [ ] **Helm Repo**: Added any external charts (NGINX, cert-manager, etc.)
- [ ] **Values File**: values.yaml reviewed and tested in staging first
  - [ ] Backend replicas: 3
  - [ ] Frontend replicas: 2
  - [ ] Resources: requests and limits configured
  - [ ] HPA enabled: backend 3-10, frontend 2-5
  - [ ] Health check paths: /health, /ready accessible
- [ ] **Dry Run**: `helm install --dry-run` produces valid manifests
- [ ] **Install**: `helm install student-portal helm-charts/student-portal --namespace student-portal`
- [ ] **Verify**: `helm status student-portal` shows deployed

### Pod Deployment Verification
- [ ] **Pods Running**: `kubectl get pods -n student-portal` shows all pods Running
  - [ ] Expected: 3 backend pods, 2 frontend pods, 2 nginx-ingress controller pods
  - [ ] All pods: Ready status (e.g., 1/1, 2/2)
- [ ] **Pod Logs**: `kubectl logs <pod-name> -n student-portal` show clean startup
  - [ ] Backend: "Server running on port 5000" messages
  - [ ] Frontend: Nginx started successfully
  - [ ] No error messages in logs
- [ ] **Pod Events**: `kubectl describe pod <pod-name>` shows no warning events
- [ ] **Resource Requests**: `kubectl top pods -n student-portal` shows reasonable usage
  - [ ] Backend: ~50-100m CPU, 100-200Mi memory
  - [ ] Frontend: ~10-20m CPU, 50-100Mi memory

## Networking & Ingress Phase

### Ingress Controller
- [ ] **NGINX Installed**: `kubectl get svc -n ingress-nginx` shows nginx-ingress service
- [ ] **Service Type**: Confirmed LoadBalancer with AWS ELB
- [ ] **External IP**: `kubectl get svc -n ingress-nginx` shows external IP/DNS name
- [ ] **Health Check**: ELB targets marked healthy in AWS Console

### Ingress Configuration
- [ ] **Ingress Object**: `kubectl get ingress -n student-portal` shows student-portal ingress
- [ ] **Rules Configured**: Ingress rules route:
  - [ ] `/` → frontend service
  - [ ] `/api` → backend service
- [ ] **TLS Certificate**: Ingress configured with cert-manager
  - [ ] Certificate requested: `kubectl get certificate -n student-portal`
  - [ ] Status: Ready/True
- [ ] **DNS Resolution**: `nslookup app.yourdomain.com` resolves to ELB DNS name
- [ ] **HTTPS Access**: 
  - [ ] `curl https://app.yourdomain.com` returns frontend HTML
  - [ ] Certificate valid (no SSL warnings)

### Service Mesh (Optional)
- [ ] **Istio/Linkerd**: (if enabled) Data plane sidecar injection verified
- [ ] **VirtualService**: Traffic routing policies applied
- [ ] **DestinationRule**: Load balancing configured

## Monitoring & Logging Phase

### Prometheus Metrics
- [ ] **Prometheus Pod**: `kubectl get pods -n prometheus` shows Prometheus running
- [ ] **Scrape Targets**: `kubectl port-forward svc/prometheus 9090:9090` → http://localhost:9090/targets
  - [ ] All targets showing UP status
  - [ ] Backend metrics: 3/3 replicas scraped
  - [ ] Frontend metrics: 2/2 replicas scraped
- [ ] **Sample Queries**: 
  - [ ] `up` returns 1 for all targets
  - [ ] `container_cpu_usage_seconds_total` returns values for backend/frontend
  - [ ] `container_memory_usage_bytes` returns memory metrics
- [ ] **Alert Rules**: `kubectl get servicemonitor -n student-portal` shows monitoring configured

### Grafana Dashboards
- [ ] **Grafana Access**: `kubectl port-forward svc/grafana 3000:3000` → http://localhost:3000
- [ ] **Initial Login**: default credentials changed (admin:prom-operator)
- [ ] **Datasource**: Prometheus datasource added and verified
- [ ] **Dashboards Imported**:
  - [ ] Kubernetes Cluster Monitoring (6417)
  - [ ] Pod Monitoring (8588)
  - [ ] Node Exporter Dashboard (1860)
- [ ] **Application Dashboard**: Custom dashboard showing backend/frontend metrics
  - [ ] Request rate (requests/sec)
  - [ ] Response time (p50, p95, p99)
  - [ ] Error rate (4xx, 5xx)
  - [ ] Pod memory/CPU usage

### Loki Logs
- [ ] **Loki Pod**: `kubectl get pods -n loki` shows Loki running
- [ ] **Log Ingestion**: Logs flowing from all pods
- [ ] **Grafana Explore**: Loki datasource configured in Grafana
  - [ ] Query: `{app="backend"}` returns recent logs
  - [ ] Query: `{app="frontend"}` returns recent logs
- [ ] **Retention**: Logs retained for minimum 7 days

### CloudWatch Integration
- [ ] **CloudWatch Logs**: `/aws/eks/student-portal-production` log group contains:
  - [ ] /aws/eks/student-portal-production/api
  - [ ] /aws/eks/student-portal-production/audit
  - [ ] /aws/eks/student-portal-production/authenticator
- [ ] **Log Retention**: Set to 30 days minimum
- [ ] **CloudWatch Alarms**:
  - [ ] RDS CPU > 80% alarm configured
  - [ ] RDS storage < 10% free alarm configured
  - [ ] EKS node CPU > 80% alarm configured
  - [ ] EKS pod memory OOMKilled alarm configured

### Alerting
- [ ] **AlertManager**: `kubectl get pods -n prometheus` shows AlertManager running
- [ ] **Alert Rules**: 
  - [ ] PodCrashLooping triggered when pods crash
  - [ ] HighErrorRate triggered when 5xx errors > 5%
  - [ ] HighLatency triggered when response time > 1s (p99)
  - [ ] DatabaseConnectionHigh triggered when connections > 80% pool
- [ ] **Notification Channel**: Slack/Email configured for alerts
  - [ ] Test alert triggered manually
  - [ ] Notification received successfully

## Backup & Disaster Recovery Phase

### RDS Backups
- [ ] **Automated Backups**: AWS RDS console shows automated backups enabled
  - [ ] Backup retention: 30 days
  - [ ] Backup window: Off-peak hours (e.g., 2-3 AM UTC)
  - [ ] Latest snapshot: < 24 hours old
- [ ] **Manual Snapshot**: Create test snapshot for recovery validation
  - [ ] Snapshot name: `student-portal-prod-pre-launch`
  - [ ] Snapshot encrypted
- [ ] **PITR Test**: 
  - [ ] Create test database from point-in-time (24 hours ago)
  - [ ] Verify: Data present and queryable
  - [ ] Delete: Test database after verification

### Kubernetes etcd Backup
- [ ] **etcd Backup Script**: Configured in /scripts/backup-etcd.sh
- [ ] **Backup Frequency**: Scheduled via CronJob (daily at 1 AM)
- [ ] **Backup Storage**: Snapshots stored in S3 bucket with encryption
- [ ] **Restore Test**: Practiced restoring from etcd snapshot (in dev cluster)

### Disaster Recovery Plan
- [ ] **RTO Document**: Retrieved and reviewed (30 minutes for DB, 1 hour for cluster)
- [ ] **RPO Document**: Data loss threshold defined (5 minutes max)
- [ ] **Failover Procedure**: Documented steps for Multi-AZ RDS failover
- [ ] **Runbook**: Team trained on recovery procedures

## Performance Baseline Phase

### Load Testing Setup
- [ ] **Load Test Tool**: k6 or JMeter installed and configured
- [ ] **Test Scenarios**: Created baseline, ramp-up, stress, and sustainability tests
- [ ] **Endpoints Defined**: 
  - [ ] Frontend: GET /
  - [ ] Backend: GET /api/health, POST /api/auth/login
  - [ ] Backend: GET /api/students (with auth)
- [ ] **Baseline Metrics Captured**:
  - [ ] Throughput: X requests/second
  - [ ] p50: Y ms
  - [ ] p95: Z ms
  - [ ] p99: W ms
  - [ ] Error rate: < 0.5%

### Execution
- [ ] **Baseline Test**: 100 concurrent users, 5 minutes
  - [ ] Metrics recorded in spreadsheet
  - [ ] Pod CPU/memory normal range established
  - [ ] No error spike
- [ ] **Ramp-up Test**: 100→1000 users over 10 minutes
  - [ ] HPA scales pod count appropriately
  - [ ] Performance degrades < 10%
  - [ ] No 5xx errors
- [ ] **Stress Test**: Increase until breaking point
  - [ ] Document failure threshold (e.g., pod unable to scale beyond 20)
  - [ ] Rollback gracefully
  - [ ] Alert triggers before breaking

### Optimization
- [ ] **Slow Endpoints**: Analyzed via Prometheus/Grafana
- [ ] **Bottleneck Identified**: Is it CPU, memory, I/O, or DB?
- [ ] **Tuning Applied**: 
  - [ ] If CPU: Optimize query N+1, reduce computations
  - [ ] If memory: Reduce connection pool, enable pagination
  - [ ] If I/O: Enable caching, use CDN
  - [ ] If DB: Add indexes, optimize queries
- [ ] **Re-test**: Verify improvements met targets

## Security Validation Phase

### Container Security
- [ ] **Image Scanning**: ECR results reviewed
  - [ ] CVE list: 0 CRITICAL, 0 HIGH (or exceptions documented)
  - [ ] Scanning enabled: on-push enabled
- [ ] **Image Layers**: Scanned for hardcoded secrets
  - [ ] No AWS credentials in Dockerfile
  - [ ] No database passwords in ENV
  - [ ] No API keys in code
- [ ] **Base Images**: Verified latest stable versions
  - [ ] node:18-alpine3.19 up-to-date
  - [ ] nginx:1.25-alpine up-to-date

### Kubernetes Security
- [ ] **RBAC**: ServiceAccount permissions minimal
  - [ ] get/list pods only (not create/delete)
  - [ ] No cluster-admin role assignment
  - [ ] No wildcard (* ) resource access
- [ ] **Network Policies**: 
  - [ ] Backend ingress: frontend and ingress-nginx only
  - [ ] Backend egress: RDS (3306), DNS (53), HTTPS (443)
  - [ ] Frontend ingress: ingress-nginx only
  - [ ] Frontend egress: backend, DNS, HTTPS
- [ ] **Pod Security Policy**: PSP/PSS enforced
  - [ ] No privileged containers
  - [ ] No root user (verified: uid=1000)
  - [ ] No hostNetwork/hostPID
- [ ] **Secrets**: Never logged or exposed
  - [ ] Secrets stored in Kubernetes Secret (not ConfigMap)
  - [ ] AWS Secrets Manager used for sensitive data
  - [ ] No secrets in logs (grep audit.log for secret names)

### AWS Security
- [ ] **IAM Policy**: Principle of least privilege verified
  - [ ] OIDC role: Only ECR, EKS, Secrets Manager, Terraform permissions
  - [ ] Pod roles (IRSA): Only specific secrets accessible
  - [ ] No wildcard (*) actions allowed
- [ ] **VPC Security**:
  - [ ] RDS in private subnet (no internet gateway)
  - [ ] Bastion host (optional): For RDS access if needed
  - [ ] Security groups: Minimal ingress rules
- [ ] **Encryption**:
  - [ ] EBS volumes: AES-256 encryption enabled
  - [ ] RDS: Storage encryption enabled
  - [ ] S3 state bucket: SSE-S3 encryption enabled
  - [ ] Secrets: KMS key for encryption
- [ ] **Logging & Monitoring**:
  - [ ] CloudTrail: enabled for audit trail
  - [ ] VPC Flow Logs: enabled for network analysis
  - [ ] CloudWatch Logs: retention policy 90 days minimum

### DenialS of Service (DoS) Protection
- [ ] **Rate Limiting**: Nginx configured with limit_req zones
  - [ ] General endpoint: 100 req/s per IP
  - [ ] API endpoint: 50 req/s per IP
  - [ ] Status: 429 (Too Many Requests) returned
- [ ] **Connection Limits**: 
  - [ ] Max connections per worker: 1024
  - [ ] Database pool size: 20 (prevents connection exhaustion)
- [ ] **Resource Limits**: Pod CPU/memory limits prevent runaway usage

## Post-Deployment Validation Phase

### Smoke Tests
- [ ] **Frontend Access**: 
  - [ ] `curl https://app.yourdomain.com/` returns 200
  - [ ] Dashboard loads in browser
  - [ ] CSS/JS assets load
- [ ] **Backend API**: 
  - [ ] `curl https://app.yourdomain.com/api/health` returns 200
  - [ ] Login endpoint: POST /api/auth/login with test credentials
  - [ ] Authenticated endpoint: GET /api/students with auth token
- [ ] **Database**: 
  - [ ] Backend can connect to RDS
  - [ ] User data persists across pod restarts
- [ ] **Monitoring**: 
  - [ ] Prometheus scraping all targets
  - [ ] Grafana dashboards populated with data
  - [ ] Logs flowing to Loki
  - [ ] CloudWatch logs ingesting EKS events

### Chaos Engineering (Optional)
- [ ] **Pod Failure**: 
  - [ ] Delete random pod: `kubectl delete pod <pod>`
  - [ ] Verify: HPA recreates pod automatically
  - [ ] Frontend/API continues working
- [ ] **Node Failure**: 
  - [ ] Terminate EC2 node (simulated failure)
  - [ ] Verify: ASG recreates node
  - [ ] Pods reschedule to remaining nodes
  - [ ] Service continues without interruption
- [ ] **Network Partition**: 
  - [ ] Simulate network latency (tc qdisc in pod)
  - [ ] Verify: Request timeouts handled gracefully
  - [ ] Health checks detect and remediate

### User Acceptance Testing (UAT)
- [ ] **Business Stakeholders**: Sign off on feature set
  - [ ] Dashboard displays correctly
  - [ ] Login/logout works
  - [ ] Student data visible and searchable
  - [ ] Reports generate successfully
- [ ] **Performance Targets**: Met or exceeded
  - [ ] Page load < 2 seconds
  - [ ] API response < 500ms (p95)
  - [ ] Zero errors under production load
- [ ] **Documentation**: UAT team trained
  - [ ] Runbook provided
  - [ ] Escalation contacts defined
  - [ ] Known issues documented

## Launch Readiness (Final Sign-off)

- [ ] **Checklist 100% Complete**: Every item above checked
- [ ] **Approvals**:
  - [ ] Infrastructure Lead: Terraform, EKS, RDS approved
  - [ ] Security Lead: VPC, RBAC, encryption approved
  - [ ] DevOps Lead: CI/CD, monitoring, backups approved
  - [ ] Engineering Lead: Code quality, performance approved
  - [ ] Product Manager: Feature completeness approved
- [ ] **Runbook Distribution**: Sent to all on-call engineers
- [ ] **Alert Escalation**: On-call schedule published
- [ ] **Rollback Plan**: Documented and rehearsed (terraform destroy, restore snapshot)
- [ ] **Go/No-Go Meeting**: Stakeholders confirm production ready

## Post-Launch Monitoring (First 7 Days)

- [ ] **Hourly Check**: First 24 hours - verify no critical issues
- [ ] **Daily Review**: Days 2-7 - review metrics, error rates, performance
- [ ] **Weekly Review**: Day 7+ - comprehensive performance analysis
- [ ] **Issues Logged**: Known issues tracked in JIRA/GitHub Issues
- [ ] **Hotfix Pipeline**: Ready for critical bugs (tested before deploy)

---

**Document Version**: 1.0  
**Last Updated**: [Today's Date]  
**Next Review**: Before next major release
