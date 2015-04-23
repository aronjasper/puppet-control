# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure(2) do |config|

  if not defined? VagrantPlugins::LibrarianPuppet
    puts "librarian-puppet plugin is not installed."
    puts "You can install it with `vagrant plugin install vagrant-librarian-puppet`"
    puts "You may have to run `librarian-puppet` on your host machine if you have not already"
  end
  
  config.vm.box = "landregistry/centos"
  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "manifests"
    puppet.manifest_file = "site.pp"
    puppet.hiera_config_path = "hiera.vagrant.yaml"
    puppet.working_directory = "/tmp/vagrant-puppet"
    puppet.options = '--environment=development'
    puppet.module_path = ["site", "modules"]
    puppet.facter = {
      'is_vagrant'   => true,
    }
  end

  if defined? VagrantPlugins::Cachier
    config.cache.scope = :box
    config.cache.auto_detect = true
  else
    puts "Yum cache is available (vagrant plugin install vagrant-cachier)."
    puts "You really want to install vagrant-cachier.  Vagrant build go zoooooom."
    puts "Continuing in slow mode..."
  end


  config.vm.define "charges" do |charges|
    charges.vm.host_name = "charges"
    charges.vm.provision "shell", inline: "yum install postgresql-server -y"
    charges.vm.provider :virtualbox do |v|
      v.customize ['modifyvm', :id, '--memory', '2048']
    end
  end
  
end