#!/usr/bin/env bash
# ==============================================================================
# Script: bajas.sh
# Descripción: Revocación segura de usuarios, terminación de procesos,
#              respaldo de directorio home y eliminación de cuenta.
# Entorno: Linux (Ubuntu/Debian)
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/bajas_usuarios.log"
readonly BACKUP_DIR="/var/backups/homes"

log() {
    local nivel="$1"
    local mensaje="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$nivel] $mensaje" | tee -a "$LOG_FILE"
}

validar_entorno() {
    if [[ $EUID -ne 0 ]]; then
        echo "[ERROR] Este script debe ejecutarse con privilegios de root (sudo)." >&2
        exit 1
    fi

    if [[ $# -ne 1 ]]; then
        echo "[ERROR] Parámetros insuficientes." >&2
        echo "Uso: $0 <nombre_usuario | ruta_archivo.csv>" >&2
        exit 1
    fi
}

eliminar_usuario() {
    local user="$1"

    if ! id "$user" >/dev/null 2>&1; then
        log "WARN" "El usuario '$user' no existe en el sistema. Omitiendo."
        return 0
    fi

    # 1. Bloquear cuenta inmediatamente
    passwd -l "$user" >/dev/null 2>&1 || true
    usermod -e 1 "$user" >/dev/null 2>&1 || true

    # 2. Terminar procesos activos
    pkill -9 -u "$user" >/dev/null 2>&1 || true

    # 3. Respaldar home si existe
    if [[ -d "/home/$user" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_file="$BACKUP_DIR/${user}_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$backup_file" -C "/home" "$user" 2>/dev/null || true
        log "INFO" "Directorio /home/$user respaldado en: $backup_file"
    fi

    # 4. Eliminar cuenta y home original
    userdel -r "$user"
    log "INFO" "Usuario '$user' eliminado del sistema."
}

main() {
    validar_entorno "$@"
    local target="$1"

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    if [[ -f "$target" ]]; then
        log "INFO" "=== Procesando bajas por lote desde archivo: $target ==="
        while IFS=',' read -r user _resto || [[ -n "$user" ]]; do
            user=$(echo "$user" | tr -d '\r' | xargs)
            [[ "$user" == "usuario" || -z "$user" || "$user" =~ ^[[:space:]]*# ]] && continue
            eliminar_usuario "$user"
        done < "$target"
    else
        log "INFO" "=== Procesando baja individual para: $target ==="
        eliminar_usuario "$target"
    fi

    log "INFO" "=== Operación de bajas finalizada ==="
}

main "$@"
