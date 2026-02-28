#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# CONFIG (edit these)
# -----------------------------
DOMAIN="arsene-student-portal.duckdns.org"
NAMESPACE_APP="student-portal"
EMAIL="arsenet7@gmail.com"   # <-- CHANGE THIS to your email for Let's Encrypt
TLS_SECRET="student-portal-tls"

# Services inside your namespace
FRONTEND_SVC="student-portal-frontend"
BACKEND_SVC="student-portal-backend"

# Toggle cert-manager install (true/false)
INSTALL_CERT_MANAGER="true"

# -----------------------------
# Helpers
# -----------------------------
log() { echo -e "\n\033[1;34m==> $*\033[0m"; }

need_kubectl() {
  command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
  kubectl version --client >/dev/null 2>&1 || true
}

wait_ns_deleted() {
  local ns="$1"
  for i in {1..60}; do
    if ! kubectl get ns "$ns" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for namespace $ns to delete"
  exit 1
}

# -----------------------------
# Start
# -----------------------------
need_kubectl

log "Showing current ingress-nginx and cert-manager resources (if any)"
kubectl get ns | egrep 'ingress-nginx|cert-manager' || true
kubectl get all -n ingress-nginx 2>/dev/null || true
kubectl get all -n cert-manager 2>/dev/null || true

# -----------------------------
# 1) DELETE ingress-nginx fully
# -----------------------------
log "Deleting ingress-nginx namespace (removes all ingress controllers/services/jobs)"
kubectl delete namespace ingress-nginx --ignore-not-found=true
wait_ns_deleted ingress-nginx

# -----------------------------
# 2) DELETE cert-manager fully
# -----------------------------
log "Deleting cert-manager namespace"
kubectl delete namespace cert-manager --ignore-not-found=true || true
# Wait only if it existed
if kubectl get ns cert-manager >/dev/null 2>&1; then
  wait_ns_deleted cert-manager
fi

log "Deleting cert-manager CRDs (full cleanup)"
kubectl delete crd \
  certificaterequests.cert-manager.io \
  certificates.cert-manager.io \
  challenges.acme.cert-manager.io \
  clusterissuers.cert-manager.io \
  issuers.cert-manager.io \
  orders.acme.cert-manager.io \
  --ignore-not-found=true

log "Deleting cert-manager webhooks (if they exist)"
kubectl get validatingwebhookconfigurations | grep -i cert-manager >/dev/null 2>&1 && \
  kubectl get validatingwebhookconfigurations | awk '/cert-manager/ {print $1}' | xargs -r kubectl delete validatingwebhookconfiguration || true

kubectl get mutatingwebhookconfigurations | grep -i cert-manager >/dev/null 2>&1 && \
  kubectl get mutatingwebhookconfigurations | awk '/cert-manager/ {print $1}' | xargs -r kubectl delete mutatingwebhookconfiguration || true

log "Optional: deleting old TLS secret in app namespace (if present)"
kubectl delete secret "$TLS_SECRET" -n "$NAMESPACE_APP" --ignore-not-found=true

# -----------------------------
# 3) REINSTALL ingress-nginx clean
# -----------------------------
log "Installing ingress-nginx (clean official manifest)"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml

log "Waiting for ingress-nginx controller to be Ready..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s

log "Ingress-nginx service info:"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide

# -----------------------------
# 4) REINSTALL cert-manager (optional)
# -----------------------------
if [[ "$INSTALL_CERT_MANAGER" == "true" ]]; then
  log "Installing cert-manager"
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

  log "Waiting for cert-manager deployments to be Ready..."
  kubectl rollout status deployment/cert-manager -n cert-manager --timeout=180s
  kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=180s
  kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=180s

  # -----------------------------
  # 5) Create ClusterIssuer for Let's Encrypt
  # -----------------------------
  log "Creating Let's Encrypt ClusterIssuer (prod)"
  cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

  log "ClusterIssuer status:"
  kubectl get clusterissuer letsencrypt-prod -o wide
else
  log "Skipping cert-manager install (INSTALL_CERT_MANAGER=false)"
fi

# -----------------------------
# 6) Create/Apply Student Portal Ingress (TLS + routing)
# -----------------------------
log "Applying Student Portal Ingress for domain: ${DOMAIN}"
if [[ "$INSTALL_CERT_MANAGER" == "true" ]]; then
  # TLS enabled with cert-manager
  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: student-portal-ingress
  namespace: ${NAMESPACE_APP}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${DOMAIN}
    secretName: ${TLS_SECRET}
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: ${BACKEND_SVC}
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${FRONTEND_SVC}
            port:
              number: 80
EOF
else
  # No TLS
  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: student-portal-ingress
  namespace: ${NAMESPACE_APP}
spec:
  ingressClassName: nginx
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: ${BACKEND_SVC}
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${FRONTEND_SVC}
            port:
              number: 80
EOF
fi

log "Ingress created. Current Ingress status:"
kubectl get ingress -n "$NAMESPACE_APP" -o wide
kubectl describe ingress -n "$NAMESPACE_APP" student-portal-ingress | sed -n '1,120p' || true

if [[ "$INSTALL_CERT_MANAGER" == "true" ]]; then
  log "Watching certificate (may take 1-5 minutes depending on DNS reachability)"
  kubectl get certificate -n "$NAMESPACE_APP" || true
  echo
  echo "If certificate is not Ready yet, run:"
  echo "  kubectl describe certificate -n ${NAMESPACE_APP}"
  echo "  kubectl describe challenge -n ${NAMESPACE_APP}"
fi

log "DONE"
echo "Next:"
echo "1) Ensure your DNS (${DOMAIN}) points to your ingress entrypoint (Node public IP or LB IP)."
echo "2) Ensure ports are reachable from the internet."
echo "   - For kubeadm, ingress service may be NodePort or LoadBalancer(<pending>)."
echo "   - Check: kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide"
