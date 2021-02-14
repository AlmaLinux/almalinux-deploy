import pytest


def test_is_almalinux_distro(host):
    assert host.system_info.distribution == 'almalinux'


def test_release_package_installed(host):
    pkg = host.package('almalinux-release')
    assert pkg.is_installed


def test_grub_default(host):
    with host.sudo():
        host.run_expect((0,), 'grubby --info DEFAULT | grep AlmaLinux')


@pytest.mark.parametrize('name', [
    'centos-linux-release', 'centos-gpg-keys', 'centos-linux-repos',
    'libreport-plugin-rhtsupport'
])
def test_centos_packages_removed(host, name):
    pkg = host.package(name)
    assert not pkg.is_installed
