#!/usr/bin/env bash
set -eo pipefail

device1=''
device2=''
array='/dev/md/unidad3'
apply='no'
confirm=''

usage() {
    printf '%s\n' 'Uso: raid1_setup.sh --device1 /dev/sdb --device2 /dev/sdc [--array /dev/md/unidad3] [--apply --confirm ERASE_DATA_ON_SELECTED_DEVICES]'
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --device1) [ "$#" -ge 2 ] || fail 'Falta el disco 1'; device1="$2"; shift 2 ;;
        --device2) [ "$#" -ge 2 ] || fail 'Falta el disco 2'; device2="$2"; shift 2 ;;
        --array) [ "$#" -ge 2 ] || fail 'Falta la ruta del arreglo'; array="$2"; shift 2 ;;
        --apply) apply='yes'; shift ;;
        --confirm) [ "$#" -ge 2 ] || fail 'Falta la confirmación'; confirm="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Opción desconocida: $1" ;;
    esac
done

[ -n "$device1" ] || fail 'Debe indicar --device1'
[ -n "$device2" ] || fail 'Debe indicar --device2'
[ "$device1" != "$device2" ] || fail 'Los dos miembros deben ser dispositivos distintos'
case "$device1:$device2" in
    /dev/*:/dev/*) ;;
    *) fail 'Los miembros deben ser rutas explícitas bajo /dev' ;;
esac
case "$array" in
    /dev/md/*) ;;
    *) fail 'El arreglo debe estar bajo /dev/md' ;;
esac

if [ "$apply" = 'no' ]; then
    printf '[SIMULACIÓN] No se invocó mdadm ni se modificó ningún disco.\n'
    printf 'mdadm --create %s --metadata=1.2 --level=1 --raid-devices=2 %s %s\n' "$array" "$device1" "$device2"
    printf '[SIMULACIÓN] Para aplicar: revisar que ambos discos estén vacíos y añadir --apply --confirm ERASE_DATA_ON_SELECTED_DEVICES.\n'
    exit 0
fi

[ "$confirm" = 'ERASE_DATA_ON_SELECTED_DEVICES' ] || fail 'La operación real exige --confirm ERASE_DATA_ON_SELECTED_DEVICES'
[ "$EUID" -eq 0 ] || fail 'El modo real requiere root'
for tool in mdadm lsblk wipefs; do
    command -v "$tool" >/dev/null 2>&1 || fail "Falta el comando requerido: $tool"
done

for device in "$device1" "$device2"; do
    [ -b "$device" ] || fail "$device no es un dispositivo de bloque real"
    kind=$(lsblk -dnro TYPE "$device")
    [ "$kind" = 'disk' ] || fail "$device no es un disco completo; se rechazan particiones"
    signatures=$(wipefs -n -i -O TYPE "$device")
    [ -z "$signatures" ] || fail "$device contiene firmas detectables; operación cancelada"
    child_count=$(lsblk -nr -o NAME "$device" | wc -l)
    [ "$child_count" -le 1 ] || fail "$device contiene particiones o dispositivos hijos"
    mounts=$(lsblk -nrpo MOUNTPOINT "$device")
    if [ -n "$mounts" ]; then
        fail "$device o un hijo aparece montado"
    fi
done

[ ! -e "$array" ] || fail "El destino $array ya existe"
printf '[INFO] Se crearán metadatos RAID 1 en %s y %s.\n' "$device1" "$device2"
printf '[INFO] Verifique nuevamente los identificadores de dispositivo antes de aceptar.\n'
mdadm --create "$array" --metadata=1.2 --level=1 --raid-devices=2 "$device1" "$device2"
printf '[OK] Arreglo creado. Revise el estado antes de crear un sistema de archivos.\n'
printf '[INFO] Este script no formatea ni monta el arreglo.\n'