#!/bin/bash
# Description: EL to AlmaLinux migration script.
# License: GPLv3.
# Environment variables:
#   ALMA_RELEASE_URL - almalinux-release package download URL.
#   ALMA_PUBKEY_URL - RPM-GPG-KEY-AlmaLinux download URL.

set -euo pipefail

VERSION='0.1.0'
OS_RELEASE_PATH='/etc/os-release'
BASE_TMP_DIR='/root'


# Prints an error message to stderr.
show_error() {
    local -r message="${1}"
    echo "Error: ${message}" >&2
}


show_usage() {
    echo -e 'Migrates an EL system to AlmaLinux\n'
    echo -e 'Usage: almalinux-deploy.sh [OPTION]...\n'
    echo '  -h, --help           show this message and exit'
    echo '  -v, --version        print version information and exit'
}

# Terminates the program if it is not run with root privileges
assert_run_as_root() {
    if [[ $(id -u) -ne 0 ]]; then
        echo 'Error: the migration tool must be run as root' >&2
        exit 2
    fi
}

# Prints a system architecture.
get_system_arch() {
    uname -i
}

# Reads a variable value from /etc/os-release.
#
# $1 - variable name.
#
# Returns the variable value.
get_os_release_var() {
    local -r var="${1}"
    local val
    if ! val="$(grep -oP "^${var}=\"\K.*?(?=\")" "${OS_RELEASE_PATH}")"; then
        echo "Error: ${var} is not found in ${OS_RELEASE_PATH}" >&2
        exit 1
    fi
    echo "${val}"
}

# Terminates the program if a platform is not supported by AlmaLinux.
#
# $1 - Operational system id (ID).
# $2 - Operational system version (VERSION_ID).
# $3 - System architecture (e.g. x86_64).
assert_supported_system() {
    local -r os_id="${1}"
    local -r os_version="${2}"
    local -r arch="${3}"
    if [[ ${arch} != 'x86_64' ]]; then
        show_error "${arch} architecture is not supported"
        exit 1
    fi
    if [[ ${os_version} -ne 8 ]]; then
        show_error "EL${os_version} is not supported"
        exit 1
    fi
    if [[ ${os_id} != 'centos' ]]; then
        show_error "migration from ${os_id} is not supported"
        exit 1
    fi
}


# Returns a latest almalinux-release RPM package download URL.
#
# $1 - AlmaLinux major version (e.g. 8).
# $2 - System architecture (e.g. x86_64).
#
# Prints almalinux-release RPM package download URL.
get_release_file_url() {
    local -r os_version="${1}"
    local -r arch="${2}"
    echo "${ALMA_RELEASE_URL:-https://repo.almalinux.org/almalinux/almalinux-release-latest-${os_version}.${arch}.rpm}"
}

# Downloads and installs the AlmaLinux public PGP key.
#
# $1 - Temporary directory path.
install_rpm_pubkey() {
    local -r tmp_dir="${1}"
    local -r pubkey_url="${ALMA_PUBKEY_URL:-https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux}"
    local -r pubkey_path="${tmp_dir}/RPM-GPG-KEY-AlmaLinux"
    echo -e "Installing AlmaLinux public key: ${pubkey_url}"
    curl -s -o "${pubkey_path}" "${pubkey_url}"
    rpm --import "${pubkey_path}"
    rm -f "${pubkey_path}"
}

# Downloads almalinux-release package.
#
# $1 - almalinux-release package download URL.
# $2 - Temporary directory path.
#
# Prints downloaded file path.
download_release_file() {
    local -r release_url="${1}"
    local -r tmp_dir="${2}"
    local -r release_path="${tmp_dir}/almalinux-release-latest.rpm"
    curl -s -o "${release_path}" "${release_url}"
    echo "${release_path}"
}

# Terminates the program if a given RPM package checksum/signature is invalid.
#
# $1 - RPM package path.
assert_valid_package() {
    local -r pkg_path="${1}"
    local output
    if ! output=$(rpm -K "${pkg_path}"); then
        show_error "${output}"
        exit 1
    fi
}


cleanup_tmp_dir() {
    rm -fr "${1:?}"
}


migrate_from_centos() {
    local -r release_path="${1}"
    local to_remove=''
    # replace CentOS packages with almalinux-release
    for pkg_name in centos-linux-release centos-gpg-keys centos-linux-repos; do
        if rpm -q "${pkg_name}" &>/dev/null; then
            to_remove="${to_remove} ${pkg_name}"
        fi
    done
    if [[ -n "${to_remove}" ]]; then
        echo "Removing CentOS packages: ${to_remove}"
        # shellcheck disable=SC2086
        rpm -e --nodeps ${to_remove}
    fi
    echo "Installing almalinux-release"
    rpm -Uvh "${release_path}"
}


distro_sync() {
    local ret_code=0
    echo 'Reinstalling packages from AlmaLinux repositories: dnf distro-sync -y'
    dnf distro-sync -y || {
        ret_code=${?}
        show_error "dnf distro-sync failed with ${ret_code} exit code"
    }
    return ${ret_code}
}


main() {
    local arch
    local os_version
    local os_id
    local release_url
    local tmp_dir
    local release_path
    assert_run_as_root
    arch="$(get_system_arch)"
    os_version="$(get_os_release_var 'VERSION_ID')"
    os_version="${os_version:0:1}"
    os_id="$(get_os_release_var 'ID')"
    assert_supported_system "${os_id}" "${os_version}" "${arch}"
    release_url=$(get_release_file_url "${os_version}" "${arch}")
    tmp_dir=$(mktemp -d --tmpdir="${BASE_TMP_DIR}" .alma.XXXXXX)
    # shellcheck disable=SC2064
    trap "cleanup_tmp_dir ${tmp_dir}" EXIT
    install_rpm_pubkey "${tmp_dir}"

    echo "Downloading almalinux-release package: ${release_url}"
    release_path=$(download_release_file "${release_url}" "${tmp_dir}")

    echo "Verifying almalinux-release package: ${release_path}"
    assert_valid_package "${release_path}"
    
    case "${os_id}" in
    centos)
        migrate_from_centos "${release_path}"
        ;;
    *)
        show_error "${os_id} is not supported"
        exit 1
        ;;
    esac

    distro_sync || exit ${?}

    echo 'Migration to AlmaLinux is completed, please reboot the system'
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    for opt in "$@"; do
        case ${opt} in
        -h | --help)
            show_usage
            exit 0
            ;;
        -v | --version)
            echo "${VERSION}"
            exit 0
            ;;
        *)
            echo "Error: unknown option ${opt}" >&2
            exit 2
            ;;
        esac
    done

    main
fi
