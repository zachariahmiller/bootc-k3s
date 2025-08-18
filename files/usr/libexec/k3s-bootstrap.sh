#!/usr/bin/env bash
set -euo pipefail
cfg_dir="/etc/rancher/k3s"
mkdir -p "$cfg_dir"
[ -f "$cfg_dir/config.yaml" ] || cp -n /usr/etc/rancher/k3s/config.yaml "$cfg_dir/config.yaml"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server " sh -
systemctl enable --now k3s.service
