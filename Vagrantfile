# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box_check_update = true

  # Disable the builtin syncing functionality and use a file provisioner
  # instead. This allows us to use RHEL boxes that do not come with rsync or
  # other easy ways of getting the files into a box.
  config.vm.synced_folder '.', '/vagrant', disabled: true
  config.vm.provision :file, source: File.expand_path('../', __FILE__), destination: '/home/vagrant/almalinux-deploy'

  config.vm.provider "libvirt" do |libvirt|
    libvirt.random_hostname = true
    libvirt.uri = 'qemu:///system'
  end

  config.vm.define "centos8-4" do |i|
    i.vm.box = "generic/centos8"
    i.vm.hostname = "centos8-4"
    i.vm.box_version = "3.4.6"
  end

  config.vm.define "centos8-5" do |i|
    i.vm.box = "generic/centos8"
    i.vm.hostname = "centos8-5"
    i.vm.box_version = "3.6.4"
  end

  config.vm.define "centos8stream" do |i|
    i.vm.box = "generic/centos8s"
    i.vm.hostname = "centos8stream"
  end

  config.vm.define "centos9stream" do |i|
    i.vm.box = "generic/centos9s"
    i.vm.hostname = "centos9stream"
  end

  config.vm.define "oracle8-4" do |i|
    i.vm.box = "generic/oracle8"
    i.vm.hostname = "oracle8-4"
    i.vm.box_version = "3.4.6"
  end

  config.vm.define "oracle8-5" do |i|
    i.vm.box = "generic/oracle8"
    i.vm.hostname = "oracle8-5"
    i.vm.box_version = "3.6.4"
  end

  config.vm.define "oracle8" do |i|
    i.vm.box = "generic/oracle8"
    i.vm.hostname = "oracle8"
  end

  config.vm.define "oracle9" do |i|
    i.vm.box = "eurolinux-vagrant/oracle-linux-9"
    i.vm.hostname = "oracle9"
  end

  config.vm.define "rhel8-4" do |i|
    i.vm.box = "generic/rhel8"
    i.vm.hostname = "rhel8-4"
    i.vm.box_version = "3.4.6"
  end

  config.vm.define "rhel8-5" do |i|
    i.vm.box = "generic/rhel8"
    i.vm.hostname = "rhel8-5"
    i.vm.box_version = "3.6.4"
  end

  config.vm.define "rhel8" do |i|
    i.vm.box = "generic/rhel8"
    i.vm.hostname = "rhel8"
  end

  config.vm.define "rhel9" do |i|
    i.vm.box = "generic/rhel9"
    i.vm.hostname = "rhel9"
  end

  config.vm.define "rocky8-4" do |i|
    i.vm.box = "generic/rocky8"
    i.vm.hostname = "rocky8-4"
    i.vm.box_version = "3.4.6"
  end

  config.vm.define "rocky8-5" do |i|
    i.vm.box = "generic/rocky8"
    i.vm.hostname = "rocky8-5"
    i.vm.box_version = "3.6.4"
  end

  config.vm.define "rocky8" do |i|
    i.vm.box = "generic/rocky8"
    i.vm.hostname = "rocky8"
  end

  config.vm.define "rocky9" do |i|
    i.vm.box = "generic/rocky9"
    i.vm.hostname = "rocky9"
  end
end

