#!/bin/bash

# Step 1: Install k3d (lightweight wrapper to run k3s in Docker)
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Step 2: Install Docker (required for k3d to run)
# Add Docker's official GPG key for package verification
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install ca-certificates jq -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker's repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker and related packages
sudo DEBIAN_FRONTEND=noninteractive apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Step 3: Install kubectl (Kubernetes CLI tool)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Step 4: Create a k3d cluster named 'argoCluster' with custom port mappings
# Port mappings: 443->32222, 8888->32223, 444->32224
k3d cluster create argoCluster --port "443:32222" --port "8888:32223" --port "444:32224"

# Step 5: Install Helm (Kubernetes package manager)
wget https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
tar -xvf helm-v3.12.0-linux-amd64.tar.gz && sudo mv linux-amd64/helm /usr/local/bin && rm -rf helm-v3.12.0-linux-amd64.tar.gz linux-amd64

# Step 6: Install Argo CD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Step 7: Add the GitLab Helm repository
helm repo add gitlab http://charts.gitlab.io/

# Step 8: Install GitLab using Helm with custom values from ../confs/values.yaml
helm install gitlab gitlab/gitlab -n gitlab --create-namespace -f ../confs/values.yaml

# Step 9: Patch the GitLab NGINX Ingress controller service to use a specific NodePort (32222) for HTTPS
kubectl patch svc gitlab-nginx-ingress-controller -n gitlab --patch '{"spec":{"ports":[{"name":"https","nodePort":32222,"port":443,"protocol":"TCP"}]}}'

echo "--------Gitlab is now accessible on https://gitlab.46.101.86.85.nip.io-------"

# Step 10: Create namespaces for Argo CD and development
kubectl create namespace argocd
kubectl create namespace dev

# Step 11: Install Argo CD in the 'argocd' namespace
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd

# Step 112: Patch the Argo CD server service to use NodePort 32224 for HTTPS
kubectl patch svc argocd-server -n argocd --patch '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {
        "name": "https",
        "port": 443,
        "protocol": "TCP",
        "nodePort": 32224
      }
    ]
  }
}'

# Step 13: Wait for GitLab to be fully up and running by checking its HTTP status
while true; do
  status=$(curl -k -s -o /dev/null -w "%{http_code}" https://gitlab.46.101.86.85.nip.io)
  if [ "$status" != "502" ]; then
    echo "✅ Server is up!"
    break
  fi
  echo "⏳ waiting for gitlab to start up"
  sleep 10
done

echo "--------    argocd is now accessible on https://46.101.86.85:444    -------"

# Step 14: Retrieve the initial admin password for Argo CD
ADMIN_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)

# Step 15: Log in to Argo CD CLI using the admin credentials
argocd login 46.101.86.85:444 --insecure --username admin --password $ADMIN_PASSWORD


# Step 16: Obtain an OAuth access token for GitLab using the root credentials
ROOT_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d)
ACCESS_TOKEN=$(curl -s -k --data "grant_type=password&username=root&password=$ROOT_PASSWORD" --request POST "https://gitlab.46.101.86.85.nip.io/oauth/token" | jq -r '.access_token')

# Step 17: Create a new GitLab repository named 'k3d_ael-korc_conf' using the API
curl -s -k -X POST "https://gitlab.46.101.86.85.nip.io/api/v4/projects?access_token=$ACCESS_TOKEN" \
  --data "name=k3d_ael-korc_conf&visibility=public" | jq -r '.http_url_to_repo'

# Step 18: Navigate to the application configuration directory
cd ../confs/application

# Step 19: Initialize a new Git repository, add the remote, and configure user details
git init -b main && git remote add origin https://oauth2:$ACCESS_TOKEN@gitlab.46.101.86.85.nip.io/root/k3d_ael-korc_conf.git
git config --local user.name "Administrator"
git config --local user.email "gitlabUser@example.com"

# Step 20: Stage, commit, and push the initial files to the GitLab repository
git add . && git commit -m "Initial commit"
GIT_SSL_NO_VERIFY=true git push origin main

# Step 21: Add the GitLab repository to Argo CD, skipping SSL verification
argocd repo add https://gitlab.46.101.86.85.nip.io/root/k3d_ael-korc_conf.git --insecure-skip-server-verification

# Step 22: Apply the Argo CD configuration from the local files
kubectl apply -f ../argocd_application.yaml

GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)
echo "${GREEN}GitLab Root Password: $ROOT_PASSWORD${RESET}"
echo "${BLUE}Argo CD Admin Password: $ADMIN_PASSWORD${RESET}"