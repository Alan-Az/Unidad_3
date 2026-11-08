#!/usr/bin/env bash
# ==============================================================================
# Script: altas.sh
# Descripción: Creación automatizada de cuentas de usuario por lotes desde CSV.
# Entorno: Linux (Ubuntu/Debian)
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/altas_usuarios.log"
readonly CREDENTIALS_FILE="/root/credenciales_temporales.txt"

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
        echo "[ERROR] Parámetro faltante." >&2
        echo "Uso: $0 <ruta_archivo.csv>" >&2
        exit 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "[ERROR] El archivo '$1' no existe." >&2
        exit 1
    fi
}

asegurar_grupo() {
    local grupo="$1"
    if ! getent group "$grupo" >/dev/null 2>&1; then
        groupadd "$grupo"
        log "INFO" "Grupo '$grupo' creado."
    fi
}

crear_usuario() {
    local user="$1"
    local nombre="$2"
    local prim_group="$3"
    local sec_groups="$4"
    local dias_exp="$5"

    if id "$user" >/dev/null 2>&1; then
        log "WARN" "El usuario '$user' ya existe. Omitiendo."
        return 0
    fi

    asegurar_grupo "$prim_group"

    # Procesar grupos secundarios separados por coma
    local clean_sec_groups=""
    local IFS_ORIG="$IFS"
    IFS=','
    for g in $sec_groups; do
        g=$(echo "$g" | xargs)
        if [[ -n "$g" ]]; then
            asegurar_grupo "$g"
            if [[ -z "$clean_sec_groups" ]]; then
                clean_sec_groups="$g"
            else
                clean_sec_groups="$clean_sec_groups,$g"
            fi
        fi
    done
    IFS="$IFS_ORIG"

    # Alta en el sistema con home interactivo (-m) y shell bash (-s)
    if [[ -n "$clean_sec_groups" ]]; then
        useradd -m -s /bin/bash -g "$prim_group" -G "$clean_sec_groups" -c "$nombre" "$user"
    else
        useradd -m -s /bin/bash -g "$prim_group" -c "$nombre" "$user"
    fi

    # Generación de contraseña temporal con entropía alta
    local temp_pass="Temp.$(openssl rand -hex 4)A1!"
    echo "$user:$temp_pass" | chpasswd

    # Forzar expiración inmediata para exigir cambio en primer inicio
    # Nota: chage -d 0 marca la contraseña como vencida desde el 01/01/1970.
    # En Linux esto puede bloquear el login normal por SSH.
    # Para el video, el administrador entra con: sudo su - <usuario>
    # y cambia la contraseña con: passwd
    chage -d 0 "$user"

    # Configurar fecha límite de cuenta activa
    local fecha_exp
    fecha_exp=$(date -d "+$dias_exp days" +%Y-%m-%d)
    chage -E "$fecha_exp" "$user"

    # Aislamiento estricto de directorio
    chmod 700 "/home/$user"
    chown "$user:$prim_group" "/home/$user"

    log "INFO" "Usuario '$user' creado exitosamente | Grupo: $prim_group | Expira: $fecha_exp"
    echo "Usuario: $user | Password Temporal: $temp_pass | Expira: $fecha_exp" >> "$CREDENTIALS_FILE"
}

main() {
    validar_entorno "$@"
    local csv_file="$1"

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
    touch "$CREDENTIALS_FILE" && chmod 600 "$CREDENTIALS_FILE"

    log "INFO" "=== Iniciando aprovisionamiento masivo desde: $csv_file ==="

    while IFS=',' read -r user nombre prim_group sec_groups dias_exp || [[ -n "$user" ]]; do
        user=$(echo "$user" | tr -d '\r' | xargs)
        nombre=$(echo "$nombre" | tr -d '\r' | xargs)
        prim_group=$(echo "$prim_group" | tr -d '\r' | xargs)
        sec_groups=$(echo "$sec_groups" | tr -d '\r' | xargs)
        dias_exp=$(echo "$dias_exp" | tr -d '\r' | xargs)

        [[ "$user" == "usuario" || -z "$user" || "$user" =~ ^[[:space:]]*# ]] && continue

        crear_usuario "$user" "$nombre" "$prim_group" "$sec_groups" "$dias_exp"
    done < "$csv_file"

    log "INFO" "=== Proceso finalizado. Credenciales registradas en: $CREDENTIALS_FILE ==="
}

main "$@"