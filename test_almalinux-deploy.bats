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
    for arch in 'i686' 'ppc64le' 'armv7l'; do
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
