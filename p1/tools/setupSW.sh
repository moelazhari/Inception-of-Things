

mkdir -p /home/vagrant/.ssh
echo "$1" >> /home/vagrant/.ssh/authorized_keys

# install k3s
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$(cat /node-token/token) sh -