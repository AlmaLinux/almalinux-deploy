#!/bin/bash

# Description: EL to AlmaLinux migration script.
# License: GPLv3.
# Environment variables:
#   ALMA_RELEASE_URL - almalinux-release package download URL.
#   ALMA_PUBKEY_URL - RPM-GPG-KEY-AlmaLinux download URL.

set -euo pipefail

BASE_TMP_DIR='/root'
OS_RELEASE_PATH='/etc/os-release'
REDHAT_RELEASE_PATH='/etc/redhat-release'
STAGE_STATUSES_DIR='/var/run/almalinux-deploy-statuses'
ALT_ADM_DIR="/var/lib/alternatives"
BAK_DIR="/tmp/alternatives_backup"
ALT_DIR="/etc/alternatives"

# AlmaLinux OS 8.5
MINIMAL_SUPPORTED_VERSION='8.4'
VERSION='0.1.13'
DOWNGRADE='NO'

BRANDING_PKGS=("centos-backgrounds" "centos-logos" "centos-indexhtml" \
                "centos-logos-ipa" "centos-logos-httpd" \
                "oracle-backgrounds" "oracle-logos" "oracle-indexhtml" \
                "oracle-logos-ipa" "oracle-logos-httpd" \
                "oracle-epel-release-el8" "oracle-epel-release-el9" \
                "redhat-backgrounds" "redhat-logos" "redhat-indexhtml" \
                "redhat-logos-ipa" "redhat-logos-httpd" \
                "rocky-backgrounds" "rocky-logos" "rocky-indexhtml" \
                "rocky-logos-ipa" "rocky-logos-httpd" \
                "vzlinux-backgrounds" "vzlinux-logos" "vzlinux-indexhtml" \
                "vzlinux-logos-ipa" "vzlinux-logos-httpd")

REMOVE_PKGS=("centos-linux-release" "centos-gpg-keys" "centos-linux-repos" \
                "centos-stream-release" "centos-stream-repos" \
                "kernel-uek" "kernel-uek-core" "kernel-uek-modules" \
                "libreport-plugin-rhtsupport" "libreport-rhel" "insights-client" \
                "libreport-rhel-anaconda-bugzilla" "libreport-rhel-bugzilla" \
                "linux-firmware-core" "iwlax2xx-firmware" \
                "oraclelinux-release" "oraclelinux-release-el8" \
                "oraclelinux-release-el9" "python3-gobject-base-noarch" \
                "redhat-release" "redhat-release-eula" \
                "rocky-release" "rocky-gpg-keys" "rocky-repos" \
                "rocky-obsolete-packages" "libblockdev-btrfs" \
                "vzlinux-release" "vzlinux-gpg-keys" "vzlinux-repos" "vzlinux-obsolete-packages" \
                "evolution-data-server-ui" "epel-next-release")
REDHAT_DNF_PLUGINS=("product-id" "subscription-manager" "upload-profile")
REDHAT_REPO_FILES=("/etc/yum.repos.d/redhat.repo" "/etc/yum.repos.d/ubi.repo")
REDHAT_RHSM_RPMS=("subscription-manager" "subscription-manager-cockpit" "cockpit" "rhc")

module_list_enabled=""
module_list_installed=""
is_container=0

setup_log_files() {
    exec > >(tee /var/log/almalinux-deploy.log)
    exec 5> /var/log/almalinux-deploy.debug.log
    BASH_XTRACEFD=5
}


# Save the successful status of a stage for future continue of it
# $1 - name of a stage
save_status_of_stage() {
    if [[ 0 != "$(id -u)" ]]; then
        # the function is called in tests and should be skipped
        return 0
    fi
    local -r stage_name="${1}"
    if [[ ! -d "${STAGE_STATUSES_DIR}" ]]; then
        mkdir -p "${STAGE_STATUSES_DIR}"
    fi
    touch "${STAGE_STATUSES_DIR}/${stage_name}"
}


# Get a status of a stage for continue of it
# $1 - name of a stage
# The function returns 1 if stage isn't completed and 0 if it's completed
get_status_of_stage() {
    if [[ 0 != "$(id -u)" ]]; then
        # the function is called in tests and should be skipped
        return 1
    fi
    local -r stage_name="${1}"
    if [[ ! -d "${STAGE_STATUSES_DIR}" ]]; then
        return 1
    fi
    if [[ ! -f "${STAGE_STATUSES_DIR}/${stage_name}" ]]; then
        return 1
    fi
    return 0
}


is_migration_completed() {
    if get_status_of_stage "completed"; then
        printf '\n\033[0;32mMigration to AlmaLinux was already completed\033[0m\n'
        exit 0
    fi
}


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
    echo '  -f, --full           perform yum upgrade to 8.5 if necessary'
    echo '  -d, --downgrade      option to allow downgrade from CentOS Stream'
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

# Terminates the program if UEFI Secure Boot is enabled
assert_secureboot_disabled() {
    local -r message='Check Secure Boot disabled'
    if LC_ALL='C' mokutil --sb-state 2>/dev/null | grep -P '^SecureBoot\s+enabled' 1>/dev/null; then
        report_step_error "${message}" 'Secure Boot is not supported yet'
        exit 1
    fi
    report_step_done "${message}"
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
        if [[ "$(get_os_release_var 'NAME')"  == 'CentOS Stream' ]]; then
            if [[ ! "${DOWNGRADE}" == 'YES' ]]; then
                report_step_error "Use '-d or --downgrade' option to allow downgrade from CentOS Stream"
                exit 1
            fi
	        os_version="$(get_os_release_var 'VERSION_ID')"
        else
	        if ! os_version="$(grep -oP 'CentOS\s+Linux\s+release\s+\K(\d+\.\d+)' \
		        "${REDHAT_RELEASE_PATH}" 2>/dev/null)"; then
	            report_step_error "Detect ${os_type} version"
	        fi
        fi
    elif [[ "${os_type}" == 'virtuozzo' ]]; then
        if ! os_version="$(grep -oP 'Virtuozzo\s+Linux\s+release\s+\K(\d+\.\d+)' \
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
    if get_status_of_stage "assert_supported_system"; then
        return 0
    fi
    local -r os_type="${1}"
    local -r os_version="${2:0:1}"
    local -r arch="${3}"
    case "${arch}" in
        x86_64|aarch64|ppc64le|s390x)
            ;;
        *)
            report_step_error "Check ${arch} architecture is supported"
            exit 1
            ;;
    esac
    if [[ ${os_version} -lt ${MINIMAL_SUPPORTED_VERSION:0:1} ]]; then
        report_step_error "Check EL${os_version} is supported"
        exit 1
    fi
    os_types=("centos" "almalinux" "ol" "rhel" "rocky" "virtuozzo")
    if [[ ! " ${os_types[*]} " =~ ${os_type} ]]; then
        report_step_error "Check ${os_type} operating system is supported"
        exit 1
    fi
    report_step_done "Check ${os_type}-${os_version}.${arch} is supported"
    save_status_of_stage "assert_supported_system"
    return 0
}

# Terminates the program if a control panel is not supported by AlmaLinux.
#
# $1 - Control panel type.
# $2 - Control panel version.
assert_supported_panel() {
    if get_status_of_stage "assert_supported_panel"; then
        return 0
    fi
    local -r panel_type="${1}"
    local -r panel_version="${2}"
    local plesk_min_major=18
    local plesk_min_minor=0
    local plesk_min_micro=35
    local major
    local minor
    local micro
    local error_msg="${panel_type} version \"${panel_version}\" is not supported. Please update the control panel to version \"${plesk_min_major}.${plesk_min_minor}.${plesk_min_micro}\"."
    if [[ "${panel_type}" == 'plesk' ]]; then
    local IFS=.
read -r major minor micro << EOF
${panel_version}
EOF
        if [[ -z ${micro} ]]; then
            micro=0
        fi
        if [[ -z ${minor} ]]; then
            minor=0
        fi
        if [[ ${major} -lt ${plesk_min_major} ]]; then
            report_step_error "${error_msg}"
            exit 1
        elif [[ ${major} -eq ${plesk_min_major} && ${minor} -lt ${plesk_min_minor} ]]; then
            report_step_error "${error_msg}"
            exit 1
        elif [[ ${major} -eq ${plesk_min_major} && ${minor} -eq ${plesk_min_minor} && ${micro} -lt ${plesk_min_micro} ]]; then
            report_step_error "${error_msg}"
            exit 1
        fi
    fi
    save_status_of_stage "assert_supported_panel"
}

assert_supported_filesystem() {
    if get_status_of_stage "assert_supported_filesystem"; then
        return 0
    fi
    local result
    if result=$(df -Th | awk '{print $2}' | grep btrfs); then
        report_step_error "${result} is not supported filesystem"
        exit 1
    fi
    save_status_of_stage "assert_supported_filesystem"
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

# Returns a latest almalinux-repos RPM package download URL.
#
# $1 - AlmaLinux major version (e.g. 9).
# $2 - System architecture (e.g. x86_64).
#
# Prints almalinux-release RPM package download URL.
get_repos_file_url() {
    local -r os_version="${1:0:1}"
    local -r arch="${2}"
    echo "${ALMA_REPOS_URL:-https://repo.almalinux.org/almalinux/almalinux-repos-latest-${os_version}.${arch}.rpm}"
}

# Returns a latest almalinux-gpg-keys RPM package download URL.
#
# $1 - AlmaLinux major version (e.g. 9).
# $2 - System architecture (e.g. x86_64).
#
# Prints almalinux-gpg-keys RPM package download URL.
get_gpg_keys_file_url() {
    local -r os_version="${1:0:1}"
    local -r arch="${2}"
    echo "${ALMA_REPOS_URL:-https://repo.almalinux.org/almalinux/almalinux-gpg-keys-latest-${os_version}.${arch}.rpm}"
}

# Downloads and installs the AlmaLinux public PGP key.
#
# $1 - Temporary directory path.
# $2 - AlmaLinux major version (e.g. 8).
install_rpm_pubkey() {
    if get_status_of_stage "install_rpm_pubkey"; then
        return 0
    fi
    local -r tmp_dir="${1}"
    local -r os_version="${2:0:1}"
    local -r ALMA_PUBKEY_URL="https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux-${os_version}"
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
    save_status_of_stage "install_rpm_pubkey"
}

# Downloads almalinux-release package.
#
# $1 - Temporary directory path.
# $2 - almalinux-release package download URL.
#
# Prints downloaded file path.
download_release_files() {
    local -r tmp_dir="${1}"
    local -r release_url="${2}"
    local -r release_path="${tmp_dir}/almalinux-release-latest.rpm"
    local output
    if ! output=$(curl -f -s -S -o "${release_path}" "${release_url}" 2>&1); then
        report_step_error 'Download almalinux packages - release' "${output}"
        exit 1
    fi
    echo "${release_path}"
}

# Downloads almalinux-repos package.
#
# $1 - Temporary directory path.
# $2 - almalinux-repos package download URL.
#
# Prints downloaded file path.
download_repos_files() {
    local -r tmp_dir="${1}"
    local -r repos_url="${2}"
    local -r repos_path="${tmp_dir}/almalinux-repos.rpm"
    local output
    if ! output=$(curl -f -s -S -o "${repos_path}" "${repos_url}" 2>&1); then
        report_step_error 'Download almalinux packages - repos' "${output}"
        exit 1
    fi
    echo "${repos_path}"
}

# Downloads almalinux-gpg-keys package.
#
# $1 - Temporary directory path.
# $2 - almalinux-gpg-keys package download URL.
#
# Prints downloaded file path.
download_gpg_keys_files() {
    local -r tmp_dir="${1}"
    local -r gpg_keys_url="${2}"
    local -r gpg_keys_path="${tmp_dir}/almalinux-gpg-keys.rpm"
    local output
    if ! output=$(curl -f -s -S -o "${gpg_keys_path}" "${gpg_keys_url}" 2>&1); then
        report_step_error 'Download almalinux packages - gpg-keys' "${output}"
        exit 1
    fi
    echo "${gpg_keys_path}"
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
    report_step_done 'Verify almalinux-release package'
}

#
# Change repo file to point to last CentOS 8 release in vault
#
# $1 - Repo id.
# $2 - Repo name.
# $3 - Repo name for earlier releases if different from name.
# $4 - Repo subdir if different from name.
fix_repo_file() {
    local -r repo_id="${1}"
    local -r repo_name="${2}"
    local -r repo_name_alt="${3-$2}"
    local -r repo_subdir="${4:-$2}"
    if [ -f "/etc/yum.repos.d/CentOS-Linux-${repo_name}.repo" ]; then
        sed -i -e "/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=\$releasever&arch=\$basearch&repo=/ s/^#*/#/" -e "/baseurl=http:\/\/mirror.centos.org\/\$contentdir\/\$releasever\// s/^#*/#/" -e "/^\[${repo_id}\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/${repo_subdir}/\$basearch/os" "/etc/yum.repos.d/CentOS-Linux-${repo_name}.repo"
    elif [ -f "/etc/yum.repos.d/CentOS-${repo_name_alt}.repo" ]; then
        sed -i -e "/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=\$releasever&arch=\$basearch&repo=/ s/^#*/#/" -e "/baseurl=http:\/\/mirror.centos.org\/\$contentdir\/\$releasever\// s/^#*/#/" -e "/^\[\(${repo_id}\|${repo_name}\)\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/${repo_subdir}/\$basearch/os" "/etc/yum.repos.d/CentOS-${repo_name_alt}.repo"
    elif [ -n "${repo_name_alt}" ]; then
        echo "Error: No repo file found for ${repo_name}" >&2
        return 1
    fi
}

#
# Perform dnf upgrade (and fix repos since CentOS mirrorlist is offline as of 2022-01-31)
#
dnf_upgrade() {
    local -r step='Fix DNF repositories to live mirror and run dnf upgrade -y'
    if [[ "$(get_os_release_var 'NAME')" != 'CentOS Stream' ]]; then
        fix_repo_file baseos BaseOS Base
        fix_repo_file appstream AppStream
        fix_repo_file cr ContinuousRelease CR
        fix_repo_file devel Devel ''
        fix_repo_file extras Extras Extras extras
        fix_repo_file fasttrack FastTrack fasttrack fasttrack
        fix_repo_file ha HighAvailability ''
        fix_repo_file plus Plus centosplus
        fix_repo_file powertools PowerTools
        fix_repo_file crb CRB
    fi
    dnf upgrade -y || {
        ret_code=${?}
        if [[ ${ret_code} -ne 0 ]]; then
            report_step_error "${step}. Exit code: ${ret_code}"
            exit ${ret_code}
        fi
    }
    # Make sure RPM DB is clean for gpg key installation in a subsequent step
    dnf clean dbcache
    report_step_done 'DNF upgrade'
}

# Terminates the program if OS version doesn't match AlmaLinux version.
#
# $1 - OS version.
# $2 - almalinux-release package file path.
assert_compatible_os_version() {
    if get_status_of_stage "assert_compatible_os_version"; then
        return 0
    fi
    local -r os_version="${1}"
    local -r release_path="${2}"
    local alma_version
    alma_version=$(rpm -qp --queryformat '%{version}' "${release_path}")

    if [[ "$(get_os_release_var 'NAME')" != 'CentOS Stream' ]]; then
	      if [[ "${os_version:0:1}" -lt "${MINIMAL_SUPPORTED_VERSION:0:1}" ]] && [[ "${os_version:2:3}" -lt "${MINIMAL_SUPPORTED_VERSION:2:3}" ]]; then
          report_step_error "Please upgrade your OS from ${os_version} to" \
          "at least ${MINIMAL_SUPPORTED_VERSION} and try again"
          exit 1
        fi
    fi
    if [[ "${os_version:0:1}" -lt "${alma_version:0:1}" ]] && [[ "${os_version:2:3}" -gt "${alma_version:2:3}" ]]; then
        report_step_error "Version of your OS ${os_version} is not supported yet"
        exit 1
    fi
    report_step_done 'Your OS is supported'
    save_status_of_stage "assert_compatible_os_version"
}

# Backup /etc/issue* files
backup_issue() {
    if get_status_of_stage "backup_issue"; then
        return 0
    fi
    for file in $(rpm -Vf /etc/issue | cut -d' ' -f4); do
        if [[ ${file} =~ "/etc/issue" ]]; then
            cp "${file}" "${file}.bak"
        fi
    done
    save_status_of_stage "backup_issue"
}

# Restore /etc/issue* files
restore_issue() {
    if get_status_of_stage "restore_issue"; then
        return 0
    fi
    for file in /etc/issue /etc/issue.net; do
        [ ! -f "${file}.bak" ] || mv -f ${file}.bak ${file}
    done
    save_status_of_stage "restore_issue"
}

# Recursively removes a given directory.
#
# $1 - Directory path.
cleanup_tmp_dir() {
    rm -fr "${1:?}"
}

# Remove OS specific packages
remove_os_specific_packages_before_migration() {
    if get_status_of_stage "remove_os_specific_packages_before_migration"; then
        return 0
    fi
    for i in "${!REMOVE_PKGS[@]}"; do
        if ! rpm -q "${REMOVE_PKGS[i]}" &> /dev/null; then
            # remove an erased package from the list if it isn't installed
            unset "REMOVE_PKGS[i]"
        fi
    done
    if [[ "${#REMOVE_PKGS[@]}" -ne 0 ]]; then
        rpm -e --nodeps --allmatches "${REMOVE_PKGS[@]}"
    fi
    report_step_done 'Remove OS specific rpm packages'
    save_status_of_stage "remove_os_specific_packages_before_migration"
}


# Remove not needed Red Hat directories
remove_not_needed_redhat_dirs() {
    if get_status_of_stage "remove_not_needed_redhat_dirs"; then
        return 0
    fi
    [ -d /usr/share/doc/redhat-release ] && rm -r /usr/share/doc/redhat-release
    [ -d /usr/share/redhat-release ] && rm -r /usr/share/redhat-release
    save_status_of_stage "remove_not_needed_redhat_dirs"
}


# Install package almalinux-release
install_almalinux_release_package() {
    if get_status_of_stage "install_almalinux_release_package"; then
        return 0
    fi
    local -r release_path="${1}"
    rpm -Uvh --nodeps "${release_path}"
    report_step_done 'Install almalinux-release package'
    save_status_of_stage "install_almalinux_release_package"
}

# Install package almalinux-repos
install_almalinux_repos_package() {
    if get_status_of_stage "install_almalinux_repos_package"; then
        return 0
    fi
    local -r repos_path="${1}"
    rpm -Uvh --nodeps "${repos_path}"
    report_step_done 'Install almalinux-repos package'
    save_status_of_stage "install_almalinux_repos_package"
}

# Install package almalinux-gpg-keys
#
# $1 - full path (including package filename) to the almalinux-gpg-keys package
install_almalinux_gpg_keys_package() {
    if get_status_of_stage "install_almalinux_gpg_keys_package"; then
        return 0
    fi
    local -r gpg_keys_path="${1}"
    rpm -Uvh --nodeps "${gpg_keys_path}"
    report_step_done 'Install almalinux-gpg-keys package'
    save_status_of_stage "install_almalinux_gpg_keys_package"
}

# Remove brand packages and install the same AlmaLinux packages
replace_brand_packages() {
    if get_status_of_stage "replace_brand_packages"; then
        return 0
    fi
    local alma_pkgs=()
    local alma_pkg
    local output
    local pkg_name
    # replace GUI packages
    for i in "${!BRANDING_PKGS[@]}"; do
        pkg_name="${BRANDING_PKGS[i]}"
        if rpm -q "${pkg_name}" &>/dev/null; then
            # shellcheck disable=SC2001
            case "${pkg_name}" in
                oracle-epel-release-el*)
                    alma_pkg="epel-release"
                    ;;
                *)
                    # shellcheck disable=SC2001
                    alma_pkg="$(echo "${pkg_name}" | sed 's#centos\|oracle\|redhat\|rocky\|vzlinux#almalinux#')"
                    ;;
            esac
            alma_pkgs+=("${alma_pkg}")
        else
            unset "BRANDING_PKGS[i]"
        fi
    done
    if [[ "${#BRANDING_PKGS[@]}" -ne 0 ]]; then
        rpm -e --nodeps --allmatches "${BRANDING_PKGS[@]}"
        report_step_done "Remove ${BRANDING_PKGS[*]} packages"
    fi
    if [[ "${#alma_pkgs[@]}" -ne 0 ]]; then
        if ! output=$(dnf install -y "${alma_pkgs[@]}" 2>&1); then
            report_step_error "Install ${alma_pkgs[*]} packages" "${output}"
        fi
        report_step_done "Install ${alma_pkgs[*]} packages"
    fi
    save_status_of_stage "replace_brand_packages"
}


# Converts a CentOS like system to AlmaLinux
#
# $1 - almalinux-release RPM package path.
# $2 - almalinux-repos RPM package path.
# $3 - almalinux-gpg-keys RPM package path
migrate_from_centos() {
    if get_status_of_stage "migrate_from_centos"; then
        return 0
    fi
    local -r release_path="${1}"
    case "${os_version}" in
      9*)
        local -r repos_path="${2}"
        local -r gpg_keys_path="${3}"
        ;;
    esac
    # replace OS packages with almalinux-release
    # and OS centos-specific packages
    remove_os_specific_packages_before_migration
    remove_not_needed_redhat_dirs
    install_almalinux_release_package "${release_path}"
    case "${os_version}" in
      9*)
        install_almalinux_repos_package "${repos_path}"
        install_almalinux_gpg_keys_package "${gpg_keys_path}"
        ;;
    esac
    replace_brand_packages
    save_status_of_stage "migrate_from_centos"
}

# Reset modules stream ol8 for OracleLinux
reset_wrong_module_streams() {
    module_list_enabled=$(dnf -e 1 module list --enabled | awk '$2 == "ol8" {printf $1" "}')
    module_list_installed=$(dnf -e 1 module list --installed | awk '$2 == "ol8" {printf $1" "}')
    if [ -n "${module_list_enabled}" ]; then
        # shellcheck disable=SC2086
        dnf module reset -y ${module_list_enabled}
        echo "reset modules: ${module_list_enabled}"
        report_step_done "Reset modules"
    fi
}

# Executes the 'dnf distro-sync -y' command.
#
# $1 - operational system type.
#
distro_sync() {
    if get_status_of_stage "distro_sync"; then
        return 0
    fi
    local -r step='Run dnf distro-sync -y'
    local ret_code=0
    local -r os_version="${1}"
    case "${os_version}" in
      8*)
        local dnf_repos="--enablerepo=powertools"
        ;;
      9*)
        local dnf_repos="--enablerepo=crb"
        ;;
    esac
    local exclude_pkgs="--exclude="
    # create needed repo
    if [ "${panel_type}" == "plesk" ]; then
        plesk installer --select-release-current --show-components --skip-cleanup
        dnf_repos+=",PLESK_*-dist"
    fi
    dnf check-update || {
        ret_code=${?}
        if [[ ${ret_code} -ne 0 ]] && [[ ${ret_code} -ne 100 ]]; then
            report_step_error "${step}. Exit code: ${ret_code}"
            exit ${ret_code}
        fi
    }
    # check if we inside lxc container
    if [ $is_container -eq 1 ]; then
        exclude_pkgs+="filesystem*,grub*"
    fi
    dnf distro-sync -y "${dnf_repos}" "${exclude_pkgs}" || {
        ret_code=${?}
        report_step_error "${step}. Exit code: ${ret_code}"
        exit ${ret_code}
    }
    # remove unnecessary repo
    if [ "${panel_type}" == "plesk" ]; then
        plesk installer --select-release-current --show-components
    fi
    report_step_done "${step}"
    save_status_of_stage "distro_sync"
}

# Enable reseted modules with new stream rhel8
restore_module_streams() {
    if [ -n "${module_list_enabled}" ]; then
        # shellcheck disable=SC2001,2086
        module_enabled_rhel=$(echo ${module_list_enabled} | sed -e 's# #:rhel8 #g')
        # shellcheck disable=SC2086
        dnf module enable -y ${module_enabled_rhel}
        echo "re-enabled modules: ${module_enabled_rhel}"
        report_step_done "Enable modules"
    fi
    if [ -n "${module_list_installed}" ]; then
        # shellcheck disable=SC2001,2086
        module_installed_rhel=$(echo ${module_list_installed} | sed -e 's# #:rhel8 #g')
        # shellcheck disable=SC2086
        dnf module install -y ${module_installed_rhel}
        echo "installed modules: ${module_installed_rhel}"
        report_step_done "Install modules"
    fi
}

install_kernel() {
    if get_status_of_stage "install_kernel"; then
        return 0
    fi
    if ! output=$(rpm -q kernel 2>&1); then
        if output=$(dnf -y install kernel 2>&1); then
            report_step_done "Install AlmaLinux kernel"
        else
            report_step_error "Install AlmaLinux kernel"
        fi
    fi
    save_status_of_stage "install_kernel"
}

grub_update() {
    if get_status_of_stage "grub_update"; then
        return 0
    fi
    if [ "$(which grub2-mkconfig)" ] ; then
        if [ -d /sys/firmware/efi ]; then
            grub2-mkconfig -o /etc/grub2-efi.cfg
        else
            grub2-mkconfig -o /etc/grub2.cfg
        fi
    fi
    save_status_of_stage "grub_update"
}

# Check do we have custom kernel (e.g. kernel-uek) and print warning
check_custom_kernel() {
    if get_status_of_stage "check_custom_kernel"; then
        return 0
    fi
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
    save_status_of_stage "check_custom_kernel"
}

_backup_alternative() {
    local path="${1}"
    local bak_dir="${2}"
    local bak_prefix="current_point"
    local alt_name=
    local alt_dest=
    local alt_link=
    alt_name="$(basename "${path}")"
    alt_link="${ALT_DIR}/${alt_name}"
    alt_dest="$(readlink "${alt_link}")"
    mkdir -p "${bak_dir}"

    # backup the current state of an alternative
    echo "${alt_dest} ${alt_link}" > "${bak_dir}/${bak_prefix}.${alt_name}"
}


_restore_alternative() {
    local path="${1}"
    local bak_dir="${2}"
    local bak_point="${bak_dir}/current_point"
    local alt_name=
    local shift_begin=3
    local shift_middle=2
    local main_link=
    local alternatives=()
    local priorities=()
    local links=()
    local dests=()
    local names=()
    local line=
    local _alt_link=
    local _alt_dest=
    local alt_link=
    local alt_dest=
    local i=
    local empty_num=
    local len=
    local begin_index=
    local end_index=
    len="$(wc -l < "${path}")"
    # name of a backup alternatives, e.g. python or java
    alt_name="$(basename "${path}")"
    # system link which points to an alternative, e.g.
    # /usr/bin/unversioned-python -> /etc/alternatives/python
    main_link="$(sed -n -e 2p "${path}")"
    i=0
    # this cycle saves info about slave's links
    # and slave's names of an alternative
    # e.g.
    # unversioned-python - name
    # /usr/bin/python - link
    # python2 - name
    # /usr/bin/python2 - link
    # unversioned-python-man - name
    # /usr/share/man/man1/python.1.gz - link
    while read -r line; do
        i=$(("${i}" + 1))
        if [[ -z $line ]]; then
            empty_num=$(("${shift_begin}" + "${i}"))
            break
        fi
        if [[ $(( "${i}" % 2 )) -eq 0 ]]; then
            links+=("$line")
        else
            names+=("$line")
        fi
    done < <(tail -n +${shift_begin} "${path}")

    # this cycle saves info about available alternatives and them priorites
    # e.g.
    # /usr/libexec/no-python alternative with priority 404
    # /usr/bin/python3 alternative with priority 300
    while [[ "${len}" -gt $(("${#names[@]}" + "${empty_num}")) ]]; do
        alternatives+=("$(sed -n -e "${empty_num}"p "${path}")")
        priorities+=("$(sed -n -e $(("${empty_num}" + 1))p "${path}")")
        begin_index="$(("${empty_num}" + "${shift_middle}"))"
        end_index="$(("${#names[@]}" + "${shift_middle}" + "${empty_num}"))"
        # this cycle saves info about slave's dests for an each alternative,
        # e.g.
        # /usr/bin/python3 - dest for /usr/bin/python
        #/usr/share/man/man1/python3.1.gz - dest for /usr/share/man/man1/python.1.gz
        # destination can be empty and in this case we don't create symlink
        if [[ "${begin_index}" -ne "${end_index}" ]]; then
            while read -r line; do
                dests+=("$line")
            done < <(sed -n -e "${begin_index}","${end_index}"p "${path}")
        fi
        empty_num=$(("${empty_num}" + "${#names[@]}" + "${shift_middle}"))
    done
    # read and restore current state of an alternative
    # e.g.
    # /etc/alternatives/python -> /usr/libexec/no-python
    while read -r _alt_dest _alt_link; do
        alt_link="${_alt_link}"
        alt_dest="${_alt_dest}"
        if [[ ! -e "${alt_link}" ]]; then
            ln -sf "${alt_dest}" "${alt_link}"
        fi
    done < "${bak_point}.${alt_name}"

    for i in "${!alternatives[@]}"; do
        if [[ ! -e "${main_link}" ]]; then
            # restore system symlink for alternative, e.g.
            # /usr/bin/unversioned-python -> /etc/alternatives/python
            ln -sf "${alt_link}" "${main_link}"
        fi
        for j in "${!names[@]}"; do
            if [[ "${alt_dest}" == "${alternatives[$i]}" ]]; then
                if [[ -e "${dests[$(( "${j}" + "${#links[@]}" * "${i}"))]}" && ! -e "${ALT_DIR}/${names[$j]}" ]]; then
                    # restore system slave link to an alternative, e.g.
                    # /etc/alternatives/unversioned-python-man -> /usr/share/man/man1/unversioned-python.1.gz
                    ln -sf "${dests[$(( "${j}" + "${#links[@]}" * "${i}"))]}" "${ALT_DIR}/${names[$j]}"
                fi
                if [[ -e "${ALT_DIR}/${names[$j]}" && ! -e "${links[$j]}" ]]; then
                    # restore slave link for an alternative
                    # e.g. /usr/share/man/man1/python.1.gz -> /etc/alternatives/unversioned-python-man
                    ln -sf "${ALT_DIR}/${names[$j]}" "${links[$j]}"
                fi
            fi
        done
    done

}

# backup existing alternatives, including the current states of alternatives
backup_alternatives() {
    if get_status_of_stage "backup_alternatives"; then
        return 0
    fi
    for alt_file in "${ALT_ADM_DIR}"/*; do
        _backup_alternative "${alt_file}" "${BAK_DIR}"
    done
    /usr/bin/cp -rf "${ALT_ADM_DIR}" "${BAK_DIR}"/.
    report_step_done "Backup of alternatives is done"
    save_status_of_stage "backup_alternatives"
}


# restore existing alternatives, including the current states of alternatives
restore_alternatives() {
    if get_status_of_stage "restore_alternatives"; then
        return 0
    fi
    for alt_file in "${BAK_DIR}/alternatives/"*; do
        _restore_alternative "${alt_file}" "${BAK_DIR}"
    done
    /usr/bin/cp -rn "${BAK_DIR}/alternatives/"* "${ALT_ADM_DIR}/"
    report_step_done "Restoring of alternatives is done"
    save_status_of_stage "restore_alternatives"
}


add_efi_boot_record() {
    if get_status_of_stage "add_efi_boot_record"; then
        return 0
    fi
    if [[ ! -d /sys/firmware/efi ]]; then
        return
    fi
    local device
    local disk_name
    local disk_num
    local soft_dev1
    local soft_dev2
    local disk_name1
    local disk_name2
    local disk_num1
    local disk_num2
    local arch
    arch="$(get_system_arch)"
    device="$(df -T /boot/efi | sed -n 2p | awk '{ print $1}')"

    if [[ $device == *"/dev/md"* ]]; then
        echo "ESP Partition on software raid detected:"
        soft_dev1="$(lsblk -f -l -p | grep boot_efi |sed -n 1p | awk '{ print $1}')"
        soft_dev2="$(lsblk -f -l -p | grep boot_efi |sed -n 2p | awk '{ print $1}')"
        echo "$soft_dev1"
        echo "$soft_dev2"
        disk_name1="$(echo "${soft_dev1}" | sed -re 's/(p|)[0-9]$//g')"
        disk_name2="$(echo "${soft_dev2}" | sed -re 's/(p|)[0-9]$//g')"
        disk_num1="$(echo "${soft_dev1}" | tail -c 2|sed 's|[^0-9]||g')"
        disk_num2="$(echo "${soft_dev2}" | tail -c 2|sed 's|[^0-9]||g')"
    else
        disk_name="$(echo "${device}" | sed -re 's/(p|)[0-9]$//g')"
        disk_num="$(echo "${device}" | tail -c 2|sed 's|[^0-9]||g')"
    fi

    if [[ ${arch} == "x86_64" && $device == *"/dev/md"* ]]; then
        efibootmgr -c -L "AlmaLinux" -l "\EFI\almalinux\shimx64.efi" -d "${disk_name1}" -p "${disk_num1}"
        efibootmgr -c -L "AlmaLinux" -l "\EFI\almalinux\shimx64.efi" -d "${disk_name2}" -p "${disk_num2}"

    elif [[ ${arch} == "aarch64" && $device == *"/dev/md"* ]]; then
    	  efibootmgr -c -L "AlmaLinux" -l "\EFI\almalinux\shimaa64.efi" -d "${disk_name1}" -p "${disk_num1}"
        efibootmgr -c -L "AlmaLinux" -l "\EFI\almalinux\shimaa64.efi" -d "${disk_name2}" -p "${disk_num2}"

    elif [[ ${arch} == "x86_64" ]]; then
        efibootmgr -c -L "AlmaLinux" -l "\EFI\almalinux\shimx64.efi" -d "${disk_name}" -p "${disk_num}"

    elif [[ ${arch} == "aarch64" ]]; then
        efibootmgr -c -L "AlmaLinux" -l "\EFI\almalinux\shimaa64.efi" -d "${disk_name}" -p "${disk_num}"

    fi
        report_step_done "The new EFI boot record for AlmaLinux is added"
        save_status_of_stage "add_efi_boot_record"
}


reinstall_secure_boot_packages() {
    if get_status_of_stage "reinstall_secure_boot_packages"; then
        return 0
    fi
    if [ "$(which grubby)" ] ; then #if this happens on a system with GRUB and related tools, rather than on RPi
        local kernel_package
        for pkg in $(rpm -qa | grep -E 'shim|fwupd|grub2'); do
            if [[ "AlmaLinux" != "$(rpm -q --queryformat '%{vendor}' "$pkg")" ]]; then
                yum reinstall "${pkg}" -y
            fi
        done
        kernel_package="$(rpm -qf "$(grubby --default-kernel)")"
        if [[ "AlmaLinux" != "$(rpm -q --queryformat '%{vendor}' "${kernel_package}")" ]]; then
            yum reinstall "${kernel_package}" -y
        fi
    fi
    report_step_done "All Secure Boot related packages which were not released by AlmaLinux are reinstalled"
    save_status_of_stage "reinstall_secure_boot_packages"
}

disable_dnf_plugin() {
    local plugin="$1"

    local conf
    conf="/etc/dnf/plugins/${plugin}.conf"

    if [ -f "${conf}" ]; then
        sed -i -e 's/^enabled\s*=\s*1/enabled=0/g' "${conf}"
    else
        printf '[main]\nenabled=0\n' > "${conf}"
    fi
}

disable_redhat_dnf_plugins() {
    local plugin

    for plugin in "${REDHAT_DNF_PLUGINS[@]}"; do
        disable_dnf_plugin "${plugin}"
    done
}

subscription_manager_unregister() {
    if get_status_of_stage "subscription_manager_unregister"; then
        return 0
    fi
    if subscription-manager status >/dev/null 2>&1; then
        subscription-manager remove --all
        subscription-manager unregister
        subscription-manager clean
    fi
    report_step_done "Red Hat Subscription Manager deactivated"
    save_status_of_stage "subscription_manager_unregister"
}

remove_redhat_rhsm_rpms() {
    if get_status_of_stage "remove_redhat_rhsm_rpms"; then
        return 0
    fi
    rpm -e --nodeps "${REDHAT_RHSM_RPMS[@]}" >/dev/null 2>&1 || true
    report_step_done "Red Hat Subscription Manager packages are removed (with rpm --nodeps)"
    save_status_of_stage "remove_redhat_rhsm_rpms"
}

remove_redhat_repo_files() {
    if get_status_of_stage "remove_redhat_repo_files"; then
        return 0
    fi
    local repo
    for repo in "${REDHAT_REPO_FILES[@]}"; do
        if [ -e "${repo}" ]; then
            mv -f "${repo}" "${repo}.$(date -u '+%s')"
        fi
    done
    report_step_done "Remove RHEL repositories' files if any"
    save_status_of_stage "remove_redhat_repo_files"
}

main() {
    is_migration_completed
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
    assert_supported_filesystem

    read -r panel_type panel_version < <(get_panel_info)
    assert_supported_panel "${panel_type}" "${panel_version}"

    release_url=$(get_release_file_url "${os_version}" "${arch}")
    tmp_dir=$(mktemp -d --tmpdir="${BASE_TMP_DIR}" .alma.XXXXXX)
    # shellcheck disable=SC2064
    trap "cleanup_tmp_dir ${tmp_dir}" EXIT
    install_rpm_pubkey "${tmp_dir}" "${os_version}"

    release_path=$(download_release_files "${tmp_dir}" "${release_url}")
    report_step_done 'Download almalinux-release package'
    if mount | grep -q fuse.lxcfs ||
        env | grep -q 'container=lxc' ||
        awk '{print $1}' /proc/vz/veinfo 2>/dev/null ||
        grep docker '/proc/1/cgroup' >/dev/null; then
        is_container=1
    fi

    assert_valid_package "${release_path}"
    assert_compatible_os_version "${os_version}" "${release_path}"

    case "${os_type}" in
    almalinux|centos|ol|rhel|rocky|virtuozzo)
        backup_issue

        if [[ "${os_type}" == "rhel" ]]; then
            subscription_manager_unregister
            remove_redhat_rhsm_rpms
            remove_redhat_repo_files
        fi

        case "${os_version}" in
          8*)
            migrate_from_centos "${release_path}"
            ;;
          9*)
            repos_url=$(get_repos_file_url "${os_version}" "${arch}")
            repos_path=$(download_repos_files "${tmp_dir}" "${repos_url}")
            gpg_keys_url=$(get_gpg_keys_file_url "${os_version}" "${arch}")
            gpg_keys_path=$(download_gpg_keys_files "${tmp_dir}" "${gpg_keys_url}")
            migrate_from_centos "${release_path}" "${repos_path}" "${gpg_keys_path}"
            ;;
        esac
        ;;
    *)
        report_step_error "Migrate ${os_type}: not supported"
        exit 1
        ;;
    esac

    backup_alternatives
    reset_wrong_module_streams
    distro_sync "${os_version}"
    restore_module_streams
    restore_alternatives
    restore_issue
    # don't do this steps if we inside the lxc container
    if [ $is_container -eq 0 ]; then
        install_kernel
        grub_update
        reinstall_secure_boot_packages
        add_efi_boot_record
    fi
    check_custom_kernel
    save_status_of_stage "completed"
    printf '\n\033[0;32mMigration to AlmaLinux is completed\033[0m\n'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    for opt in "$@"; do
        case ${opt} in
        -h | --help)
            show_usage
            exit 0
            ;;
        -f | --full)
            dnf_upgrade
            ;;
        -v | --version)
            echo "${VERSION}"
            exit 0
            ;;
        -d | --downgrade)
            DOWNGRADE='YES'
            ;;
        -t | --tests)
            exit 0
            ;;
        *)
            echo "Error: unknown option ${opt}" >&2
            exit 2
            ;;
        esac
    done
    setup_log_files
    set -x
    main
    set +x
fi
