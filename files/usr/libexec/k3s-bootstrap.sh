#!/usr/bin/env bash
set -euo pipefail
cfg_dir="/etc/rancher/k3s"
mkdir -p "$cfg_dir"
# seed default if none (moved from /usr/etc to /usr/share to satisfy bootc lint)
if [ ! -f "$cfg_dir/config.yaml" ] && [ -f "/usr/share/bootc-k3s/k3s-config.yaml" ]; then
  cp -n /usr/share/bootc-k3s/k3s-config.yaml "$cfg_dir/config.yaml"
fi
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server " sh -
systemctl enable --now k3s.service
