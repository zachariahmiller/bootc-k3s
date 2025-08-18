#!/usr/bin/env bash
set -euo pipefail
POOL_NAME="${POOL_NAME:-tank}"
POOL_LEVEL="${POOL_LEVEL:-auto}"   # auto|single|mirror|raidz1|raidz2
DISK_FILTER="${DISK_FILTER:-^/dev/(nvme[^p]|sd|vd)[a-z]+$}"
WIPE_DISKS="${WIPE_DISKS:-false}"

systemctl start zfs-import-scan.service || true
if zpool list -H 2>/dev/null | grep -q .; then
  echo "ZFS: pool(s) present; skip create."
  exit 0
fi

mapfile -t candidates < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -E "${DISK_FILTER}")
root_disk=$(lsblk -no PKNAME / | head -n1 || true)
candidates=( $(printf "%s\n" "${candidates[@]}" | grep -vE "${root_disk:-^$}") )
count=${#candidates[@]}
(( count == 0 )) && { echo "ZFS: no extra disks; skipping."; exit 0; }

if [[ "${WIPE_DISKS}" == "true" ]]; then
  for d in "${candidates[@]}"; do sgdisk --zap-all "$d" || true; wipefs -a "$d" || true; done
fi

case "${POOL_LEVEL}" in
  single) layout=( "${candidates[0]}" );;
  mirror) layout=( mirror "${candidates[@]}" );;
  raidz1) layout=( raidz1 "${candidates[@]}" );;
  raidz2) layout=( raidz2 "${candidates[@]}" );;
  auto)
    if   (( count == 1 )); then layout=( "${candidates[0]}" )
    elif (( count == 2 )); then layout=( mirror "${candidates[@]}" )
    elif (( count == 3 )); then layout=( raidz1 "${candidates[@]}" )
    else layout=( raidz2 "${candidates[@]}" ); fi ;;
  *) echo "ZFS: unknown POOL_LEVEL=${POOL_LEVEL}"; exit 1;;
esac

zpool create -f "${POOL_NAME}" "${layout[@]}"
zfs set mountpoint=/"${POOL_NAME}" "${POOL_NAME}"
zfs create -o mountpoint=/"${POOL_NAME}"/data "${POOL_NAME}"/data || true
systemctl start zfs-mount.service
