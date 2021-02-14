import pytest

ALMA_BRANDED_PACKAGES = ['almalinux-backgrounds', 'almalinux-logos',
                         'almalinux-indexhtml']

CENTOS_BRANDED_PACKAGES = ['centos-backgrounds', 'centos-logos',
                           'centos-indexhtml']


@pytest.mark.parametrize('name', ALMA_BRANDED_PACKAGES)
def test_alma_gui_packages_installed(host, name):
    pkg = host.package(name)
    assert pkg.is_installed


@pytest.mark.parametrize('name', CENTOS_BRANDED_PACKAGES)
def test_centos_gui_packages_removed(host, name):
    pkg = host.package(name)
    assert not pkg.is_installed

