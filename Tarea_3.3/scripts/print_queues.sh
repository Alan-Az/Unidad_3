#!/usr/bin/env bash
set -eo pipefail

printer_ip='192.0.2.44'
apply='no'
confirm=''

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --printer-ip) [ "$#" -ge 2 ] || fail 'Falta la IP de la impresora'; printer_ip="$2"; shift 2 ;;
        --apply) apply='yes'; shift ;;
        --confirm) [ "$#" -ge 2 ] || fail 'Falta la confirmación'; confirm="$2"; shift 2 ;;
        --help|-h) printf '%s\n' 'Uso: print_queues.sh [--printer-ip IP] [--apply --confirm CHANGE_CUPS_QUEUES]'; exit 0 ;;
        *) fail "Opción desconocida: $1" ;;
    esac
done

ip_octet='([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
ip_pattern="^($ip_octet\.){3}$ip_octet$"
[[ "$printer_ip" =~ $ip_pattern ]] || fail 'La IP debe ser IPv4 válida'

if [ "$apply" = 'no' ]; then
    printf '[SIMULACIÓN] No se ejecutó lpadmin ni se cambió CUPS.\n'
    printf 'lpadmin -p aula_normal -E -v ipp://%s/ipp/print -m everywhere -o printer-is-shared=true\n' "$printer_ip"
    printf 'lpadmin -p aula_prioridad -E -v ipp://%s/ipp/print -m everywhere -o printer-is-shared=true\n' "$printer_ip"
    printf '[SIMULACIÓN] 192.0.2.44 es una IP de documentación; no es una impresora real.\n'
    exit 0
fi

[ "$confirm" = 'CHANGE_CUPS_QUEUES' ] || fail 'La operación real exige --confirm CHANGE_CUPS_QUEUES'
[ "$EUID" -eq 0 ] || fail 'El modo real requiere root'
[ "$printer_ip" != '192.0.2.44' ] || fail 'Reemplace la IP de documentación por la impresora de laboratorio'
command -v lpadmin >/dev/null 2>&1 || fail 'Falta lpadmin; el script no instala paquetes'
lpadmin -p aula_normal -E -v "ipp://$printer_ip/ipp/print" -m everywhere -o printer-is-shared=true
lpadmin -p aula_prioridad -E -v "ipp://$printer_ip/ipp/print" -m everywhere -o printer-is-shared=true
printf '[OK] Colas creadas; confirme acceso con lpstat -t desde una estación autorizada.\n'