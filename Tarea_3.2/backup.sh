#!/usr/bin/env bash
# Backup and restore user-selected paths. This script never mounts devices or deletes old archives.
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
    printf '%s\n' \
      'Uso:' \
      '  backup.sh --source DIR --destination DIR [--state FILE] [--mode full|incremental] [--secondary DIR]' \
      '  backup.sh --restore ARCHIVE --target DIR --force' \
      'Una copia incremental requiere una completa anterior. Restaura primero la completa y luego cada incremental en orden.' \
      'El destino secundario debe estar montado previamente.'
}
fail() { printf '[ERROR] %s\n' "$1" >&2; exit 2; }
log() {
    local logfile="$1"; shift
    printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "$logfile"
}
need_value() { [[ $# -ge 2 && -n "$2" ]] || fail "Falta el valor para $1"; }

source_dir=''
destination=''
state_file=''
mode='full'
secondary=''
restore_archive=''
target_dir=''
force=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source) need_value "$@"; source_dir="$2"; shift 2 ;;
        --destination) need_value "$@"; destination="$2"; shift 2 ;;
        --state) need_value "$@"; state_file="$2"; shift 2 ;;
        --mode) need_value "$@"; mode="$2"; shift 2 ;;
        --secondary) need_value "$@"; secondary="$2"; shift 2 ;;
        --restore) need_value "$@"; restore_archive="$2"; shift 2 ;;
        --target) need_value "$@"; target_dir="$2"; shift 2 ;;
        --force) force=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Opción desconocida: $1" ;;
    esac
done

if [[ -n "$restore_archive" ]]; then
    [[ $force == 1 ]] || fail "La restauración requiere --force para confirmar el destino elegido."
    [[ -f "$restore_archive" ]] || fail "No existe el archivo de respaldo."
    [[ -n "$target_dir" ]] || fail "--target es obligatorio al restaurar."
    [[ -f "$restore_archive.sha256" ]] || fail "Falta el archivo de verificación SHA-256."
    IFS=' ' read -r expected_hash _ < "$restore_archive.sha256"
    actual_line=$(sha256sum -- "$restore_archive")
    IFS=' ' read -r actual_hash _ <<< "$actual_line"
    [[ "$expected_hash" == "$actual_hash" ]] || fail "La suma SHA-256 no coincide; no se extrajo nada."

    archive_listing=$(tar -tzf "$restore_archive") || fail "El archivo tar no se pudo inspeccionar."
    while IFS= read -r entry; do
        case "$entry" in
            /*|../*|*/../*|*/..|..) fail "El archivo contiene una ruta insegura: $entry" ;;
        esac
    done <<< "$archive_listing"

    mkdir -p -- "$target_dir"
    target_real=$(realpath -e -- "$target_dir") || fail "No se pudo resolver el destino de restauración."
    restore_log="$(dirname -- "$restore_archive")/restore.log"
    log "$restore_log" "Inicio de restauración: $(basename -- "$restore_archive")"
    tar --extract --gzip --file="$restore_archive" --directory="$target_real" \
        --no-same-owner --no-same-permissions --listed-incremental=/dev/null
    log "$restore_log" "Restauración completada en: $target_real"
    exit 0
fi

[[ -d "$source_dir" ]] || fail "--source debe ser una carpeta existente."
[[ -n "$destination" ]] || fail "--destination es obligatorio."
[[ "$mode" == 'full' || "$mode" == 'incremental' ]] || fail "--mode debe ser full o incremental."
source_real=$(realpath -e -- "$source_dir") || fail "No se pudo resolver la carpeta de origen."
destination_real=$(realpath -m -- "$destination") || fail "No se pudo resolver el destino."
case "$destination_real/" in
    "$source_real/"*) fail "El destino no puede estar dentro del origen." ;;
esac
[[ "$source_real" != "$destination_real" ]] || fail "El origen y el destino deben ser distintos."
if [[ -n "$secondary" ]]; then
    [[ -d "$secondary" ]] || fail "El destino secundario debe existir y estar montado previamente."
    secondary_real=$(realpath -e -- "$secondary") || fail "No se pudo resolver el destino secundario."
    [[ "$secondary_real" != "$source_real" ]] || fail "El destino secundario no puede ser el origen."
    case "$secondary_real/" in "$source_real/"*) fail "El destino secundario no puede estar dentro del origen." ;; esac
    [[ "$secondary_real" != "$destination_real" ]] || fail "El destino secundario ya es el destino principal."
    case "$secondary_real/" in "$destination_real/"*) fail "El destino secundario no puede estar dentro del destino principal." ;; esac
fi
state_file=$(realpath -m -- "$state_file")
case "$state_file" in "$source_real"/*) fail "El estado no puede guardarse dentro del origen." ;; esac
[[ "$state_file" != "$source_real" ]] || fail "El estado no puede reemplazar el origen."
mkdir -p -- "$destination"
destination_real=$(realpath -e -- "$destination") || fail "No se pudo resolver el destino después de crearlo."
mkdir -p -- "$(dirname -- "$state_file")"
logfile="$destination_real/backup.log"
lock_dir="$destination_real/.backup.lock"
mkdir -- "$lock_dir" 2>/dev/null || fail "Ya existe un proceso de respaldo activo."
tmp_state=''
tmp_archive=''
cleanup() {
    [[ -z "$tmp_state" || ! -e "$tmp_state" ]] || rm -f -- "$tmp_state"
    [[ -z "$tmp_archive" || ! -e "$tmp_archive" ]] || rm -f -- "$tmp_archive"
    rmdir -- "$lock_dir" 2>/dev/null || true
}
trap cleanup EXIT

archive_mode="$mode"
if [[ "$mode" == 'incremental' && ! -f "$state_file" ]]; then
    archive_mode='full'
    log "$logfile" "No existe estado anterior; la primera ejecución incremental se guardará como completa."
fi

timestamp="$(date -u '+%Y%m%dT%H%M%S')_$$"
archive_name="unidad3_${timestamp}_${archive_mode}.tar.gz"
archive_path="$destination_real/$archive_name"
tmp_archive="$destination_real/.$archive_name.part"
tmp_state="$state_file.tmp.$$"
if [[ "$archive_mode" == 'incremental' ]]; then
    cp -- "$state_file" "$tmp_state"
else
    : > "$tmp_state"
fi

tar --create --gzip --file="$tmp_archive" --listed-incremental="$tmp_state" \
    --directory="$source_real" . || fail "GNU tar no pudo crear el archivo."
IFS=' ' read -r archive_hash _ <<< "$(sha256sum -- "$tmp_archive")"
mv -- "$tmp_archive" "$archive_path"
tmp_archive=''
printf '%s  %s\n' "$archive_hash" "$archive_name" > "$archive_path.sha256.tmp"
mv -- "$archive_path.sha256.tmp" "$archive_path.sha256"
mv -- "$tmp_state" "$state_file"
tmp_state=''
log "$logfile" "Respaldo $archive_mode creado y verificado: $archive_name"

if [[ -n "$secondary" ]]; then
    if cp -- "$archive_path" "$secondary_real/" && cp -- "$archive_path.sha256" "$secondary_real/"; then
        IFS=' ' read -r source_secondary_hash _ < "$archive_path.sha256"
        IFS=' ' read -r copied_secondary_hash _ <<< "$(sha256sum -- "$secondary_real/$archive_name")"
        IFS=' ' read -r sidecar_secondary_hash _ < "$secondary_real/$archive_name.sha256"
        if [[ "$source_secondary_hash" == "$copied_secondary_hash" && "$source_secondary_hash" == "$sidecar_secondary_hash" ]]; then
            log "$logfile" "Copia secundaria transferida y verificada: $secondary_real"
        else
            log "$logfile" "ERROR: la suma SHA-256 de la copia secundaria no coincide."
            exit 1
        fi
    else
        log "$logfile" "ERROR: el respaldo local existe, pero falló la copia secundaria."
        exit 1
    fi
fi