#!/bin/bash
set -e

SERVER_IP="192.168.56.110"
KEY_PATH="/vagrant/.vagrant/machines/mazhariS/virtualbox/private_key"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

TOKEN=$(ssh $SSH_OPTS -i "$KEY_PATH" vagrant@$SERVER_IP "sudo cat /var/lib/rancher/k3s/server/node-token")

curl -sfL https://get.k3s.io |  INSTALL_K3S_EXEC="agent --server https://${SERVER_IP}:6443 --token ${TOKEN}" sh -