#!/bin/zsh
set -e

HOME_PATH="/Users/mazhari/goinfre"
TOOLS_DIR="$HOME_PATH/tools"
BIN_DIR="$TOOLS_DIR/bin"
mkdir -p "$BIN_DIR"

# Add BIN_DIR to PATH (only if not already added)
echo "export PATH=\"$BIN_DIR:\$PATH\"" >> ~/.zshrc
source  ~/.zshrc
export PATH="$BIN_DIR:$PATH"

echo "🚀 Installing tools to $BIN_DIR..."

# ---------------------------
# 1. Install kubectl
# ---------------------------
if ! command -v kubectl &>/dev/null; then
  echo "📦 Installing kubectl..."
  curl -Lo "$BIN_DIR/kubectl" "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
  chmod +x "$BIN_DIR/kubectl"
else
  echo "✅ kubectl already installed"
fi

# ---------------------------
# 2. Install k3d
# ---------------------------
if ! command -v k3d &>/dev/null; then
  echo "☸️ Installing k3d..."
  curl -Lo "$BIN_DIR/k3d" -s  "https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh" | sh
  chmod +x "$BIN_DIR/k3d"
else
  echo "✅ k3d already installed"
fi

# ---------------------------
# 3. Check Docker is running
# ---------------------------
if ! docker info &>/dev/null; then
  echo "❌ Docker is not running. Start Docker first!"
  exit 1
fi

# ---------------------------
# 4. Create k3d cluster with timeout
# ---------------------------
echo "🚀 Creating k3d cluster..."
k3d cluster create iot-cluster

# ---------------------------
# 5. Create namespaces
# ---------------------------
echo "📁 Creating namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

echo "📡 Installing Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ---------------------------
# 9. Wait for Argo CD to be ready
# ---------------------------
echo "⏳ Waiting for Argo CD server to be available..."
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd


# ---------------------------
# 10. Get Argo CD password
# ---------------------------
echo "🔐 Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

echo "
✅ Setup complete! 🎉

🔗 To access the Argo CD UI:
Run:
    kubectl port-forward svc/argocd-server -n argocd 8080:443
Then visit:
    https://localhost:8080

Login:
    Username: admin
    Password: (above)