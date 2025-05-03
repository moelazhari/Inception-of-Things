

mkdir -p /home/vagrant/.ssh
echo "$1" >> /home/vagrant/.ssh/authorized_keys

# install k3s
curl -sfL https://get.k3s.io | sh -
sudo cp /var/lib/rancher/k3s/server/token /node-token/