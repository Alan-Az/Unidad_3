#!/usr/bin/env bash
# ==============================================================================
# Script: configurar_seguridad.sh
# Descripción: Aplica directivas de sudoers, restricciones de horario (pam_time)
#              y bloqueo por intentos fallidos (pam_faillock).
# Entorno: Linux (Ubuntu/Debian)
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Este script debe ejecutarse con sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Configurando Reglas de Sudoers ==="
SUDOERS_SRC="$SCRIPT_DIR/sudoers_tarea31"
SUDOERS_DEST="/etc/sudoers.d/tarea31_seguridad"

if [[ -f "$SUDOERS_SRC" ]]; then
    cp "$SUDOERS_SRC" "$SUDOERS_DEST"
    chmod 0440 "$SUDOERS_DEST"
    if visudo -cf "$SUDOERS_DEST"; then
        echo "[OK] Reglas de sudoers instaladas y validadas con visudo."
    else
        echo "[ERROR] Error de sintaxis en sudoers. Eliminando archivo por seguridad."
        rm -f "$SUDOERS_DEST"
        exit 1
    fi
fi

echo "=== 2. Configurando Horarios de Acceso (pam_time) ==="
TIME_SRC="$SCRIPT_DIR/time.conf.snippet"
TIME_DEST="/etc/security/time.conf"

if [[ -f "$TIME_SRC" ]]; then
    cp "$TIME_DEST" "${TIME_DEST}.bak_$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    cat "$TIME_SRC" >> "$TIME_DEST"
    echo "[OK] Directiva agregada a $TIME_DEST"
fi

# Habilitar pam_time en /etc/pam.d/login y /etc/pam.d/sshd si no existe
for pam_target in /etc/pam.d/login /etc/pam.d/sshd /etc/pam.d/common-account; do
    if [[ -f "$pam_target" ]]; then
        if ! grep -q "pam_time.so" "$pam_target"; then
            echo "account required pam_time.so" >> "$pam_target"
            echo "[OK] Módulo pam_time.so vinculado en $pam_target"
        fi
    fi
done

echo "=== 3. Configurando Bloqueo por Intentos Fallidos (pam_faillock) ==="
FAILLOCK_SRC="$SCRIPT_DIR/faillock.conf.snippet"
FAILLOCK_DEST="/etc/security/faillock.conf"

if [[ -f "$FAILLOCK_SRC" ]]; then
    cp "$FAILLOCK_SRC" "$FAILLOCK_DEST"
    chmod 0644 "$FAILLOCK_DEST"
    echo "[OK] Archivo $FAILLOCK_DEST actualizado."
fi

# Asegurar pam_faillock en Ubuntu mediante pam-auth-update si está disponible
if command -v pam-auth-update >/dev/null 2>&1; then
    pam-auth-update --enable faillock 2>/dev/null || true
fi

echo "=== Configuración de directivas de seguridad finalizada con éxito ==="

