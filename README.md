# almalinux-deploy

An EL to AlmaLinux migration tool.


## Usage

In order to convert your EL8 operating system to AlmaLinux do the following:

1. Make a backup of the system. We didn't test all possible scenarios so there
   is a risk that something goes wrong. In such a situation you will have a
   restore point.
2. Download the [almalinux-deploy.sh](almalinux-deploy.sh) script:
   ```shell
   $ curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh
   ```
3. Run the script and check its output for errors. You will need to reboot the
   system at the end.
   ```shell
   $ sudo bash almalinux-deploy.sh
     ...
     Migration to AlmaLinux is completed, please reboot the system
   
   $ reboot
   ```
4. Ensure that your system was successfully converted:
   ```shell
   # check release file
   $ cat /etc/redhat-release 
   AlmaLinux release 8.3 (Purple Manul)
   
   # check that the system boots AlmaLinux kernel by default
   $ sudo grubby --info DEFAULT | grep AlmaLinux
   title="AlmaLinux (4.18.0-240.el8.x86_64) 8"
   ```
5. Thank you for choosing AlmaLinux!


## Roadmap

* [x] CentOS 8 support.
* [ ] Write debug information to a log file for failed migration analysis.
* [ ] Oracle Linux 8 support.
* [ ] DirectAdmin control panel support.
* [ ] cPanel control panel support (blocked from cPanel side).
* [ ] Plesk control panel support (blocked from Plesk side).
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

To run the functional tests do the following:

1. Install Vagrant and VirtualBox.
2. Install requirements from the requirements.txt file.
3. Run `molecule test --all` in the project root.


## License

Licensed under the GPLv3 license, see the [LICENSE](LICENSE) file for details.
