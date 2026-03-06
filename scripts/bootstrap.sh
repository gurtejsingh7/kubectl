#!/bin/bash
# =========================
# Minikube Bootstrap Script
# =========================
set -euo pipefail

GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

log()  { echo -e "${BLUE}-> $*${NC}"; }
ok()   { echo -e "${GREEN}✔ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
die()  { echo -e "${RED}✘ $*${NC}" >&2; exit 1; }

# Resolve paths relative to script location, not working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="${MANIFEST_DIR:-$SCRIPT_DIR/../manifests}"

echo -e "${BLUE}== Minikube Setup Script ==${NC}"

# 1️⃣ Check dependencies
for cmd in minikube kubectl; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

# Cache sudo credentials upfront
log "Requesting sudo credentials..."
sudo -v
ok "Sudo credentials cached."

# 2️⃣ Start Minikube if not already running
log "Checking Minikube..."
if ! minikube status 2>/dev/null | grep -q "host: Running"; then
    warn "Starting Minikube..."
    minikube start --driver=docker
else
    ok "Minikube already running."
fi

# 3️⃣ Start minikube tunnel if not already running
log "Checking minikube tunnel..."
if ! pgrep -f "minikube tunnel" > /dev/null; then
    echo ""
    warn "ACTION REQUIRED: Open a new terminal and run:"
    echo -e "        ${RED} minikube tunnel -c${NC}"
    echo ""
    log "Waiting for tunnel to come up before continuing..."
    for i in {1..20}; do
        if pgrep -f "minikube tunnel" > /dev/null; then
            ok "Minikube tunnel detected, continuing..."
            break
        fi
        warn "Waiting for tunnel... attempt $i/20"
        sleep 5
        if [[ $i -eq 20 ]]; then
            die "Minikube tunnel never started. Please run 'minikube tunnel -c' in a separate terminal."
        fi
    done
else
    ok "Minikube tunnel already running."
fi

# 4️⃣ Install Envoy Gateway only if no healthy pods exist
log "Checking Envoy Gateway..."
RUNNING_PODS=$(kubectl get pods -n envoy-gateway-system --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo 0)
if [[ "$RUNNING_PODS" -eq 0 ]]; then
    warn "Envoy Gateway not found or not running. Installing..."
    kubectl apply --server-side \
        -f https://github.com/envoyproxy/gateway/releases/download/v1.5.1/install.yaml
    log "Waiting for Envoy Gateway to become ready..."
    kubectl wait --for=condition=Available deployment/envoy-gateway \
        -n envoy-gateway-system --timeout=120s
else
    ok "Envoy Gateway already running ($RUNNING_PODS pod(s))."
fi

# 5️⃣ Create crawler namespace if missing
log "Ensuring namespace 'crawler' exists..."
kubectl get ns crawler >/dev/null 2>&1 \
    && ok "Namespace 'crawler' already exists." \
    || { kubectl create ns crawler; ok "Namespace 'crawler' created."; }

# 6️⃣ Apply manifests in dependency order
log "Applying local manifests from $MANIFEST_DIR..."
[[ -d "$MANIFEST_DIR" ]] || die "Manifest directory '$MANIFEST_DIR' not found."

kubectl apply --server-side -f "$MANIFEST_DIR/gateway/"
kubectl apply --server-side -f "$MANIFEST_DIR/api/"
kubectl apply --server-side -f "$MANIFEST_DIR/crawler/"
kubectl apply --server-side -f "$MANIFEST_DIR/web/"

# 7️⃣ Update /etc/hosts with current gateway IP
log "Updating /etc/hosts with gateway IP..."

kubectl wait --for=condition=Available deployment/envoy-gateway \
    -n envoy-gateway-system --timeout=120s

GATEWAY_IP=""
for i in {1..10}; do
    GATEWAY_IP=$(kubectl get svc -n envoy-gateway-system \
        -l gateway.envoyproxy.io/owning-gateway-name=app-gateway \
        --output jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [[ -n "$GATEWAY_IP" ]]; then
        break
    fi
    warn "Waiting for gateway IP... attempt $i/10"
    sleep 10
done

if [[ -z "$GATEWAY_IP" ]]; then
    die "Gateway IP never assigned. Run 'kubectl get svc -A' to debug."
fi

HOSTS="synchat.internal synchatapi.internal"
sudo sh -c "grep -v 'synchat.internal' /etc/hosts > /tmp/hosts && printf '%s  %s\n' '$GATEWAY_IP' '$HOSTS' >> /tmp/hosts && cat /tmp/hosts > /etc/hosts"
ok "Updated /etc/hosts → $GATEWAY_IP $HOSTS"

# 8️⃣ Launch minikube dashboard in background
log "Starting Minikube dashboard..."
if ! pgrep -f "minikube dashboard" > /dev/null; then
    nohup minikube dashboard > /tmp/minikube-dashboard.log 2>&1 &
    ok "Dashboard started (logs at /tmp/minikube-dashboard.log)"
else
    ok "Minikube dashboard already running."
fi

# 9️⃣ Done
echo ""
ok "== Setup Complete! =="
echo -e "${BLUE}K8s Dashboard:${NC}         ${YELLOW}minikube dashboard${NC}"
echo -e "${BLUE}Monitor all pods:${NC}      ${YELLOW}watch kubectl get po -A${NC}"