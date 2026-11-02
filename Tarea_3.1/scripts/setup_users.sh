#!/usr/bin/env bash
# Automated user provisioning, deprovisioning, and security hardening.
# Tiers: 1. direccion, 2. gerencia, 3. operaciones, 4. soporte.

set -euo pipefail

# Visual log helpers
log_info()    { printf "\033[1;34m[INFO]\033[0m    %s\n" "$*"; }
log_step()    { printf "\033[1;36m[PASO]\033[0m    %s\n" "$*"; }
log_create()  { printf "\033[1;32m[CREAR]\033[0m   %s\n" "$*"; }
log_update()  { printf "\033[1;33m[EDITAR]\033[0m  %s\n" "$*"; }
log_delete()  { printf "\033[1;31m[BAJA]\033[0m    %s\n" "$*"; }
log_sec()     { printf "\033[1;35m[SEGURIDAD]\033[0m %s\n" "$*"; }
log_success() { printf "\033[1;32m[EXITO]\033[0m   %s\n" "$*"; }
log_warn()    { printf "\033[1;33m[AVISO]\033[0m   %s\n" "$*"; }

# Self-heal CRLF
if grep -q $'\r' "$0" 2>/dev/null; then
    sed -i 's/\r$//' "$0" 2>/dev/null || true
fi

# Load .env if present
ENV_FILE="$(dirname "$0")/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source <(grep -v '^#' "$ENV_FILE" | sed -e 's/\r$//')
    set +a
fi

DRY_RUN="${DRY_RUN:-0}"
TEMP_PASS="${TEMP_PASS:-TempPass2026!}"
LOCKOUT_MAX_ATTEMPTS="${LOCKOUT_MAX_ATTEMPTS:-3}"
LOCKOUT_DURATION_MINUTES="${LOCKOUT_DURATION_MINUTES:-15}"
LOCKOUT_SECONDS=$(( LOCKOUT_DURATION_MINUTES * 60 ))

# Auto-enable DRY_RUN on Windows Git Bash / MSYS
if ! command -v useradd >/dev/null 2>&1; then
    if [[ "$DRY_RUN" != "1" ]]; then
        log_warn "Binario nativo 'useradd' no encontrado (Git Bash/MSYS). Activando DRY_RUN=1."
        DRY_RUN="1"
    fi
fi

run_cmd() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf "         \033[2m[SIMULACION] %s\033[0m\n" "$*"
    else
        "$@"
    fi
}

if [[ "$DRY_RUN" != "1" && "${EUID:-$(id -u)}" -ne 0 ]]; then
    printf "\033[1;31m[ERROR]\033[0m Permisos insuficientes. Ejecute con: sudo bash %s\n" "$0" >&2
    exit 1
fi

TARGET_GROUPS=("direccion" "gerencia" "operaciones" "soporte" "sudo" "auditoria_finanzas" "uso_operaciones" "impresoras")

# 9 functional operational roles (removed redundant read-only roles)
TARGET_USERS=(
    "ceo|direccion|sudo,gerencia,operaciones,soporte,auditoria_finanzas,uso_operaciones,impresoras|2028-12-31|CEO - Estrategia y Vision Global"
    "coo|direccion|gerencia,operaciones,soporte,auditoria_finanzas,uso_operaciones,impresoras|2028-12-31|COO - Direccion de Operaciones"
    "pm_gerente|gerencia|operaciones,auditoria_finanzas,uso_operaciones,impresoras|2027-06-30|Project Manager - Gestion de Proyectos"
    "tech_lead|gerencia|operaciones,uso_operaciones,impresoras|2027-06-30|Lead Developer - Liderazgo Tecnico"
    "esp_operativo|operaciones|uso_operaciones,impresoras|2027-01-31|Especialista Operativo / Dev / Diseno"
    "esp_soporte|operaciones|uso_operaciones,impresoras|2027-01-31|Especialista en Atencion al Cliente / Soporte"
    "rh_talento|soporte|impresoras|2027-12-31|Recursos Humanos y Talento"
    "ti_secops|soporte|sudo,direccion,gerencia,operaciones,auditoria_finanzas,uso_operaciones,impresoras|2028-12-31|TI y Seguridad Informatica (Sysadmin / SecOps)"
    "legal_compliance|soporte|auditoria_finanzas,impresoras|2027-12-31|Legal y Cumplimiento (Compliance)"
)

# Mode: Deprovision / Baja de usuarios (--deprovision or --remove)
if [[ "${1:-}" == "--deprovision" || "${1:-}" == "--remove" || "${1:-}" == "-d" ]]; then
    target_to_remove="${2:-all}"
    log_step "Iniciando proceso de BAJA de usuarios (Objetivo: $target_to_remove)..."
    
    remove_single_user() {
        local u="$1"
        log_delete "Procesando baja del usuario '$u'..."
        if command -v pkill >/dev/null 2>&1; then
            log_sec "Terminando procesos activos de '$u'..."
            run_cmd pkill -u "$u" || true
        fi
        if id "$u" >/dev/null 2>&1 || [[ "$DRY_RUN" == "1" ]]; then
            log_delete "Eliminando cuenta y archivando/borrando home de '$u'..."
            run_cmd userdel -r "$u" || true
        fi
    }

    if [[ "$target_to_remove" == "all" ]]; then
        for entry in "${TARGET_USERS[@]}"; do
            IFS='|' read -r u _ _ _ _ <<< "$entry"
            remove_single_user "$u"
        done

        log_delete "Eliminando grupos de trabajo creados..."
        for grp in "${TARGET_GROUPS[@]}"; do
            if [[ "$grp" != "sudo" ]]; then
                run_cmd groupdel "$grp" || true
            fi
        done

        log_delete "Limpiando reglas de sudoers (/etc/sudoers.d/access_levels)..."
        run_cmd rm -f /etc/sudoers.d/access_levels

        log_delete "Limpiando bloque horario en /etc/security/time.conf..."
        if [[ -f /etc/security/time.conf ]]; then
            run_cmd sed -i '/# BEGIN UNIDAD_3_1_SCHEDULES/,/# END UNIDAD_3_1_SCHEDULES/d' /etc/security/time.conf || true
        fi
    else
        remove_single_user "$target_to_remove"
    fi
    log_success "Operacion de baja completada en su totalidad."
    exit 0
fi

# Mode: Provisioning
log_info "Iniciando proceso de aprovisionamiento de cuentas y politicas..."

# 1. Groups
log_step "Fase 1/5: Verificacion y creacion de grupos del sistema..."
for grp in "${TARGET_GROUPS[@]}"; do
    if command -v getent >/dev/null 2>&1 && getent group "$grp" >/dev/null 2>&1; then
        log_info "Grupo existente: '$grp'"
    else
        log_create "Creando grupo: '$grp'..."
        run_cmd groupadd -f "$grp"
    fi
done

# 2. Users & Strict Home Isolation (700)
log_step "Fase 2/5: Aprovisionamiento de cuentas con aislamiento estricto (chmod 700)..."
for entry in "${TARGET_USERS[@]}"; do
    IFS='|' read -r user pgroup sgroups exp comment <<< "$entry"
    home_dir="/home/$user"

    if [[ "$DRY_RUN" != "1" ]] && id "$user" >/dev/null 2>&1; then
        log_update "Modificando usuario '$user'..."
        run_cmd usermod -c "$comment" -g "$pgroup" -G "$sgroups" -d "$home_dir" -s /bin/bash -e "$exp" "$user"
    else
        log_create "Creando usuario '$user' [$comment]..."
        run_cmd useradd -m -d "$home_dir" -s /bin/bash -c "$comment" -g "$pgroup" -G "$sgroups" -e "$exp" "$user"
    fi

    # Strict isolation: 700
    log_sec "Aplicando aislamiento total (chmod 700) a '$home_dir'..."
    run_cmd chmod 700 "$home_dir"
    run_cmd chown "$user:$pgroup" "$home_dir"

    log_sec "Asignando contrasena temporal y forzando reseteo en primer inicio..."
    if [[ "$DRY_RUN" == "1" ]]; then
        printf "         \033[2m[SIMULACION] echo '%s:<TEMP_PASS>' | chpasswd && chage -d 0 %s\033[0m\n" "$user" "$user"
    else
        echo "${user}:${TEMP_PASS}" | chpasswd
        chage -d 0 "$user"
    fi
done

# 3. Sudoers: Explicit order of precedence
log_step "Fase 3/5: Configurando privilegios sudoers (orden de precedencia estricto)..."
SUDOERS_FILE="/etc/sudoers.d/access_levels"
SUDOERS_CONTENT="# Access control by organizational tier
# Precedence: Last matching rule wins.
%operaciones ALL=(ALL:ALL) !ALL
%gerencia ALL=(root) /bin/journalctl, /usr/bin/journalctl, /bin/systemctl restart cups, /usr/bin/systemctl restart cups
%direccion ALL=(root) /bin/journalctl, /usr/bin/journalctl, /bin/systemctl restart cups, /usr/bin/systemctl restart cups
legal_compliance ALL=(root) /bin/journalctl, /usr/bin/journalctl
ceo ALL=(ALL:ALL) ALL
ti_secops ALL=(ALL:ALL) ALL
"

log_create "Escribiendo y validando sudoers en '$SUDOERS_FILE'..."
if [[ "$DRY_RUN" == "1" ]]; then
    printf "         \033[2m[SIMULACION] Generar %s (reglas especificas al final) y visudo -cf\033[0m\n" "$SUDOERS_FILE"
else
    mkdir -p /etc/sudoers.d
    printf "%s" "$SUDOERS_CONTENT" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    visudo -cf "$SUDOERS_FILE"
fi

# 4. Schedules: PAM injection limited to login, sshd, and su (common-account omitted)
log_step "Fase 4/5: Configurando PAM pam_time.so en login, sshd y su..."
TIME_CONF_FILE="/etc/security/time.conf"
TIME_CONF_BLOCK="# BEGIN UNIDAD_3_1_SCHEDULES
*;*;ceo|coo|ti_secops;Al0000-2400
*;*;pm_gerente|tech_lead|rh_talento|legal_compliance;MoTuWeThFrSa0700-2100
*;*;esp_operativo|esp_soporte;Wk0800-1700
# END UNIDAD_3_1_SCHEDULES"

if [[ "$DRY_RUN" == "1" ]]; then
    printf "         \033[2m[SIMULACION] Inyectar horarios en %s y habilitar en /etc/pam.d/{login,sshd,su}\033[0m\n" "$TIME_CONF_FILE"
else
    mkdir -p /etc/security
    touch "$TIME_CONF_FILE"
    sed -i '/# BEGIN UNIDAD_3_1_SCHEDULES/,/# END UNIDAD_3_1_SCHEDULES/d' "$TIME_CONF_FILE"
    printf "\n%s\n" "$TIME_CONF_BLOCK" >> "$TIME_CONF_FILE"

    for pam_file in /etc/pam.d/sshd /etc/pam.d/login /etc/pam.d/su; do
        if [[ -f "$pam_file" ]]; then
            if ! grep -Eq '^\s*account\s+required\s+pam_time\.so' "$pam_file"; then
                log_sec "Habilitando 'pam_time.so' en '$pam_file'..."
                echo "account required pam_time.so" >> "$pam_file"
            fi
        fi
    done
fi

# 5. Lockout consuming .env variables
log_step "Fase 5/5: Configurando bloqueo faillock (intentos=$LOCKOUT_MAX_ATTEMPTS, tiempo=${LOCKOUT_SECONDS}s)..."
FAILLOCK_FILE="/etc/security/faillock.conf"
FAILLOCK_CONTENT="# Lockout policy dynamically loaded from .env
deny = $LOCKOUT_MAX_ATTEMPTS
fail_interval = $LOCKOUT_SECONDS
unlock_time = $LOCKOUT_SECONDS
"

if [[ "$DRY_RUN" == "1" ]]; then
    printf "         \033[2m[SIMULACION] Escribir %s con deny=%s y unlock_time=%s\033[0m\n" "$FAILLOCK_FILE" "$LOCKOUT_MAX_ATTEMPTS" "$LOCKOUT_SECONDS"
else
    mkdir -p /etc/security
    printf "%s" "$FAILLOCK_CONTENT" > "$FAILLOCK_FILE"
    if command -v authselect >/dev/null 2>&1; then
        authselect enable-feature with-faillock >/dev/null 2>&1 || true
    elif command -v pam-auth-update >/dev/null 2>&1; then
        pam-auth-update --enable faillock >/dev/null 2>&1 || true
    fi
fi

log_success "Aprovisionamiento y endurecimiento completado con exito."
