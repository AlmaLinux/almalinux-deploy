#!/bin/bash
# Description: EL to AlmaLinux migration script.
# License: GPLv3.
# Environment variables:
#   ALMA_RELEASE_URL - almalinux-release package download URL.
#   ALMA_PUBKEY_URL - RPM-GPG-KEY-AlmaLinux download URL.

set -euo pipefail

exec > >(tee /var/log/almalinux-deploy.log)

BASE_TMP_DIR='/root'
OS_RELEASE_PATH='/etc/os-release'
REDHAT_RELEASE_PATH='/etc/redhat-release'
# AlmaLinux OS 8.3
MINIMAL_SUPPORTED_VERSION='8'
VERSION='0.1.9'

BRANDING_PKGS="centos-backgrounds centos-logos centos-indexhtml \
                centos-logos-ipa centos-logos-httpd \
                oracle-backgrounds oracle-logos oracle-indexhtml \
                oracle-logos-ipa oracle-logos-httpd \
                oracle-epel-release-el8 \
                redhat-backgrounds redhat-logos redhat-indexhtml \
                redhat-logos-ipa redhat-logos-httpd"

REMOVE_PKGS="centos-linux-release centos-gpg-keys centos-linux-repos \
                centos-stream-release centos-stream-repos kpatch kpatch-dnf\
                libreport-plugin-rhtsupport libreport-rhel insights-client \
                libreport-rhel-anaconda-bugzilla libreport-rhel-bugzilla \
                oraclelinux-release oraclelinux-release-el8 \
                redhat-release redhat-release-eula"

# Reports a completed step using a green color.
#
# $1 - Message to print.
report_step_done() {
    local -r message="${1}"
    printf '\033[0;32m%-70sOK\033[0m\n' "${message}"
}

# Reports a failed step using a red color.
#
# $1 - Message to print.
# $2 - Additional information to show (optional).
report_step_error() {
    local -r message="${1}"
    local -r trace="${2:-}"
    printf '\033[0;31m%-70sERROR\033[0m\n' "${message}" 1>&2
    if [[ -n "${trace}" ]]; then
        echo "${trace}" | while read -r line; do
            printf '    %s\n' "${line}" 1>&2
        done
    fi
}

# Prints program usage information.
show_usage() {
    echo -e 'Migrates an EL system to AlmaLinux\n'
    echo -e 'Usage: almalinux-deploy.sh [OPTION]...\n'
    echo '  -h, --help           show this message and exit'
    echo '  -v, --version        print version information and exit'
}

# Terminates the program if it is not run with root privileges
assert_run_as_root() {
    if [[ $(id -u) -ne 0 ]]; then
        report_step_error 'Check root privileges' \
            'Migration tool must be run as root'
        exit 2
    fi
    report_step_done 'Check root privileges'
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

# Detects an operational system version.
#
# $1 - operational system type.
#
# Prints OS version.
get_os_version() {
    local -r os_type="${1}"
    local os_version
    if [[ "${os_type}" == 'centos' ]]; then
        if ! os_version="$(grep -oP 'CentOS\s+(Linux|Stream)\s+release\s+\K(\d+(\.\d+)?)' \
                                    "${REDHAT_RELEASE_PATH}" 2>/dev/null)"; then
            report_step_error "Detect ${os_type} version"
        fi
    else
        os_version="$(get_os_release_var 'VERSION_ID')"
    fi
    echo "${os_version}"
}

# Prints control type and version.
get_panel_info() {
    local panel_type=''
    local panel_version=''
    local -r cpanel_file='/usr/local/cpanel/cpanel'
    local -r plesk_file='/usr/local/psa/version'
    if [[ -x "${cpanel_file}" ]]; then
        panel_type='cpanel'
        panel_version=$("${cpanel_file}" -V 2>/dev/null | grep -oP '^[\d.]+')
    elif [[ -f "${plesk_file}" ]]; then
        panel_type='plesk'
        panel_version=$(grep -oP '^[\d.]+' "${plesk_file}" 2>/dev/null)
    fi
    echo "${panel_type} ${panel_version}"
}

# Terminates the program if a platform is not supported by AlmaLinux.
#
# $1 - Operational system id (ID).
# $2 - Operational system version (e.g. 8 or 8.3).
# $3 - System architecture (e.g. x86_64).
assert_supported_system() {
    local -r os_type="${1}"
    local -r os_version="${2:0:1}"
    local -r arch="${3}"
    if [[ ${arch} != 'x86_64' ]]; then
        report_step_error "Check ${arch} architecture is supported"
        exit 1
    fi
    if [[ ${os_version} -ne ${MINIMAL_SUPPORTED_VERSION:0:1} ]]; then
        report_step_error "Check EL${os_version} is supported"
        exit 1
    fi
    if [[ ${os_type} != 'centos' && ${os_type} != 'almalinux' && \
          ${os_type} != 'ol' && ${os_type} != 'rhel' ]]; then
        report_step_error "Check ${os_type} operating system is supported"
        exit 1
    fi
    report_step_done "Check ${os_type}-${os_version}.${arch} is supported"
}

# Terminates the program if a control panel is not supported by AlmaLinux.
#
# $1 - Control panel type.
# $2 - Control panel version.
assert_supported_panel() {
    local -r panel_type="${1}"
    local -r panel_version="${2}"
    if [[ "${panel_type}" == 'plesk' ]]; then
        report_step_error 'Plesk is not supported yet'
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
    local -r os_version="${1:0:1}"
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
    local -r step='Download RPM-GPG-KEY-AlmaLinux'
    local output
    if ! output=$(curl -f -s -S -o "${pubkey_path}" "${pubkey_url}" 2>&1); then
        report_step_error "${step}" "${output}"
        exit 1
    else
        report_step_done "${step}"
    fi
    rpm --import "${pubkey_path}"
    report_step_done 'Import RPM-GPG-KEY-AlmaLinux to RPM DB'
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
    local output
    if ! output=$(curl -f -s -S -o "${release_path}" "${release_url}" 2>&1); then
        report_step_error 'Download almalinux-release package' "${output}"
        exit 1
    fi
    echo "${release_path}"
}

# Terminates the program if a given RPM package checksum/signature is invalid.
#
# $1 - RPM package path.
assert_valid_package() {
    local -r pkg_path="${1}"
    local output
    if ! output=$(rpm -K "${pkg_path}" 2>&1); then
        report_step_error "Verify $(basename "${pkg_path}") package" \
            "${output}"
        exit 1
    fi
}

# Terminates the program if OS version doesn't match AlmaLinux version.
#
# $1 - OS version.
# $2 - almalinux-release package file path.
assert_compatible_os_version() {
    local -r os_version="${1}"
    local -r release_path="${2}"
    local alma_version
    alma_version=$(rpm -qp --queryformat '%{version}' "${release_path}")

    if [[ "${os_version:2:3}" -lt "${MINIMAL_SUPPORTED_VERSION:2:3}" ]]; then
        report_step_error "Please upgrade your OS from ${os_version} to" \
        "at least ${MINIMAL_SUPPORTED_VERSION} and try again"
        exit 1
    fi
    if [[ "${os_version:2:3}" -gt "${alma_version:2:3}" ]]; then
        report_step_error "Version of you OS ${os_version} is not supported yet"
        exit 1
    fi
}

# Backup /etc/issue* files
backup_issue() {
    for file in $(rpm -Vf /etc/issue | cut -d' ' -f4); do
        if [[ ${file} =~ "/etc/issue" ]]; then
            cp "${file}" "${file}.bak"
        fi
    done
}

# Restore /etc/issue* files
restore_issue() {
    for file in /etc/issue /etc/issue.net; do
        [ ! -f "${file}.bak" ] || mv -f ${file}.bak ${file}
    done
}

# Recursively removes a given directory.
#
# $1 - Directory path.
cleanup_tmp_dir() {
    rm -fr "${1:?}"
}

# Converts a CentOS system to AlmaLinux
#
# $1 - almalinux-release RPM package path.
migrate_from_centos() {
    local -r release_path="${1}"
    local to_remove=''
    local alma_pkg=''
    local output
    # replace CentOS packages with almalinux-release and remove centos-specific
    # packages
    for pkg_name in ${REMOVE_PKGS}; do
        if rpm -q "${pkg_name}" &>/dev/null; then
            to_remove="${to_remove} ${pkg_name}"
        fi
    done
    if [[ -n "${to_remove}" ]]; then
        # shellcheck disable=SC2086
        rpm -e --nodeps --allmatches ${to_remove}
        for pkg_name in ${to_remove}; do
            report_step_done "Remove ${pkg_name} package"
        done
    fi
    [ -d /usr/share/doc/redhat-release ] && rm -r /usr/share/doc/redhat-release
    [ -d /usr/share/redhat-release ] && rm -r /usr/share/redhat-release
    rpm -Uvh "${release_path}"
    report_step_done 'Install almalinux-release package'
    # replace GUI packages
    for pkg_name in ${BRANDING_PKGS}; do
        if rpm -q "${pkg_name}" &>/dev/null; then
            # shellcheck disable=SC2001
            alma_pkg=""
            case ${pkg_name} in
                oracle-epel-release-el8)
                    alma_pkg="epel-release"
                    ;;
                *)
                    # shellcheck disable=SC2001
                    alma_pkg="$(echo "${pkg_name}" | sed 's#centos\|oracle\|redhat#almalinux#')"
                    ;;
            esac
            rpm -e --nodeps "${pkg_name}"
            report_step_done "Remove ${pkg_name} package"
            if ! output=$(dnf install -y "${alma_pkg}" 2>&1); then
                report_step_error "Install ${alma_pkg} package" "${output}"
            fi
            report_step_done "Install ${alma_pkg} package"
        fi
    done
}

# Executes the 'dnf distro-sync -y' command.
#
# Returns the dnf command exit code.
distro_sync() {
    local -r step='Run dnf distro-sync -y'
    local ret_code=0
    dnf distro-sync -y || {
        ret_code=${?}
        report_step_error "${step}. Exit code: ${ret_code}"
    }
    report_step_done "${step}"
    return ${ret_code}
}

install_kernel() {
    if ! output=$(rpm -q kernel 2>&1); then
        if output=$(dnf -y install kernel 2>&1); then
            report_step_done "Install AlmaLinux kernel"
        else
            report_step_error "Install AlmaLinux kernel"
        fi
    fi
}

grub_update() {
    if [ -d /sys/firmware/efi ]; then
        if [ -d /boot/efi/EFI/almalinux ]; then
            grub2-mkconfig -o /boot/efi/EFI/almalinux/grub.cfg
        elif [ -d /boot/efi/EFI/centos ]; then
            grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
        else
            grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        fi
    else
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
}

# Check do we have custom kernel (e.g. kernel-uek) and print warning
check_custom_kernel() {
    local output
    output=$(rpm -qa | grep kernel-uek) || :
    if [ -n "${output}" ]; then
        if [ -x /usr/bin/mokutil ] && /usr/bin/mokutil --sb-state 2>&1 | grep -q enabled; then
            echo -ne "\n!! [31;1mThere are kernels left from previous operating system
that won't boot in Secure Boot mode anymore[0m:\n"
        else
            echo "There are kernels left from previous operating system:"
        fi
        # shellcheck disable=SC2001,SC2086
        echo "$output" | sed 's# #\n#'
        echo ""
        echo "If you don't need them, you can remove them by using the 'dnf remove" \
            "${output}' command"
    fi
}

# Backup and restore symbol links from java-openjdk-headless package
# https://bugzilla.redhat.com/show_bug.cgi?id=1200302
javaBackup=$(mktemp /tmp/java_backup.XXXXXX)

backup_java_links() {
    local java_alternatives
    # do nothing if java alternatives don't exist
    if java_alternatives="$(update-alternatives --display java)"; then
        echo "${java_alternatives}" | grep -oP '(?<=slave ).*' | sed -e 's#\(\S*\): \(\S*\)#\2 \1#' > "${javaBackup}"
    fi
}

restore_java_links() {
    # do nothing if a backup of java alternatives symlinks doesn't exist
    [[ ! -s "${javaBackup}" ]] && return 0
    pushd /etc/alternatives
    while IFS= read -r line; do
        if [[ -n ${line} ]]; then
            forig=$(echo "${line}" | cut -f1 -d' ')
            flink=$(echo "${line}" | cut -f2 -d' ')
            if [[ ! -e ${flink} ]]; then
                ln -s "${forig}" "${flink}"
            fi
        fi
    done < "${javaBackup}"
    popd
}

main() {
    local arch
    local os_version
    local os_type
    local release_url
    local tmp_dir
    local release_path
    local panel_type
    local panel_version
    assert_run_as_root
    arch="$(get_system_arch)"
    os_type="$(get_os_release_var 'ID')"
    os_version="$(get_os_version "${os_type}")"
    #os_version="$(get_os_release_var 'VERSION_ID')"
    #os_version="${os_version:0:1}"
    assert_supported_system "${os_type}" "${os_version}" "${arch}"

    read -r panel_type panel_version < <(get_panel_info)
    assert_supported_panel "${panel_type}" "${panel_version}"

    release_url=$(get_release_file_url "${os_version}" "${arch}")
    tmp_dir=$(mktemp -d --tmpdir="${BASE_TMP_DIR}" .alma.XXXXXX)
    # shellcheck disable=SC2064
    trap "cleanup_tmp_dir ${tmp_dir}" EXIT
    install_rpm_pubkey "${tmp_dir}"

    release_path=$(download_release_file "${release_url}" "${tmp_dir}")
    report_step_done 'Download almalinux-release package'

    assert_valid_package "${release_path}"
    report_step_done 'Verify almalinux-release package'

    assert_compatible_os_version "${os_version}" "${release_path}"

    case "${os_type}" in
    almalinux|centos|ol|rhel)
        backup_issue
        migrate_from_centos "${release_path}"
        ;;
    *)
        report_step_error "Migrate ${os_type}: not supported"
        exit 1
        ;;
    esac

    backup_java_links
    distro_sync || exit ${?}
    restore_java_links
    restore_issue
    install_kernel
    grub_update
    check_custom_kernel
    printf '\n\033[0;32mMigration to AlmaLinux is completed\033[0m\n'
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
