mkdir -p /home/vagrant/.ssh
echo "$1" >> /home/vagrant/.ssh/authorized_keys

SERVER_IP="192.168.56.110"

KEY_PATH="/vagrant/.vagrant/machines/ael-korcS/virtualbox/private_key"

SSH_OPTS="-o StrictHostKeyChecking=no"

TOKEN=$(ssh $SSH_OPTS -i "$KEY_PATH" vagrant@$SERVER_IP "sudo cat /var/lib/rancher/k3s/server/node-token")

# install k3s
curl -sfL https://get.k3s.io | K3S_URL=https://$SERVER_IP:6443 K3S_TOKEN=$TOKEN sh -