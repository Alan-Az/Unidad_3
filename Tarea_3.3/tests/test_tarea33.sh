#!/usr/bin/env bash
set -eo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}
pass() {
    printf '[PASS] %s\n' "$1"
}

for script in "$root"/scripts/*.sh; do
    bash -n "$script" || fail "Error de sintaxis: $script"
done
pass 'Sintaxis Bash válida en los scripts'

mkdir -p "$tmp/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" called >> "$TRACE_FILE"' > "$tmp/bin/mdadm"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" called >> "$TRACE_FILE"' > "$tmp/bin/mount"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" called >> "$TRACE_FILE"' > "$tmp/bin/lpadmin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "$TRACE_FILE"' > "$tmp/bin/lp"
chmod +x "$tmp/bin/"*

export TRACE_FILE="$tmp/commands.log"
export PATH="$tmp/bin:$PATH"

setup_output=$(bash "$root/scripts/raid1_setup.sh" --device1 /dev/mock-a --device2 /dev/mock-b)
case "$setup_output" in *'[SIMULACIÓN]'*'mdadm --create'*) ;; *) fail 'El modo de simulación no presentó la operación esperada' ;; esac
[ ! -e "$TRACE_FILE" ] || fail 'El modo de simulación ejecutó mdadm'
pass 'La creación RAID muestra el plan sin ejecutarlo'

mount_output=$(bash "$root/scripts/raid1_mount.sh" --device /dev/md/mock --mountpoint /tmp/unidad3-demo)
case "$mount_output" in *'[SIMULACIÓN]'*'mount /dev/md/mock /tmp/unidad3-demo'*) ;; *) fail 'El montaje de simulación no presentó el plan esperado' ;; esac
[ ! -e "$TRACE_FILE" ] || fail 'El modo de simulación ejecutó mount'
pass 'El montaje muestra el plan sin ejecutarlo'

print_output=$(bash "$root/scripts/print_queues.sh")
case "$print_output" in *'[SIMULACIÓN]'*'lpadmin -p aula_normal'*'ipp://192.0.2.44/ipp/print'*) ;; *) fail 'La cola driverless no usó IPP en la IP de simulación' ;; esac
case "$print_output" in *'lpadmin -p aula_prioridad'*'printer-is-shared=true'*) ;; *) fail 'La simulación CUPS no mostró la cola prioritaria' ;; esac
[ ! -e "$TRACE_FILE" ] || fail 'El modo de simulación ejecutó lpadmin'
pass 'Las colas CUPS se muestran sin cambiar la configuración'

printf '%s\n' 'demo' > "$tmp/sample.txt"
job_output=$(bash "$root/scripts/print_job.sh" --queue aula_prioridad --priority 80 --file "$tmp/sample.txt")
case "$job_output" in *'[SIMULACIÓN]'*'lp -d aula_prioridad -q 80'*) ;; *) fail 'La impresión de simulación no mostró la prioridad' ;; esac
[ ! -e "$TRACE_FILE" ] || fail 'La impresión de simulación ejecutó lp'
pass 'La prioridad por trabajo se muestra sin enviar archivos'

bash "$root/scripts/print_job.sh" --queue aula_prioridad --priority 80 --file "$tmp/sample.txt" --apply --confirm SEND_FILE_TO_PRINTER >/dev/null
[ -f "$TRACE_FILE" ] || fail 'La prueba con lp simulado no registró la llamada'
trace=$(<"$TRACE_FILE")
case "$trace" in *'aula_prioridad'*'80'*'sample.txt'*) ;; *) fail 'La llamada simulada no recibió cola, prioridad y archivo' ;; esac
pass 'La impresión confirmada se limitó al comando lp simulado'

if bash "$root/scripts/raid1_setup.sh" --device1 /dev/mock-a --device2 /dev/mock-a >/dev/null 2>&1; then
    fail 'Se aceptaron dos veces el mismo miembro RAID'
fi
pass 'Se rechazan miembros RAID duplicados'
: > "$TRACE_FILE"

if bash "$root/scripts/raid1_setup.sh" --apply --device1 /dev/mock-a --device2 /dev/mock-b --confirm ERASE_DATA_ON_SELECTED_DEVICES >/dev/null 2>&1; then
    fail 'Se aceptó un dispositivo ficticio en modo real'
fi
[ ! -s "$TRACE_FILE" ] || fail 'El rechazo de dispositivos ficticios ejecutó mdadm'
pass 'El modo real rechaza rutas que no son dispositivos de bloque reales'

if bash "$root/scripts/print_queues.sh" --printer-ip 999.1.1.1 >/dev/null 2>&1; then
    fail 'Se aceptó una IP fuera de rango'
fi
pass 'Se rechazan octetos IPv4 fuera de rango'

if bash "$root/scripts/print_queues.sh" --apply --confirm CHANGE_CUPS_QUEUES >/dev/null 2>&1; then
    fail 'Se aceptó la IP de documentación en modo real'
fi
[ ! -s "$TRACE_FILE" ] || fail 'La validación CUPS ejecutó lpadmin'
pass 'El modo real rechaza la IP reservada de documentación'

printf '%s\n' 'Todas las pruebas aisladas terminaron correctamente.' 