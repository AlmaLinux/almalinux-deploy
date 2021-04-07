import pytest


def test_release_package_installed(host):
    pkg = host.package('kernel-uek')
    assert not pkg.is_installed
    #assert pkg.version.startswith('5.4')
    # '5.4.175.4.17'


@pytest.mark.parametrize('name', [
    'kernel', 'kernel-core', 'kernel-modules', 'kernel-tools', 'kernel-tools-libs'
])
def test_kernel_packages_installed_and_have_correct_vendor(host, name):
    pkg = host.package(name)
    assert pkg.is_installed
    host.run_expect((0,), 'rpm -qi ' + name + ' | grep "Vendor *: *AlmaLinux"')
    
    
def test_grub_default(host):
    with host.sudo():
        host.run_expect((0,), 'grubby --info DEFAULT | grep AlmaLinux')

