#!/usr/bin/env bash
set -eo pipefail

queue='aula_normal'
priority='40'
file=''
apply='no'
confirm=''

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --queue) [ "$#" -ge 2 ] || fail 'Falta la cola'; queue="$2"; shift 2 ;;
        --priority) [ "$#" -ge 2 ] || fail 'Falta la prioridad'; priority="$2"; shift 2 ;;
        --file) [ "$#" -ge 2 ] || fail 'Falta el archivo'; file="$2"; shift 2 ;;
        --apply) apply='yes'; shift ;;
        --confirm) [ "$#" -ge 2 ] || fail 'Falta la confirmación'; confirm="$2"; shift 2 ;;
        --help|-h) printf '%s\n' 'Uso: print_job.sh [--queue aula_normal|aula_prioridad] [--priority 1-100] --file archivo [--apply --confirm SEND_FILE_TO_PRINTER]'; exit 0 ;;
        *) fail "Opción desconocida: $1" ;;
    esac
done

case "$queue" in aula_normal|aula_prioridad) ;; *) fail 'Use una de las colas configuradas' ;; esac
case "$priority" in ''|*[!0-9]*) fail 'La prioridad debe ser un número entero' ;; esac
[ "$priority" -ge 1 ] && [ "$priority" -le 100 ] || fail 'La prioridad válida va de 1 a 100'
[ -n "$file" ] || fail 'Debe indicar --file'

if [ "$apply" = 'no' ]; then
    printf '[SIMULACIÓN] No se envió un trabajo a CUPS.\n'
    printf 'lp -d %s -q %s -- %s\n' "$queue" "$priority" "$file"
    exit 0
fi

[ "$confirm" = 'SEND_FILE_TO_PRINTER' ] || fail 'La impresión real exige --confirm SEND_FILE_TO_PRINTER'
[ -f "$file" ] || fail 'El archivo debe existir y ser un archivo regular'
[ ! -L "$file" ] || fail 'No se envían enlaces simbólicos'
command -v lp >/dev/null 2>&1 || fail 'No se encontró lp'
lp -d "$queue" -q "$priority" -- "$file"
printf '[OK] CUPS aceptó el trabajo. Revise su identificador con lpstat -o.\n'