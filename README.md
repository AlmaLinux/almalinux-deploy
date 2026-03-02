# almalinux-deploy

An EL to AlmaLinux migration tool.

📖 **Official Documentation**: For comprehensive migration guidance, please refer to the [AlmaLinux Migration Guide](https://wiki.almalinux.org/documentation/migration-guide.html) on the AlmaLinux Wiki.

## Supported Systems

### Operating Systems
- CentOS Linux 8 (8.4+) / CentOS Stream 8
- CentOS Stream 9
- CentOS Stream 10
- Oracle Linux 8, 9, 10
- RHEL 8, 9, 10
- Rocky Linux 8, 9, 10
- MiracleLinux 8, 9
- Virtuozzo Linux (VZLinux) 8, 9

### Architectures
- x86_64
- aarch64
- ppc64le
- s390x

### File Systems
- All standard EL filesystems (xfs, ext4, etc.)
- BTRFS (EL10+ only)

### Boot Modes
- Legacy BIOS (GRUB2)
- UEFI (GRUB2)
- UEFI with Secure Boot enabled (GRUB2 with shim)

**Note:** Only GRUB2 bootloader is supported for systems requiring a bootloader. Systems using other bootloaders (LILO, syslinux, systemd-boot, etc.) are not supported. Container environments don't require a bootloader.

### Control Panels
- cPanel
- Plesk (minimum version 18.0.35)
- DirectAdmin

### Containers
- Open Container Initiative (OCI) standard compliant containers

### Deployment Environments
- Bare metal servers
- Virtual machines (all major hypervisors)
- Cloud compute instances (public and private clouds)

## Requirements

Before running the migration script, ensure your system meets these requirements:

- Root privileges (the script must be run as root or with sudo)
- `dnf-plugins-core` package must be installed
- **GRUB2 bootloader** (required for bare metal and VMs; not needed for containers; other bootloaders are not supported)
- Active internet connection (unless using local repository mirrors with `-l` option)
- At least CentOS 8.4 or equivalent EL8/9/10 version
- Sufficient disk space for package downloads and installation
- **Reliable console access** without risk of disconnection (see Usage section for details)

The script will automatically check for most of these requirements and exit with an error if they are not met.

## Usage

In order to convert your EL8, EL9, or EL10 operating systems to AlmaLinux do the following:

**⚠️ Important:** The migration process must be run from a reliable console session without risk of disconnection. For remote systems:
- Use a console access method (IPMI, iLO, iDRAC, VNC, or physical console)
- If using SSH, run the migration inside a terminal multiplexer like `screen` or `tmux` to prevent interruption if the SSH connection drops
- Avoid running the migration over unstable network connections

Example using `screen`:
```bash
# Start a new screen session
screen -S almalinux-migration

# If disconnected, reconnect with:
# screen -r almalinux-migration
```

1. Make sure your system is fully updated and reboot if necessary:

   ```shell
   sudo dnf update -y
   sudo reboot
   ```

   **Note:** For CentOS 8 specific issues, see the [CentOS 8 Migration Notes](#centos-8-migration-notes) section at the bottom of this document.

2. Back up of the system. We didn't test all possible scenarios so there
   is a risk that something goes wrong. In such a situation you will have a
   restore point.

3. Download the [almalinux-deploy.sh](almalinux-deploy.sh) script:

   ```shell
   curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh
   ```

4. Run the script and check its output for errors:

   ```shell
   $ sudo bash almalinux-deploy.sh
     ...
     Migration to AlmaLinux is completed
   ```

## Command-Line Options

The script supports the following options:

- `-h, --help` - Show help message and exit
- `-f, --full` - Perform dnf upgrade to 8.5 if necessary (handles CentOS 8 mirrorlist issues)
- `-d, --downgrade` - Allow downgrade from CentOS Stream to AlmaLinux stable
- `-v, --version` - Print script version and exit
- `-l=URL, --local-repo=URL` - Use AlmaLinux local repositories at specified URL/path (for systems without internet access)
- `-e=pkg1*,pkg2*, --exclude=pkg1*,pkg2*` - Comma-separated list of packages to exclude during dnf distro-sync

### Environment Variables

The script supports the following environment variables:

- `ALMA_RELEASE_URL` - Custom URL for almalinux-release package download
- `ALMA_PUBKEY_URL` - Custom URL for RPM-GPG-KEY-AlmaLinux download

### Examples

```bash
# Standard migration
sudo bash almalinux-deploy.sh

# Migration with automatic CentOS 8 repository fix
sudo bash almalinux-deploy.sh -f

# Downgrade from CentOS Stream
sudo bash almalinux-deploy.sh -d

# Use local mirror
sudo bash almalinux-deploy.sh -l=http://mirror.example.com/almalinux

# Exclude specific packages from sync
sudo bash almalinux-deploy.sh -e=kernel-debug*,some-package

# Use custom release package URL
sudo ALMA_RELEASE_URL=http://custom.mirror/almalinux-release-latest-8.x86_64.rpm bash almalinux-deploy.sh
```

5. Reboot is recommended to boot with AlmaLinux kernel:

    ```shell
    sudo reboot
    ```

6. Ensure that your system was successfully converted:

   ```shell
   # check release file
   $ cat /etc/almalinux-release
   AlmaLinux release 8.10 (Cerulean Leopard)

   # check that the system boots AlmaLinux kernel by default
   $ sudo grubby --info DEFAULT | grep AlmaLinux
   title="AlmaLinux (4.18.0-553.107.1.el8_10.x86_64) 8.10 (Cerulean Leopard)
   ```

7. Thank you for choosing AlmaLinux!

## Special Features & Notes

### Migration Tracking and Resume Support
The script maintains migration state in `/var/run/almalinux-deploy-statuses/`, allowing you to resume interrupted migrations. If a migration is interrupted, simply re-run the script and it will continue from where it left off.

### Log Files
Migration logs are stored in:
- `/var/log/almalinux-deploy.log` - Main migration log
- `/var/log/almalinux-deploy.debug.log` - Debug log with detailed trace information

Previous logs are preserved with timestamps (e.g., `almalinux-deploy.log.20260302153045`).

### RHEL-Specific Handling
When migrating from RHEL, the script automatically:
- Unregisters from Red Hat Subscription Manager
- Removes subscription-manager related packages
- Disables RHEL-specific DNF plugins
- Backs up and removes RHEL repository files

### Container Environments
The script detects OCI-compliant container environments and automatically:
- Skips kernel installation
- Skips GRUB configuration updates (containers don't use bootloaders)
- Skips EFI boot record management
- Excludes filesystem and bootloader packages from sync

**Note:** Containers are fully supported without requiring GRUB2 or any bootloader.

### Alternatives Management
The script backs up and restores system alternatives (e.g., Python, Java versions) to maintain your pre-migration configuration.

### UEFI Secure Boot Support
The script fully supports UEFI Secure Boot environments. During migration, it:
- Reinstalls all Secure Boot related packages (shim, grub2, fwupd) with AlmaLinux signed versions
- Reinstalls the kernel package with AlmaLinux signed version
- Creates appropriate EFI boot entries using shim bootloaders (shimx64.efi for x86_64, shimaa64.efi for aarch64)
- Handles BTRFS subvolume paths correctly for EL10+ systems

**Note:** If your system has custom kernels (e.g., kernel-uek), they will not boot in Secure Boot mode after migration as they are not signed by AlmaLinux.

### Module Stream Handling
For Oracle Linux migrations, the script automatically resets and restores module streams from `ol8` to appropriate AlmaLinux streams.

### Repository Mapping
The script intelligently maps enabled repositories from your source distribution to equivalent AlmaLinux repositories:

- **extras** - Extra packages for Enterprise Linux
  - Maps: CentOS/Rocky `extras`, `extras-common`, MiracleLinux `9/10-latest-extras`, Oracle Linux `ol8/9/10_addons`

- **ha** (EL8) - High Availability clustering packages
  - Maps: CentOS/Rocky/Virtuozzo `ha`, MiracleLinux `8-latest-HighAvailability`, RHEL `rhel-8-for-x86_64-highavailability-*`

- **highavailability** (EL9/10) - High Availability clustering packages
  - Maps: CentOS/Rocky `highavailability`, `ha`, MiracleLinux `9/10-latest-HighAvailability`, RHEL `rhel-9/10-for-x86_64-highavailability-*`

- **powertools** (EL8) - Additional development and build tools
  - Maps: CentOS/Rocky/Virtuozzo `powertools`, MiracleLinux `8-latest-PowerTools`, Oracle Linux `ol8_codeready_builder`, `ol8_distro_builder`, RHEL/UBI `codeready-builder-for-rhel-8-*`, `ubi-8-codeready-builder*`

- **crb** (EL9/10) - CodeReady Linux Builder - Additional development and build tools
  - Maps: CentOS/Rocky `crb`, `powertools`, MiracleLinux `9/10-latest-PowerTools`, Oracle Linux `ol9/10_codeready_builder`, `ol9/10_distro_builder`, RHEL/UBI `codeready-builder-for-rhel-9/10-*`, `ubi-9/10-codeready-builder-rpms`

- **resilientstorage** - Resilient storage packages for shared storage
  - Maps: CentOS `resilientstorage`, Rocky `resilient-storage`, MiracleLinux `9/10-latest-ResilientStorage`, RHEL `rhel-8/9/10-for-x86_64-resilientstorage-*`

- **rt** - Real-Time kernel and related packages
  - Maps: CentOS/Rocky/Virtuozzo `rt`, RHEL `rhel-8/9/10-for-x86_64-rt-*`

- **nfv** - Network Function Virtualization packages
  - Maps: CentOS/Rocky `nfv`, RHEL `rhel-9-for-x86_64-nfv-*`

- **sap** - SAP NetWeaver application server packages
  - Maps: Rocky `sap`, RHEL `rhel-8/9/10-for-x86_64-sap-netweaver-*`

- **saphana** - SAP HANA database packages
  - Maps: Rocky `saphana`, RHEL `rhel-8/9/10-for-x86_64-sap-solutions-*`

- **plus** - Additional packages with enhanced functionality
  - Maps: CentOS/Rocky/Virtuozzo `plus`

This ensures that if you had specific repositories enabled before migration, the equivalent AlmaLinux repositories will be automatically enabled after migration.

## Known Limitations

- **GRUB2 bootloader only**: For bare metal servers and virtual machines, only systems using GRUB2 as the bootloader are supported. Systems using alternative bootloaders (LILO, syslinux, systemd-boot, etc.) cannot be migrated. Container environments don't require a bootloader and are fully supported.
- **Custom kernels** (e.g., kernel-uek from Oracle Linux) are not automatically removed but will be flagged after migration. If you're using Secure Boot, these custom kernels will not boot in Secure Boot mode.
- **BTRFS** filesystem is only supported on EL10+; attempting to migrate EL8 or EL9 systems with BTRFS will fail
- Minimum supported version is **CentOS 8.4** or equivalent

## Bug Report Submission Guide

If you encounter issues during migration, please submit a bug report with the following information to help us diagnose and fix the problem quickly.

### Required Information

#### 1. **Log Files**
Attach both log files from the migration:

```bash
# Main migration log
/var/log/almalinux-deploy.log

# Debug log with detailed trace information
/var/log/almalinux-deploy.debug.log
```

If the migration was run multiple times, previous logs are timestamped (e.g., `almalinux-deploy.log.20260302153045`). Include the most recent logs.

**How to collect:**
```bash
sudo tar -czf almalinux-deploy-logs.tar.gz \
  /var/log/almalinux-deploy.log* \
  /var/log/almalinux-deploy.debug.log*
```

#### 2. **Migration State Report**
Provide the contents of the migration state directory to show which stages completed:

```bash
# List all completed migration stages
ls -la /var/run/almalinux-deploy-statuses/
```

This directory contains marker files for each completed stage (e.g., `get_enabled_repos`, `distro_sync`, `completed`).

**How to collect:**
```bash
sudo ls -la /var/run/almalinux-deploy-statuses/ > migration-state.txt
```

#### 3. **Boot Loader State**
Include information about your current boot configuration:

```bash
# Check default kernel
sudo grubby --info DEFAULT

# List all installed kernels
sudo grubby --info ALL

# Check boot loader configuration
if [ -d /sys/firmware/efi ]; then
  echo "Boot mode: UEFI"
  sudo efibootmgr -v
else
  echo "Boot mode: Legacy BIOS"
fi
```

**How to collect:**
```bash
sudo grubby --info DEFAULT > bootloader-state.txt
sudo grubby --info ALL >> bootloader-state.txt
if [ -d /sys/firmware/efi ]; then
  echo -e "\n=== UEFI Boot Entries ===" >> bootloader-state.txt
  sudo efibootmgr -v >> bootloader-state.txt
fi
```

#### 4. **DNF Repository Configuration**
List all enabled repositories at the time of the issue:

```bash
# List enabled repositories
sudo dnf repolist --enabled

# List all repository files
ls -la /etc/yum.repos.d/
```

**How to collect:**
```bash
sudo dnf repolist --enabled -v > dnf-repos.txt
echo -e "\n=== Repository Files ===" >> dnf-repos.txt
sudo ls -la /etc/yum.repos.d/ >> dnf-repos.txt
```

### Additional Helpful Information

Include the following in your bug report:

```bash
# System information
cat /etc/os-release
uname -a

# Disk and partitioning
df -h
lsblk

# Package information
rpm -qa | grep -E 'almalinux|centos|rocky|oracle' | sort

# Check for Secure Boot status
sudo mokutil --sb-state 2>/dev/null || echo "mokutil not available"

# Installed kernels
rpm -qa kernel
```

**All-in-one collection script:**
```bash
#!/bin/bash
# Bug report collection script for almalinux-deploy

REPORT_DIR="almalinux-deploy-bugreport-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${REPORT_DIR}"

echo "Collecting bug report information..."

# 1. Log files
echo "- Collecting log files..."
sudo cp /var/log/almalinux-deploy*.log* "${REPORT_DIR}/" 2>/dev/null || echo "No log files found"

# 2. Migration state
echo "- Collecting migration state..."
sudo ls -la /var/run/almalinux-deploy-statuses/ > "${REPORT_DIR}/migration-state.txt" 2>/dev/null || echo "No state directory found"
sudo cp -r /var/run/almalinux-deploy-statuses "${REPORT_DIR}/" 2>/dev/null

# 3. Boot loader state
echo "- Collecting bootloader state..."
{
  echo "=== Default Kernel ==="
  sudo grubby --info DEFAULT
  echo -e "\n=== All Kernels ==="
  sudo grubby --info ALL
  if [ -d /sys/firmware/efi ]; then
    echo -e "\n=== UEFI Boot Entries ==="
    sudo efibootmgr -v
  fi
} > "${REPORT_DIR}/bootloader-state.txt" 2>&1

# 4. DNF repositories
echo "- Collecting DNF repository information..."
{
  echo "=== Enabled Repositories ==="
  sudo dnf repolist --enabled
  echo -e "\n=== Repository Files ==="
  sudo ls -la /etc/yum.repos.d/
} > "${REPORT_DIR}/dnf-repos.txt" 2>&1

# 5. System information
echo "- Collecting system information..."
{
  echo "=== OS Release ==="
  cat /etc/os-release
  echo -e "\n=== Kernel ==="
  uname -a
  echo -e "\n=== Disk Usage ==="
  df -h
  echo -e "\n=== Disk partitioning ==="
  lsblk
  echo -e "\n=== AlmaLinux/EL Packages ==="
  rpm -qa | grep -E 'almalinux|centos|rocky|oracle|redhat' | sort
  echo -e "\n=== Secure Boot Status ==="
  sudo mokutil --sb-state 2>/dev/null || echo "mokutil not available"
  echo -e "\n=== Installed Kernels ==="
  rpm -qa kernel
} > "${REPORT_DIR}/system-info.txt" 2>&1

# Create tarball
echo "- Creating archive..."
tar -czf "${REPORT_DIR}.tar.gz" "${REPORT_DIR}"
rm -rf "${REPORT_DIR}"

echo "Done! Please attach ${REPORT_DIR}.tar.gz to your bug report."
echo "Submit at: https://github.com/AlmaLinux/almalinux-deploy/issues"
```

### Where to Submit

1. **GitHub Issues**: [https://github.com/AlmaLinux/almalinux-deploy/issues](https://github.com/AlmaLinux/almalinux-deploy/issues)
2. **AlmaLinux Community Chat**: Join the `~migration` channel at [https://chat.almalinux.org/](https://chat.almalinux.org/)
3. **AlmaLinux Forums**: [https://forums.almalinux.org/](https://forums.almalinux.org/)

For general migration guidance, see the [AlmaLinux Migration Guide](https://wiki.almalinux.org/documentation/migration-guide.html).

When creating the issue, please include:
- A clear description of the problem
- Steps to reproduce the issue
- Source OS information (OS type and version before migration)
- All collected files from the bug report collection script

## Get Involved

Any contribution is welcome:

* Find and [report](https://github.com/AlmaLinux/almalinux-deploy/issues) bugs.
* Submit pull requests with bug fixes, improvements and new tests.
* Test it on different configurations and share your thoughts in
  [discussions](https://github.com/AlmaLinux/almalinux-deploy/discussions).

### Additional Resources

* **Official Migration Guide**: [AlmaLinux Wiki - Migration Guide](https://wiki.almalinux.org/documentation/migration-guide.html)
* **Community Chat**: Join the `~migration` channel on [AlmaLinux Community Chat](https://chat.almalinux.org/)
* **Forums**: [AlmaLinux Community Forums](https://forums.almalinux.org/)

Technology stack:

* The migration script is written in [Bash](https://www.gnu.org/software/bash/).
* We use [Bats](https://github.com/bats-core/bats-core) for unit tests.
* CI/CD: GitHub Actions for automated testing with Docker containers.

## Testing

The project uses a comprehensive automated testing approach with GitHub Actions CI/CD pipeline.

### Automated Testing (GitHub Actions)

The CI workflow runs automatically on:
- Every push to the master branch
- Every pull request to the master branch
- Weekly schedule (every Monday at 03:00 UTC)
- Manual workflow dispatch

### Test Suite Components

#### 1. **Static Code Analysis**
- **Tool**: [ShellCheck](https://www.shellcheck.net/)
- **Purpose**: Lints bash/shell scripts for common issues and best practices
- **Platform**: Ubuntu 24.04

#### 2. **Unit Tests**
- **Tool**: [Bats (Bash Automated Testing System)](https://github.com/bats-core/bats-core)
- **Test File**: `test_almalinux-deploy.bats`
- **Purpose**: Tests individual functions and components of the script
- **Platform**: Ubuntu 24.04

#### 3. **Integration Tests (Container-Based)**
The most comprehensive test suite that validates migration in Docker containers.

**Test Matrix:**
- **16 Operating Systems:**
  - Oracle Linux 8, 9, 10
  - RHEL UBI 8, 9, 10
  - CentOS Stream 8, 9, 10
  - Rocky Linux 8, 9, 10
  - Virtuozzo Linux 8, 9
  - MiracleLinux 8, 9

- **4 Platform Architectures:**
  - linux/amd64 (x86_64)
  - linux/arm64 (aarch64)
  - linux/ppc64le
  - linux/s390x

**Test Process:**
1. Creates Docker containers from source OS images
2. Installs required dependencies (dnf-plugins-core)
3. Runs the migration script with appropriate options
4. Verifies successful migration by checking:
   - System architecture matches expected platform
   - `/etc/almalinux-release` file exists and contains correct content
   - AlmaLinux GPG keys are properly installed

**Special Handling:**
- Automatically uses `--downgrade` flag for CentOS Stream migrations
- Handles CentOS Stream 8 mirror issues
- Applies workarounds for specific OS quirks

### Running Tests Locally

#### Run Unit Tests:
```bash
# Install Bats
sudo apt-get install bats  # Ubuntu/Debian
# or
brew install bats-core     # macOS

# Run the tests
bats test_almalinux-deploy.bats
```

#### Run Container-Based Tests:
```bash
# Example: Test Rocky Linux 9 migration
docker run --rm -it rockylinux/rockylinux:9 bash -c "
  curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh
  dnf install -y dnf-plugins-core
  bash almalinux-deploy.sh
  cat /etc/almalinux-release
"
```

### Test Coverage

The automated CI tests cover:
- ✅ All supported operating systems (8, 9, 10)
- ✅ All supported architectures (x86_64, aarch64, ppc64le, s390x)
- ✅ Container environments
- ✅ CentOS Stream downgrade scenarios
- ✅ Package installation and GPG key verification
- ✅ Multi-platform builds with QEMU emulation

**Note:** The integration tests run in Docker containers, so some features like kernel installation, GRUB updates, and EFI boot record management are automatically skipped by the script's container detection.

## CentOS 8 Migration Notes

This section contains specific information for migrating CentOS 8 systems to AlmaLinux.

### Minimum Version Requirements

CentOS 8.4 or higher is required to convert to AlmaLinux. It is recommended to update to 8.5 prior to migration, but not required if you are on at least CentOS 8.4. Always reboot after updates if your system received new kernel or core packages.

```shell
sudo dnf update -y
sudo reboot
```

### CentOS 8 Mirror Issues (EOL)

As of January 31, 2022, the CentOS 8 mirrorlists are offline due to CentOS 8 reaching End of Life. If you need to perform `dnf update -y` on an existing CentOS 8 system, you must update your DNF configuration files to point to the CentOS Vault.

#### Option 1: Use the `-f` Flag (Recommended)

The migration script has a built-in option to handle this automatically:

```bash
sudo bash almalinux-deploy.sh -f
```

This will fix the repository configuration and perform the necessary upgrade before migration.

#### Option 2: Manual Repository Fix

If you prefer to fix the repositories manually, use the following commands to point your system to the CentOS Vault:

```bash
# Fix BaseOS repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[baseos\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/BaseOS/$basearch/os' /etc/yum.repos.d/CentOS-Linux-BaseOS.repo

# Fix AppStream repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[appstream\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/AppStream/$basearch/os' /etc/yum.repos.d/CentOS-Linux-AppStream.repo

# Fix ContinuousRelease repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[cr\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/ContinuousRelease/$basearch/os' /etc/yum.repos.d/CentOS-Linux-ContinuousRelease.repo

# Fix Devel repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[devel\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/Devel/$basearch/os' /etc/yum.repos.d/CentOS-Linux-Devel.repo

# Fix Extras repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[extras\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/extras/$basearch/os' /etc/yum.repos.d/CentOS-Linux-Extras.repo

# Fix FastTrack repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[fasttrack\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/fasttrack/$basearch/os' /etc/yum.repos.d/CentOS-Linux-FastTrack.repo

# Fix HighAvailability repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[ha\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/HighAvailability/$basearch/os' /etc/yum.repos.d/CentOS-Linux-HighAvailability.repo

# Fix Plus repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[plus\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/centosplus/$basearch/os' /etc/yum.repos.d/CentOS-Linux-Plus.repo

# Fix PowerTools repository
sudo sed -i -e '/mirrorlist=http:\/\/mirrorlist.centos.org\/?release=$releasever&arch=$basearch&repo=/ s/^#*/#/' -e '/baseurl=http:\/\/mirror.centos.org\/$contentdir\/$releasever\// s/^#*/#/' -e '/^\[powertools\]/a baseurl=https://mirror.rackspace.com/centos-vault/8.5.2111/PowerTools/$basearch/os' /etc/yum.repos.d/CentOS-Linux-PowerTools.repo
```

After applying these fixes, you can proceed with the system update and migration:

```bash
sudo dnf clean all
sudo dnf update -y
sudo reboot
```

Then run the migration script normally:

```bash
sudo bash almalinux-deploy.sh
```

## License

Licensed under the GPLv3 license, see the [LICENSE](LICENSE) file for details.
