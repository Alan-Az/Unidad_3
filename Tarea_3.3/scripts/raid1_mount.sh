#!/usr/bin/env bash
set -eo pipefail

device='/dev/md/unidad3'
mountpoint='/srv/raid1'
apply='no'
confirm=''

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --device) [ "$#" -ge 2 ] || fail 'Falta el dispositivo'; device="$2"; shift 2 ;;
        --mountpoint) [ "$#" -ge 2 ] || fail 'Falta el punto de montaje'; mountpoint="$2"; shift 2 ;;
        --apply) apply='yes'; shift ;;
        --confirm) [ "$#" -ge 2 ] || fail 'Falta la confirmación'; confirm="$2"; shift 2 ;;
        --help|-h) printf '%s\n' 'Uso: raid1_mount.sh [--device /dev/md/unidad3] [--mountpoint /srv/raid1] [--apply --confirm MOUNT_EXISTING_ARRAY]'; exit 0 ;;
        *) fail "Opción desconocida: $1" ;;
    esac
done

case "$device" in /dev/md/*) ;; *) fail 'El origen debe estar bajo /dev/md' ;; esac
case "$mountpoint" in /*) ;; *) fail 'El punto de montaje debe ser una ruta absoluta' ;; esac
[ "$mountpoint" != '/' ] || fail 'No se permite usar la raíz como punto de montaje'

if [ "$apply" = 'no' ]; then
    printf '[SIMULACIÓN] No se montó ningún sistema de archivos.\n'
    printf 'mount %s %s\n' "$device" "$mountpoint"
    printf '[SIMULACIÓN] El arreglo debe existir y tener sistema de archivos antes del montaje.\n'
    exit 0
fi

[ "$confirm" = 'MOUNT_EXISTING_ARRAY' ] || fail 'El montaje real exige --confirm MOUNT_EXISTING_ARRAY'
[ "$EUID" -eq 0 ] || fail 'El modo real requiere root'
[ -b "$device" ] || fail "$device no existe como dispositivo de bloque"
command -v blkid >/dev/null 2>&1 || fail 'Falta blkid'
command -v mount >/dev/null 2>&1 || fail 'Falta mount'
command -v findmnt >/dev/null 2>&1 || fail 'Falta findmnt'
[ ! -L "$mountpoint" ] || fail 'No se monta sobre un enlace simbólico'
if findmnt -rn -M "$mountpoint" >/dev/null 2>&1; then
    fail "$mountpoint ya está montado"
fi
[ ! -e "$mountpoint" ] || fail 'El punto de montaje ya existe; seleccione una ruta nueva para no ocultar archivos'
fs_type=$(blkid -o value -s TYPE "$device")
case "$fs_type" in ext4|xfs) ;; *) fail "Sistema de archivos no permitido o inexistente: $fs_type" ;; esac
mkdir -p "$mountpoint"
mount "$device" "$mountpoint"
printf '[OK] Montaje realizado. No se modificó /etc/fstab.\n'