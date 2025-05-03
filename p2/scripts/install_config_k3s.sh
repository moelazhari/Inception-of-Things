#!/bin/bash
set -e

mkdir -p /home/vagrant/.ssh
echo "$1" >> /home/vagrant/.ssh/authorized_keys

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -

until kubectl get nodes &> /dev/null; do
    sleep 2
done

kubectl apply -f /vagrant/configs