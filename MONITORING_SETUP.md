# Production Monitoring and Logging Stack

## Overview

This guide covers setting up a comprehensive monitoring and logging stack for the Student Portal application on AWS EKS.

## Stack Components

1. **Prometheus**: Metrics collection and monitoring
2. **Grafana**: Visualization dashboard
3. **AlertManager**: Alert routing and management
4. **Loki**: Log aggregation
5. **Tempo**: Distributed tracing
6. **CloudWatch**: AWS native monitoring

## Installation

### Step 1: Install Prometheus Community Helm Chart

```bash
# Add Prometheus-Community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack (includes Prometheus, Grafana, AlertManager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values - <<EOF
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    serviceMonitorSelector:
      matchLabels:
        release: prometheus
    
    # Scrape configs for student-portal
    additionalScrapeConfigs:
      - job_name: 'student-portal-backend'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - student-portal
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)

grafana:
  enabled: true
  adminPassword: "changeme"  # Change in production
  persistence:
    enabled: true
    size: 10Gi
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-kube-prometheus-prometheus:9090
          isDefault: true

alertmanager:
  enabled: true
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 1h
      receiver: 'default'
    receivers:
      - name: 'default'
EOF
```

### Step 2: Install Loki for Log Aggregation

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --values - <<EOF
loki:
  persistence:
    enabled: true
    size: 20Gi
  config:
    auth_enabled: false
    ingester:
      chunk_idle_period: 3m
      max_chunk_age: 1h
      max_streams_per_user: 10000
      chunk_retain_period: 1m
    limits_config:
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: filesystem
          schema:
            prefix: index_
            version: v11
          index:
            prefix: index_
            period: 24h
    server:
      http_listen_port: 3100

promtail:
  enabled: true
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: node
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container

grafana:
  enabled: true
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Loki
          type: loki
          url: http://loki:3100
EOF
```

### Step 3: Install Tempo for Distributed Tracing

```bash
helm install tempo grafana/tempo \
  --namespace monitoring \
  --values - <<EOF
tempo:
  persistence:
    enabled: true
    size: 10Gi
  config:
    distributor:
      receivers:
        jaeger:
          protocols:
            grpc:
              endpoint: 0.0.0.0:14250
            thrift_http:
              endpoint: 0.0.0.0:14268

tempo:
  retention: 24h
EOF
```

## Grafana Dashboards

### Backend Metrics Dashboard

Create a new dashboard in Grafana with the following panels:

1. **Request Rate** (requests/sec)
   ```
   rate(http_requests_total[5m])
   ```

2. **Response Time** (95th percentile)
   ```
   histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   ```

3. **Error Rate**
   ```
   rate(http_requests_total{status=~"5.."}[5m])
   ```

4. **CPU Usage**
   ```
   rate(process_cpu_seconds_total[5m])
   ```

5. **Memory Usage**
   ```
   process_resident_memory_bytes
   ```

6. **Database Connections**
   ```
   mysql_global_status_threads_connected
   ```

### Log Dashboard

Query logs in Grafana using LogQL:

```
{namespace="student-portal", container="backend"} | json
```

## CloudWatch Integration

### Enable Container Insights

```bash
#  Create IAM role for CloudWatch Container Insights
aws iam create-role --role-name CloudWatchContainerInsightsRole \
  --assume-role-policy-document file:///tmp/trust-policy.json

AWS_POLICY_ARN="arn:aws:iam::aws:policy/CloudWatchContainerInsightsPolicy"
aws iam attach-role-policy --role-name CloudWatchContainerInsightsRole \
  --policy-arn $AWS_POLICY_ARN

# Deploy CloudWatch Logs agent
helm repo add aws https://aws.github.io/eks-charts
helm install aws-cloudwatch-metrics aws/aws-cloudwatch-metrics \
  --namespace amazon-cloudwatch \
  --create-namespace
```

### Application Logs to CloudWatch

```bash
# Install Fluent Bit for log forwarding
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --create-namespace \
  --values - <<EOF
config:
  service: |
    [SERVICE]
        Flush        5
        Daemon       Off
        Log_Level    info
        Parsers_File parsers.conf
        HTTP_Server  On
        HTTP_Listen  0.0.0.0
        HTTP_Port    2020
        Health_Check On
  
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On
  
  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Keep_Log            Off
  
  outputs: |
    [OUTPUT]
        Name cloudwatch_logs
        Match kube.student-portal.*
        region us-east-2
        log_group_name /aws/eks/student-portal
        log_stream_prefix from-fluent-bit-
        auto_create_group true
EOF
```

### CloudWatch Alarms

```bash
# CPU Utilization Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name student-portal-backend-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# Memory Utilization Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name student-portal-backend-memory \
  --alarm-description "Alert when memory exceeds 85%" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# Pod Restart Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name student-portal-pod-restarts \
  --alarm-description "Alert on pod restarts" \
  --metric-name pod_restarts \
  --namespace EKS/Pods \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1
```

## Alert Rules

Create `prometheus-rules.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: student-portal-alerts
  namespace: student-portal
spec:
  groups:
    - name: student-portal.rules
      interval: 30s
      rules:
        # High error rate
        - alert: HighErrorRate
          expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value | humanizePercentage }}"
        
        # High response time
        - alert: HighResponseTime
          expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High response time detected"
            description: "95th percentile response time is {{ $value }}s"
        
        # High CPU usage
        - alert: HighCPUUsage
          expr: rate(process_cpu_seconds_total[5m]) > 0.8
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High CPU usage"
            description: "CPU usage is {{ $value | humanizePercentage }}"
        
        # Database connection pool near limit
        - alert: DatabaseConnectionPoolHigh
          expr: mysql_global_status_threads_connected > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Database connection pool usage high"
            description: "{{ $value }} connections active"
        
        # Pod restart rate high
        - alert: PodRestartRateHigh
          expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod restart rate is high"
            description: "Pod {{ $labels.pod }} restarted {{ $value }} times"
```

## Accessing Dashboards

### Grafana

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at http://localhost:3000
# Default username: admin
# Default password: changeme
```

### Prometheus

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access at http://localhost:9090
```

## Maintenance

### Backup Metrics

```bash
# Export Prometheus data
kubectl exec -n monitoring prometheus-kube-prometheus-prometheus-0 -- \
  promtool query instant 'time()' --format json > prometheus-backup.json
```

### Update Retention Policy

```bash
kubectl patch statefulset prometheus-kube-prometheus-prometheus \
  -n monitoring \
  --type json \
  -p '[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus", "--storage.tsdb.retention.time=60d"]}]'
```

## Troubleshooting

### Prometheus not scraping metrics

```bash
# Check target status
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

### High memory usage

```bash
# Reduce retention period
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --reuse-values \
  --set prometheus.prometheusSpec.retention=7d
```

### Grafana datasource unavailable

```bash
# Verify Prometheus connectivity
kubectl exec -it -n monitoring prometheus-0 -- \
  curl -s http://prometheus:9090/api/v1/status/health
```

---

**Last Updated**: March 30, 2026
**Tested with**: Prometheus v2.40, Grafana v9.3, Loki v2.8
