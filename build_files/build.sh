#!/usr/bin/env bash
set -euo pipefail

# Make installs leaner
echo 'tsflags=nodocs' | tee -a /etc/dnf/dnf.conf >/dev/null

# Ensure dnf5 exists (Fedora 41+ has it; link fallback for older)
command -v dnf5 >/dev/null 2>&1 || ln -sf /usr/bin/dnf /usr/bin/dnf5

# Core packages (many already present in fedora-bootc; harmless if already installed)
dnf5 -y --setopt=install_weak_deps=False install \
  kernel-core kernel-modules systemd dracut openssh-server \
  policycoreutils selinux-policy-targeted coreutils util-linux \
  systemd-networkd systemd-resolved systemd-udev \
  nfs-utils iproute iptables ipset conntrack-tools ethtool \
  cockpit cockpit-storaged \
  cloud-init cloud-utils-growpart gdisk \
  jq curl shadow-utils || true

# NVIDIA repos (driver + container toolkit) — best effort on both arches
cat >/etc/yum.repos.d/negativo17-nvidia.repo <<'R'
[nvidia]
name=negativo17 - NVIDIA
baseurl=https://negativo17.org/repos/nvidia/fedora-$releasever/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://negativo17.org/repos/RPM-GPG-KEY-negativo17
R

cat >/etc/yum.repos.d/nvidia-container-toolkit.repo <<'R'
[nvidia-container-toolkit]
name=NVIDIA Container Toolkit
baseurl=https://nvidia.github.io/libnvidia-container/stable/fedora/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=https://nvidia.github.io/libnvidia-container/gpgkey
R

if ! dnf5 -y --setopt=install_weak_deps=False install \
      nvidia-driver-cuda nvidia-container-toolkit nvidia-container-toolkit-selinux; then
  echo "WARN: NVIDIA packages not available for this Fedora/arch right now; continuing"
fi

# OpenZFS repo + packages (best effort on both arches)
if dnf5 -y --setopt=install_weak_deps=False install \
     "https://zfsonlinux.org/fedora/zfs-release-2-8$(rpm --eval '%{dist}').noarch.rpm"; then
  if ! dnf5 -y --setopt=install_weak_deps=False install zfs zfs-dracut; then
    echo "WARN: ZFS packages not currently available for this kernel/arch; continuing"
  fi
else
  echo "WARN: Could not install zfs-release repo RPM; continuing"
fi

# Don’t let rpm-ostreed manage updates on bootc systems
systemctl disable rpm-ostreed.service rpm-ostreed-automatic.timer || true

# Clean caches
dnf5 clean all || true
rm -rf /var/cache/dnf/* /var/lib/dnf/* || true
