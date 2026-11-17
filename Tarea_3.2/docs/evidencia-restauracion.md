# Evidencia de restauración simulada

Fecha de ejecución: 2026-11-16 UTC.
Entorno: Windows PowerShell 5.1 y Git Bash 2.x con GNU tar 1.35. WSL no estaba configurado.
Datos: archivos creados bajo carpetas temporales por cada prueba y eliminados al terminar.

## PowerShell

Comando:
    powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File Tarea_3.2/tests/test-backup.ps1

Resultado observado:
    Respaldo Full creado y verificado: PASS
    Copia secundaria temporal y checksum recalculado: PASS
    Checksum alterado rechazado sin crear destino: PASS
    Respaldo Incremental creado y verificado: PASS
    Restauración Full seguida de Incremental: PASS
    Actualización, alta y eliminación restauradas: PASS
    Resultado final: PASS: full, incremental, checksum, and restore assertions

El permiso Bypass se limitó al proceso de prueba. No se cambió la directiva de ejecución del equipo.

## Bash

Comandos:
    "C:\Program Files\Git\bin\bash.exe" -n Tarea_3.2/backup.sh
    "C:\Program Files\Git\bin\bash.exe" Tarea_3.2/tests/test-backup.sh

Resultado observado:
    Cuatro destinos secundarios inválidos rechazados sin crear archivos: PASS
    Respaldo completo, checksum y copia secundaria temporal: PASS
    Archivo alterado rechazado antes de crear destino: PASS
    Incremental, restauración de cadena y borrado replicado: PASS
    Resultado final: PASS: full, incremental, checksum, and restore assertions

## Límites

La prueba de cuota no se ejecutó sobre particiones. La evidencia de cuotas consiste en plantillas y comandos de lectura para validarlas en un servidor de laboratorio. Ninguna tarea cron o tarea de Windows fue instalada.