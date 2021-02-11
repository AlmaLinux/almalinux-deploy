source almalinux-deploy.sh


setup() {
    if [[ ${BATS_TEST_DESCRIPTION} =~ 'get_os_release_var' ]]; then
        MOCKED_OS_RELEASE=$(tempfile -d ${BATS_TMPDIR} -p osrel_)
    fi
}

teardown() {
    if [[ ${BATS_TEST_NAME} =~ 'get_os_release_var' ]]; then
        rm -f ${MOCKED_OS_RELEASE}
    fi
}

# assert_get_system_arch_fails() {
#     local -r arch="${1}"
#     eval "function uname() { echo ${arch}; }"
#     export -f uname
#     run get_system_arch
#     [[ ${status} -ne 0 ]]
#     [[ ${output} =~ 'Error' ]]
# }


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


# @test 'get_system_arch fails on i686 architecture' {
#     assert_get_system_arch_fails i686
# }


# @test 'get_system_arch fails on armv7l architecture' {
#     assert_get_system_arch_fails armv7l
# }


# @test 'get_system_arch fails on aarch64 architecture' {
#     assert_get_system_arch_fails aarch64
# }


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
    [[ ${output} == ${ALMA_RELEASE_URL} ]]
}

@test 'assert_supported_system passes on CentOS-8 x86_64' {
    run assert_supported_system 'centos' '8' 'x86_64'
    [[ ${status} -eq 0 ]]
}

@test 'assert_supported_system fails on unsupported architectures' {
    for arch in 'i686' 'aarch64' 'armv7l'; do
        run assert_supported_system 'centos' '8' "${arch}"
        [[ ${status} -ne 0 ]]
        [[ ${output} == *"architecture is not supported" ]]
    done
}

@test 'assert_supported_system fails on non-EL8' {
    for os_version in 6 7 9; do
        run assert_supported_system 'centos' "${os_version}" 'x86_64'
        [[ ${status} -ne 0 ]]
        [[ ${output} == *"EL${os_version} is not supported" ]]
    done
}

@test 'assert_supported_system fails on non-centos' {
    for os_id in 'fedora' 'ol' 'rhel'; do
        run assert_supported_system "${os_id}" '8' 'x86_64'
        [[ ${status} -ne 0 ]]
        [[ ${output} == *"migration from ${os_id} is not supported" ]]
    done
}
