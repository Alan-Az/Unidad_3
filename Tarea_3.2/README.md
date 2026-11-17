# Tarea 3.2 — cuotas, permisos y respaldos

## Objetivo

Este paquete deja una política de recuperación y dos implementaciones de respaldo: Linux con Bash y Windows con PowerShell. Los comandos de cuotas se entregan como plantillas para un servidor de laboratorio. No se aplicaron al equipo donde se preparó el paquete.

## Archivos

- backup.sh: archivos completos e incrementales en GNU tar, suma SHA-256, bitácora y copia opcional a un destino secundario ya montado.
- backup.ps1: archivos ZIP completos e incrementales, manifiesto de cambios y eliminaciones, SHA-256, bitácora y copia secundaria opcional.
- cron/backup-tarea32.cron: ejemplo de programación semanal y diaria.
- windows/tarea-programada.md: pasos para programar copias completas e incrementales con el Programador de tareas.
- configs/posix-acl-cuotas.md: ACL, sticky bit, SGID, cuotas POSIX y comandos de configuración.
- configs/verificar-cuotas.sh y verificar-cuotas.ps1: consultas de solo lectura para revisar cuotas existentes.
- configs/fsrm-cuotas.ps1: plantilla de cuotas por carpetas de inicio y compartidas en Windows Server.
- tests/: pruebas autocontenidas con carpetas temporales.
- docs/reporte-tecnico.md: fuente del reporte PDF.
- docs/evidencia-restauracion.md: registro de las pruebas simuladas.

## Política propuesta

- Copia completa cada domingo a las 02:00.
- Copia incremental diaria de lunes a sábado a las 02:00.
- RPO objetivo: 24 horas para archivos de trabajo. Si el negocio requiere menos pérdida de cambios, se debe aumentar la frecuencia.
- RTO objetivo: 4 horas para restaurar el conjunto de datos de la práctica. Es una meta de diseño, no un tiempo medido en un servidor real.
- Retención: cuatro copias completas semanales y las seis incrementales asociadas a la semana. El script no elimina respaldos antiguos; una persona administradora debe revisar la cadena antes de aplicar la retención.
- Mantener una copia secundaria en un disco externo desconectado o un recurso NAS con acceso restringido. El destino se debe montar antes de ejecutar el script; los ejemplos no montan dispositivos ni abren conexiones de red.
- Verificar SHA-256 antes de restaurar y probar una restauración al menos una vez por mes en una carpeta vacía.

## Uso en Linux

Requisitos: Bash, GNU tar con soporte incremental, realpath, sha256sum y coreutils. No se necesita ejecutar el script como root si la cuenta puede leer el origen y escribir el destino.

    chmod +x Tarea_3.2/backup.sh
    Tarea_3.2/backup.sh --source /srv/datos --destination /var/backups/unidad3 --state /var/lib/unidad3.snar --mode full --secondary /mnt/respaldo-secundario
    Tarea_3.2/backup.sh --source /srv/datos --destination /var/backups/unidad3 --state /var/lib/unidad3.snar --mode incremental --secondary /mnt/respaldo-secundario

Para restaurar, aplicar primero el respaldo completo y luego cada incremental por fecha. La confirmación --force es obligatoria porque una restauración incremental puede reemplazar o eliminar archivos del destino elegido.

    Tarea_3.2/backup.sh --restore /var/backups/unidad3/ARCHIVO_COMPLETO.tar.gz --target /srv/restauracion --force
    Tarea_3.2/backup.sh --restore /var/backups/unidad3/ARCHIVO_INCREMENTAL.tar.gz --target /srv/restauracion --force

El destino debe estar fuera de la carpeta de origen. El estado incremental también debe guardarse fuera del origen. No se borran respaldos por retención.

## Uso en Windows

Requisitos: Windows PowerShell 5.1 o posterior y .NET para crear archivos ZIP. No requiere privilegios de administrador para respaldar carpetas a las que la cuenta ya tiene acceso.

    powershell -NoProfile -File Tarea_3.2/backup.ps1 -SourcePath D:\Datos -DestinationPath E:\Respaldos\Unidad3 -Mode Full
    powershell -NoProfile -File Tarea_3.2/backup.ps1 -SourcePath D:\Datos -DestinationPath E:\Respaldos\Unidad3 -Mode Incremental

La primera ejecución incremental sin estado previo crea una copia completa. Para restaurar una cadena, seleccionar el ZIP completo, después cada ZIP incremental en orden y proporcionar -Force para confirmar que se permite reemplazar o borrar archivos del destino.

    powershell -NoProfile -File Tarea_3.2/backup.ps1 -RestoreArchive E:\Respaldos\Unidad3\ARCHIVO.zip -TargetPath D:\Restauracion -Force

## Programación

Los ejemplos cron y Windows están en sus carpetas. Son configuraciones de referencia; no fueron instaladas. Antes de habilitarlas, sustituir las rutas de ejemplo por rutas reales y comprobar que origen, destino, permisos y medio secundario sean correctos.

## Cuotas y permisos

Las cuotas y ACL se documentan en configs. Las instrucciones muestran límites de ejemplo para una máquina de laboratorio. Se deben adaptar a un volumen de pruebas y a grupos existentes. No aplicar comandos de cuota o cambios de /etc/fstab al equipo de trabajo.

## Pruebas

Ejecutar en Windows PowerShell con el permiso de ejecución solo para el proceso de prueba:

    powershell -NoProfile -ExecutionPolicy Bypass -File Tarea_3.2/tests/test-backup.ps1

Ejecutar las pruebas Bash con Git Bash o GNU/Linux:

    bash -n Tarea_3.2/backup.sh
    bash Tarea_3.2/tests/test-backup.sh

Las pruebas crean datos temporales, comprueban respaldo completo e incremental, eliminación y restauración de archivos, checksum de la copia secundaria local, y rechazan cuatro destinos secundarios inválidos sin crear log, estado, bloqueo ni respaldo. No configuran cuotas ni tareas programadas.

## Límites conocidos

Los scripts no cifran respaldos, no preservan ACL/propietarios del sistema de archivos, no montan discos, no transfieren datos directamente por red y no aplican cuotas. Para datos sensibles, el medio secundario debe cifrarse y la llave guardarse por separado. El destino secundario debe estar montado y protegido por el sistema operativo antes de ejecutar el script.

## Verificar cuotas

Lectura Linux, en el servidor que ya tenga cuotas configuradas:

    bash Tarea_3.2/configs/verificar-cuotas.sh /srv/datos

Lectura Windows Server con FSRM:

    powershell -NoProfile -File Tarea_3.2/configs/verificar-cuotas.ps1 -Volume D: -QuotaPaths D:\Datos\Usuarios\alumno,D:\Datos\Grupos\Sistemas

Los scripts de verificación son de solo lectura. Si el volumen no tiene cuotas activas, revise la plantilla y la configuración del servidor autorizado; no active cuotas desde una demostración en una estación de trabajo.