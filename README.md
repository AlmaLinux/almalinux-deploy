# almalinux-deploy

An EL to AlmaLinux migration tool.

## Usage

In order to convert your EL8 and EL9 operating systems to AlmaLinux do the following:

1. CentOS 8.4 or 8.5 is required to convert to AlmaLinux.  It is recommended to update to 8.5 prior to moving to
AlmaLinux but not required if you are on at least CentOS 8.4.  Rebooting after the updates is recommended if your system
received new updates.

    ```shell
    sudo dnf update -y
    sudo reboot
    ```

  - As of January 31, 2022 the CentOS 8 mirrorlists are offline.  In order to successfully perform `dnf update -y`
you need to update your `dnf` config files to point to a valid mirror.  You can use the following `sed` commands for
convenience to restore `dnf` to a functional state that will let you update to 8.5 and subsequently AlmaLinux.
    - ```bash
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[baseos\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/BaseOS/$basearch/os' /etc/yum.repos.d/CentOS-Linux-BaseOS.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[appstream\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/AppStream/$basearch/os' /etc/yum.repos.d/CentOS-Linux-AppStream.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[cr\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/ContinuousRelease/$basearch/os' /etc/yum.repos.d/CentOS-Linux-ContinuousRelease.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[devel\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/Devel/$basearch/os' /etc/yum.repos.d/CentOS-Linux-Devel.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[extras\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/extras/$basearch/os' /etc/yum.repos.d/CentOS-Linux-Extras.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[fasttrack\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/fasttrack/$basearch/os' /etc/yum.repos.d/CentOS-Linux-FastTrack.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[ha\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/HighAvailability/$basearch/os' /etc/yum.repos.d/CentOS-Linux-HighAvailability.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[plus\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/centosplus/$basearch/os' /etc/yum.repos.d/CentOS-Linux-Plus.repo
      sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[powertools\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/PowerTools/$basearch/os' /etc/yum.repos.d/CentOS-Linux-PowerTools.repo
      ```
    - You can use the `-f` flag (ie `sudo bash almalinux-deploy.sh -f`) to handle this for you.
2. Back up of the system. We didn't test all possible scenarios so there
   is a risk that something goes wrong. In such a situation you will have a
   restore point.

3. Download the [almalinux-deploy.sh](almalinux-deploy.sh) script:

   ```shell
   curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh
   ```

4. Run the script and check its output for errors:

   ```shell
   $ sudo bash almalinux-deploy.sh
     ...
     Migration to AlmaLinux is completed
   ```

5. Reboot is recommended to boot with AlmaLinux kernel:

    ```shell
    sudo reboot
    ```

6. Ensure that your system was successfully converted:

   ```shell
   # check release file
   $ cat /etc/redhat-release
   AlmaLinux release 8.5 (Arctic Sphynx)

   # check that the system boots AlmaLinux kernel by default
   $ sudo grubby --info DEFAULT | grep AlmaLinux
   title="AlmaLinux (4.18.0-348.el8.x86_64) 8.5 (Arctic Sphynx)"
   ```

7. Thank you for choosing AlmaLinux!

## Roadmap

* [x] CentOS 8 support.
* [x] Write debug information to a log file for failed migration analysis.
* [x] Oracle Linux 8 support.
* [x] RHEL 8 support.
* [x] Rocky Linux 8 support.
* [x] Virtuozzo Linux (VZLinux) 8 support.
* [x] DirectAdmin control panel support.
* [x] cPanel control panel support.
* [x] Plesk control panel support.
* [x] CentOS Stream 8 downgrade support with `-d` option.
* [x] EL9 (RHEL 9, Oracle Linux 9, Rocky Linux 9, Virtuozzo Linux 9) and CentOS Stream 9 support
* [ ] Cover all common scenarios with tests.
* [ ] Add OpenNebula support to Molecule test suite.

## Get Involved

Any contribution is welcome:

* Find and [report](https://github.com/AlmaLinux/almalinux-deploy/issues) bugs.
* Submit pull requests with bug fixes, improvements and new tests.
* Test it on different configurations and share your thoughts in
  [discussions](https://github.com/AlmaLinux/almalinux-deploy/discussions).

Technology stack:

* The migration script is written in [Bash](https://www.gnu.org/software/bash/).
* We use [Bats](https://github.com/bats-core/bats-core) for unit tests.
* Functional tests are implemented using
  [Molecule](https://github.com/ansible-community/molecule),
  [Ansible](https://github.com/ansible/ansible) and
  [Testinfra](https://github.com/pytest-dev/pytest-testinfra). Virtual machines
  are powered by [Vagrant](https://www.vagrantup.com/) and
  [VirtualBox](https://www.virtualbox.org/).
 * CI/CD: Jenkins and an agent with [Vagrant Libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt).

To run the functional tests do the following:

1. Install Vagrant and VirtualBox.
2. Install requirements from the requirements.txt file.
3. Run `molecule test --all` in the project root.

## License

Licensed under the GPLv3 license, see the [LICENSE](LICENSE) file for details.
