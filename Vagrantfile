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
  end

  config.vm.define "centos8-4" do |i|
    i.vm.box = "eurolinux-vagrant/centos-8"
    i.vm.hostname = "centos8-4"
    i.vm.box_version = "8.4.5"
  end

  config.vm.define "centos8-5" do |i|
    i.vm.box = "eurolinux-vagrant/centos-8"
    i.vm.hostname = "centos8-5"
    i.vm.box_version = "8.5.3"
  end

  config.vm.define "centos8" do |i|
    i.vm.box = "eurolinux-vagrant/centos-8"
    i.vm.hostname = "centos8"
  end

  config.vm.define "oracle8-5" do |i|
    i.vm.box = "eurolinux-vagrant/oracle-linux-8"
    i.vm.hostname = "oracle8-5"
    i.vm.box_version = "8.5.11"
  end

  config.vm.define "oracle8" do |i|
    i.vm.box = "eurolinux-vagrant/oracle-linux-8"
    i.vm.hostname = "oracle8"
  end

  config.vm.define "generic-rhel8" do |i|
    i.vm.box = "generic/rhel8"
    i.vm.hostname = "generic-rhel8"
  end

  config.vm.define "rockylinux8-4" do |i|
    i.vm.box = "eurolinux-vagrant/rocky-8"
    i.vm.hostname = "rockylinux8-4"
    i.vm.box_version = "8.4.6"
  end

  config.vm.define "rockylinux8-5" do |i|
    i.vm.box = "eurolinux-vagrant/rocky-8"
    i.vm.hostname = "rockylinux8-5"
    i.vm.box_version = "8.5.11"
  end

  config.vm.define "rockylinux8" do |i|
    i.vm.box = "eurolinux-vagrant/rocky-8"
    i.vm.hostname = "rockylinux8"
  end

end

