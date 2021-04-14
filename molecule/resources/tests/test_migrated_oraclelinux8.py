import pytest


@pytest.mark.parametrize('name', [
    'oracle-epel-release-el8', 'oracle-logos-httpd', 'oracle-logos'
])
def test_centos_oracle_packages_removed(host, name):
    pkg = host.package(name)
    assert not pkg.is_installed
