#!/usr/bin/env bash
set -eo pipefail

array='/dev/md/unidad3'
if [ "$#" -gt 0 ]; then
    [ "$#" -eq 2 ] && [ "$1" = '--array' ] || { printf '%s\n' 'Uso: raid1_status.sh [--array /dev/md/unidad3]' >&2; exit 2; }
    array="$2"
fi
case "$array" in /dev/md/*) ;; *) printf '%s\n' 'El arreglo debe estar bajo /dev/md' >&2; exit 2 ;; esac
command -v mdadm >/dev/null 2>&1 || { printf '%s\n' 'No se encontró mdadm; ejecute esta consulta en el servidor Linux.' >&2; exit 2; }
exec mdadm --detail "$array"