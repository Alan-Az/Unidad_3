#!/usr/bin/env bash
# Read-only check. This script does not enable or change quotas.
set -Eeuo pipefail
if [[ $# -ne 1 ]]; then
    printf 'Uso: %s PUNTO_DE_MONTAJE\n' "$0" >&2
    exit 2
fi
command -v findmnt >/dev/null 2>&1 || { printf 'Falta findmnt.\n' >&2; exit 2; }
command -v repquota >/dev/null 2>&1 || { printf 'Falta repquota.\n' >&2; exit 2; }
mountpoint=$(findmnt -n -o TARGET --target "$1") || { printf 'No se encontró el montaje.\n' >&2; exit 1; }
fstype=$(findmnt -n -o FSTYPE --target "$mountpoint")
options=$(findmnt -n -o OPTIONS --target "$mountpoint")
[[ "$fstype" == ext4 ]] || { printf 'Se esperaba ext4; detectado: %s\n' "$fstype" >&2; exit 1; }
[[ ",$options," == *',usrquota,'* && ",$options," == *',grpquota,'* ]] || {
    printf 'El montaje no anuncia usrquota y grpquota: %s\n' "$options" >&2
    exit 1
}
printf 'Montaje: %s (%s)\n' "$mountpoint" "$fstype"
quotaon -p -u "$mountpoint"
quotaon -p -g "$mountpoint"
repquota -ug "$mountpoint"