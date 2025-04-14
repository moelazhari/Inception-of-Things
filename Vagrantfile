# Service configuration reference
SERVICES = {
  'mazhari' => {
    ip: '192.168.56.110',
    hostname: 'mazhariS',
  },
  'ahammout' => {
    ip: '192.168.56.111',
    hostname: 'ahammoutSW',
  },
}

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.box_version = "0.1.0"

  SERVICES.each do |name, machine|
    config.vm.define name do |node|
      node.vm.hostname = machine[:hostname]
      node.vm.network "private_network", ip: machine[:ip]

      node.vm.provider "virtualbox" do |vb|
        vb.memory = 512
        vb.cpus = 1
      end

    end
  end
end