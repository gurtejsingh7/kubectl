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

# 0️⃣ Check dependencies
for cmd in minikube kubectl tmux; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

# 1️⃣ Start Minikube if not already running
log "Checking Minikube..."
if ! minikube status 2>/dev/null | grep -q "host: Running"; then
    warn "Starting Minikube..."
    minikube start --driver=docker
else
    ok "Minikube already running."
fi

# 2️⃣ Install Envoy Gateway only if no healthy pods exist
log "Checking Envoy Gateway..."
RUNNING_PODS=$(kubectl get pods -n envoy-gateway-system --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo 0)
if [[ "$RUNNING_PODS" -eq 0 ]]; then
    warn "Envoy Gateway not found or not running. Installing..."
    kubectl apply --server-side \
        -f https://github.com/envoyproxy/gateway/releases/download/v1.5.1/install.yaml
else
    ok "Envoy Gateway already running ($RUNNING_PODS pod(s))."
fi

# 3️⃣ Create crawler namespace if missing
log "Ensuring namespace 'crawler' exists..."
kubectl get ns crawler >/dev/null 2>&1 \
    && ok "Namespace 'crawler' already exists." \
    || { kubectl create ns crawler; ok "Namespace 'crawler' created."; }

# 4️⃣ Apply manifests in dependency order
log "Applying local manifests from $MANIFEST_DIR..."
[[ -d "$MANIFEST_DIR" ]] || die "Manifest directory '$MANIFEST_DIR' not found."

kubectl apply --server-side -f "$MANIFEST_DIR/gateway/"
kubectl apply --server-side -f "$MANIFEST_DIR/api/"
kubectl apply --server-side -f "$MANIFEST_DIR/crawler/"
kubectl apply --server-side -f "$MANIFEST_DIR/web/"

# 5️⃣ Launch dashboard in tmux (restart if dead)
SESSION_NAME="minikube-dashboard"
log "Ensuring Minikube dashboard tmux session..."
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    if ! tmux list-panes -t "$SESSION_NAME" -F "#{pane_dead}" | grep -q "^0$"; then
        warn "Tmux session '$SESSION_NAME' exists but process is dead. Recreating..."
        tmux kill-session -t "$SESSION_NAME"
        tmux new-session -d -s "$SESSION_NAME" "minikube dashboard"
    else
        ok "Tmux session '$SESSION_NAME' already running."
    fi
else
    tmux new-session -d -s "$SESSION_NAME" "minikube dashboard"
    ok "Dashboard launched in tmux session '$SESSION_NAME'."
fi

# 6️⃣ Done
echo ""
ok "== Setup Complete! =="
echo -e "${BLUE}Attach to dashboard:${NC}        ${YELLOW}tmux attach -t $SESSION_NAME${NC}"
echo -e "${BLUE}Get dashboard URL:${NC}           ${YELLOW}minikube dashboard --url${NC}"
echo -e "${BLUE}Monitor all pods live:${NC}       ${YELLOW}watch kubectl get po -A${NC}"
