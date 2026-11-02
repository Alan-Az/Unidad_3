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
        echo "[ERROR] Uso incorrecto." >&2
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

    IFS=',' read -ra arr_sec <<< "$sec_groups"
    for g in "${arr_sec[@]}"; do
        [[ -n "$g" ]] && asegurar_grupo "$g"
    done

    useradd -m -s /bin/bash -g "$prim_group" -G "$sec_groups" -c "$nombre" "$user"

    local temp_pass
    temp_pass=$(openssl rand -base64 12)
    echo "$user:$temp_pass" | chpasswd

    # Forzar cambio de contraseña en el primer inicio de sesión
    chage -d 0 "$user"

    # Configurar fecha de expiración de la cuenta
    local fecha_exp
    fecha_exp=$(date -d "+$dias_exp days" +%Y-%m-%d)
    chage -E "$fecha_exp" "$user"

    # Aislamiento estricto de directorio home (solo propietario)
    chmod 700 "/home/$user"
    chown "$user:$prim_group" "/home/$user"

    log "INFO" "Usuario '$user' creado exitosamente | Grupo: $prim_group | Expira: $fecha_exp"
    echo "Usuario: $user | Password Temporal: $temp_pass | Expira: $fecha_exp" >> "$CREDENTIALS_FILE"
}

main() {
    validar_entorno "$@"
    local csv_file="$1"

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    touch "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    log "INFO" "=== Iniciando aprovisionamiento masivo desde: $csv_file ==="

    local num_linea=0
    while IFS=',' read -r user nombre prim_group sec_groups dias_exp || [[ -n "$user" ]]; do
        ((num_linea++))
        # Omitir cabecera y líneas vacías o comentadas
        [[ $num_linea -eq 1 && "$user" == "usuario" ]] && continue
        [[ -z "$user" || "$user" =~ ^[[:space:]]*# ]] && continue

        # Limpiar posibles retornos de carro de Windows (\r) y espacios
        user=$(echo "$user" | tr -d '\r' | xargs)
        nombre=$(echo "$nombre" | tr -d '\r' | xargs)
        prim_group=$(echo "$prim_group" | tr -d '\r' | xargs)
        sec_groups=$(echo "$sec_groups" | tr -d '\r' | xargs)
        dias_exp=$(echo "$dias_exp" | tr -d '\r' | xargs)

        crear_usuario "$user" "$nombre" "$prim_group" "$sec_groups" "$dias_exp"
    done < "$csv_file"

    log "INFO" "=== Proceso finalizado. Credenciales registradas en: $CREDENTIALS_FILE ==="
}

main "$@"

