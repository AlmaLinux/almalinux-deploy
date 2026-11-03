#!/usr/bin/env bats
source almalinux-deploy.sh -t

setup() {
    if [[ ${BATS_TEST_DESCRIPTION} =~ 'get_os_release_var' ]] \
       || [[ ${BATS_TEST_DESCRIPTION} =~ 'get_os_version' ]]; then
        MOCKED_OS_RELEASE=$(mktemp -p ${BATS_TMPDIR} osrel_XXXX )
    fi
}

teardown() {
    if [[ ${BATS_TEST_NAME} =~ 'get_os_release_var' ]] \
       || [[ ${BATS_TEST_DESCRIPTION} =~ 'get_os_version' ]]; then
        rm -f ${MOCKED_OS_RELEASE}
    fi
}

@test 'get_system_arch returns x86_64 architecture' {
    function uname() { echo 'x86_64'; }
    export -f uname
    run get_system_arch
    [[ ${status} -eq 0 ]]
    [[ ${output} == 'x86_64' ]]
}

@test 'get_system_arch returns aarch64 architecture' {
    function uname() { echo 'aarch64'; }
    export -f uname
    run get_system_arch
    [[ ${status} -eq 0 ]]
    [[ ${output} == 'aarch64' ]]
}

@test 'get_system_arch returns ppc64le architecture' {
    function uname() { echo 'ppc64le'; }
    export -f uname
    run get_system_arch
    [[ ${status} -eq 0 ]]
    [[ ${output} == 'ppc64le' ]]
}

@test 'get_system_arch returns s390x architecture' {
    function uname() { echo 's390x'; }
    export -f uname
    run get_system_arch
    [[ ${status} -eq 0 ]]
    [[ ${output} == 's390x' ]]
}

@test 'assert_run_as_root passes for root' {
    function id() { echo 0; }
    export -f id
    run assert_run_as_root
    [[ ${status} -eq 0 ]]
}

@test 'assert_run_as_root fails for user' {
    function id() { echo 1000; }
    export -f id
    run assert_run_as_root
    [[ ${status} -ne 0 ]]
}

@test 'assert_secureboot_disabled fails on enabled Secure Boot' {
    function mokutil() {
        case "$1" in
            '--sb-state' ) echo 'SecureBoot enabled' ;;
        esac
    }
    export -f mokutil
    run assert_secureboot_disabled
    [[ ${status} -ne 0 ]]
}

@test 'assert_secureboot_disabled passes on disabled Secure Boot' {
    function mokutil() {
        case "$1" in
            '--sb-state' ) echo 'SecureBoot disabled' ;;
        esac
    }
    export -f mokutil
    run assert_secureboot_disabled
    [[ ${status} -eq 0 ]]
}

@test 'get_os_release_var extracts VERSION_ID' {
    echo 'VERSION_ID="8"' >> ${MOCKED_OS_RELEASE}
    export OS_RELEASE_PATH="${MOCKED_OS_RELEASE}"
    run get_os_release_var 'VERSION_ID'
    [[ ${status} -eq 0 ]]
    [[ ${output} -eq 8 ]]
}

@test 'get_os_release_var extracts ID' {
    echo 'ID="centos"' >> ${MOCKED_OS_RELEASE}
    export OS_RELEASE_PATH="${MOCKED_OS_RELEASE}"
    run get_os_release_var 'ID'
    [[ ${status} -eq 0 ]]
    [[ ${output} == 'centos' ]]
}

@test 'get_os_release_var fails on missing variable' {
    export OS_RELEASE_PATH="${MOCKED_OS_RELEASE}"
    run get_os_release_var 'VERSION_ID'
    [[ ${status} -ne 0 ]]
    [[ ${output} =~ 'Error' ]]
}

@test 'get_release_file_url returns default URL' {
    run get_release_file_url '8' 'x86_64'
    [[ ${status} -eq 0 ]]
    [[ ${output} == 'https://repo.almalinux.org/almalinux/almalinux-release-latest-8.x86_64.rpm' ]]
}

@test 'get_release_file_url returns ALMA_RELEASE_URL environment variable' {
    export ALMA_RELEASE_URL='https://example.com/almalinux-release-latest-8.aarch64.rpm'
    run get_release_file_url '8' 'aarch64'
    [[ ${status} -eq 0 ]]
    [[ ${output} == "${ALMA_RELEASE_URL}" ]]
}

@test 'assert_supported_system passes on CentOS-8 x86_64' {
    for os_version in 8 9; do
      run assert_supported_system 'centos' "${os_version}" 'x86_64'
      [[ ${status} -eq 0 ]]
    done
}

@test 'assert_supported_system fails on unsupported architectures' {
    for arch in 'i686' 'armv7l'; do
        run assert_supported_system 'centos' '8' "${arch}"
        [[ ${status} -ne 0 ]]
        [[ ${output} =~ 'ERROR' ]]
    done
}

@test 'assert_supported_system fails on non-EL8' {
    for os_version in 6 7; do
        run assert_supported_system 'centos' "${os_version}" 'x86_64'
        [[ ${status} -ne 0 ]]
        [[ ${output} =~ 'ERROR' ]]
    done
}

@test 'assert_supported_system fails on unsupported distributions' {
    for os_id in 'fedora'; do
        run assert_supported_system "${os_id}" '8' 'x86_64'
        [[ ${status} -ne 0 ]]
        [[ ${output} =~ 'ERROR' ]]
    done
}

@test 'get_os_version detects CentOS 8.2 Core' {
    echo 'CentOS Linux release 8.2.2004 (Core)' >> ${MOCKED_OS_RELEASE}
    export REDHAT_RELEASE_PATH="${MOCKED_OS_RELEASE}"
    run get_os_version 'centos'
    [[ ${status} -eq 0 ]]
    [[ ${output} == '8.2' ]]
}

@test 'get_os_version detects CentOS 8.3' {
    echo 'CentOS Linux release 8.3.2011' >> ${MOCKED_OS_RELEASE}
    export REDHAT_RELEASE_PATH="${MOCKED_OS_RELEASE}"
    run get_os_version 'centos'
    [[ ${status} -eq 0 ]]
    [[ ${output} == '8.3' ]]
}

@test 'get_os_version reads OS_RELEASE' {
    echo 'VERSION_ID="8"' >> ${MOCKED_OS_RELEASE}
    export OS_RELEASE_PATH="${MOCKED_OS_RELEASE}"
    run get_os_version 'weirdos'
    [[ ${status} -eq 0 ]]
    [[ ${output} == '8' ]]
}

# Mocks for assert_compatible_os_version: no stage markers, almalinux-release 8.10
#
# $1 - NAME from /etc/os-release (default: CentOS Linux).
mock_compatible_os_version() {
    MOCKED_OS_NAME="${1:-CentOS Linux}"
    function get_status_of_stage() { return 1; }
    function save_status_of_stage() { :; }
    function rpm() { echo '8.10'; }
    function get_os_release_var() { echo "${MOCKED_OS_NAME}"; }
    export MOCKED_OS_NAME
    export -f get_status_of_stage save_status_of_stage rpm get_os_release_var
}

@test 'assert_compatible_os_version fails on EL 8.3' {
    mock_compatible_os_version
    run assert_compatible_os_version '8.3' 'mock-release.rpm'
    [[ ${status} -eq 1 ]]
    [[ ${output} == *'at least 8.4'* ]]
}

@test 'assert_compatible_os_version passes on EL 8.4' {
    mock_compatible_os_version
    run assert_compatible_os_version '8.4' 'mock-release.rpm'
    [[ ${status} -eq 0 ]]
}

@test 'assert_compatible_os_version passes on EL 8.10' {
    mock_compatible_os_version
    run assert_compatible_os_version '8.10' 'mock-release.rpm'
    [[ ${status} -eq 0 ]]
}

@test 'assert_compatible_os_version passes on EL 9.0' {
    mock_compatible_os_version
    run assert_compatible_os_version '9.0' 'mock-release.rpm'
    [[ ${status} -eq 0 ]]
}

@test 'assert_compatible_os_version passes on EL 9.1' {
    mock_compatible_os_version
    run assert_compatible_os_version '9.1' 'mock-release.rpm'
    [[ ${status} -eq 0 ]]
}

@test 'assert_compatible_os_version passes on EL 10.0' {
    mock_compatible_os_version
    run assert_compatible_os_version '10.0' 'mock-release.rpm'
    [[ ${status} -eq 0 ]]
}

@test 'assert_compatible_os_version passes on CentOS Stream 8' {
    mock_compatible_os_version 'CentOS Stream'
    run assert_compatible_os_version '8' 'mock-release.rpm'
    [[ ${status} -eq 0 ]]
}
