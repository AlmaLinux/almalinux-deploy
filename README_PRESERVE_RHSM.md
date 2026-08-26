The '--preserve-rhsm' option is used to preserve the Red Hat Subscription Manager (RHSM) configuration.
This option totally removes all the intelligence the authors have put into the script to manage repositories.

In addition the script will install `python3-dnf-plugin-post-transaction-actions `and create `/etc/dnf/plugins/post-transaction-actions.d/almalinux-repos.conf`.  
`/etc/dnf/plugins/post-transaction-actions.d/almalinux-repos.conf` will remove `/etc/yum.repos.d/almalinux*.repo` files as soon as an AlmaLinux release or repos RPM creates them.  
This enables your servers to not have a proxy setup in `dnf.conf` or other access to the internet.

You, the Administrator, must make sure your systems are ready for migration and that the repositories are configured correctly.  
You will probably do this by running a preparation script on the target server.

An simple example will be:
```
#!/usr/bin/bash

. /etc/os-release
OS_VER=${VERSION_ID%.*}

CodeReadyRepoInstalled=$(/usr/bin/dnf repolist | /usr/bin/awk '/codeready-builder/{print $1}')
if [ "${CodeReadyRepoInstalled}" ]; then
  case ${OS_VER} in
    8)
      CRB_REPO="--enable=ORG_AlmaLinux_${OS_VER}_PowerTools --disable ${CodeReadyRepoInstalled}"
      ;;
    9|10)
      CRB_REPO="--enable=ORG_AlmaLinux_${OS_VER}_CRB --disable ${CodeReadyRepoInstalled}"
      ;;
  esac
fi

# We have no satellite-client repository in AlmaLinux
/usr/bin/dnf remove $(/usr/bin/dnf list installed | /usr/bin/awk '/satellite-client/{print $1}')
/usr/bin/dnf upgrade -y >/dev/null || exit 1

# Your Repo naming is different. This is an example only.
/usr/bin/subscription-manager repos --enable ORG_AlmaLinux_${OS_VER}_BaseOS_RPMs \
                                    --enable ORG_AlmaLinux_${OS_VER}_AppStream_RPMs \
                                    --enable ORG_EPEL_EPEL${OS_VER} \
                                    --enable ORG_Zabbix_7_4-AL${OS_VER} \
                                    --disable rhel-${OS_VER}-for-x86_64-appstream-rpms \
                                    --disable rhel-${OS_VER}-for-x86_64-baseos-rpms \
                                    --disable satellite-client-6-for-rhel-${OS_VER}-x86_64-rpms \
                                    --disable ORG_Zabbix_7_4-RHEL${OS_VER} ${CRB_REPO}
```

The Zabbix repository is shown here as an example of a non RedHat repository that has a RedHat and AlmaLinux version.

Download the almalinux-deploy.sh script from your internal systems (pub directory of the foreman server is a suggestion);  
  and run it with the '--preserve-rhsm' option.
