# Manual técnico — Tarea 3.2
## Permisos avanzados, cuotas y respaldos

Este manual explica cómo usar los archivos de Tarea 3.2 en un laboratorio. Incluye permisos POSIX y ACL, ejemplos de cuotas, respaldos completos e incrementales, restauración y programación. Las pruebas reportadas usaron carpetas temporales: no se activaron cuotas ni tareas programadas en el equipo.

## Ruta rápida

1. Desde la raíz Unidad_3, ejecuta las pruebas aisladas descritas en Verificación.
2. Revisa los ejemplos de permisos y cuotas antes de llevarlos a una VM.
3. Crea primero una copia completa; después genera incrementales y restáuralos en orden.
4. Confirma los hashes y conserva una copia en un medio secundario ya montado.

## Alcance y límites

| Elemento | Estado |
|---|---|
| Scripts Bash y PowerShell | Implementados y probados con datos temporales |
| Restauración completa seguida de incremental | Probada en carpetas aisladas |
| Cuotas POSIX y FSRM | Plantillas; no aplicadas a un volumen real |
| Cron y Programador de tareas | Ejemplos; no registrados en este equipo |
| Medio secundario | Debe estar montado antes; el script no monta ni transfiere por red |
| Cifrado y retención automática | No incluidos |
| RPO 24 horas y RTO 4 horas | Objetivos de diseño, no mediciones |

## Archivos del paquete

| Archivo | Función |
|---|---|
| backup.sh | Copias tar.gz completas o incrementales en Linux/Git Bash |
| backup.ps1 | Copias ZIP completas o incrementales en Windows |
| configs/posix-acl-cuotas.md | Ejemplos de SGID, sticky bit, ACL y cuotas ext4 |
| configs/fsrm-cuotas.ps1 | Plantilla para cuotas por carpeta con FSRM |
| configs/verificar-cuotas.sh | Consulta de cuotas POSIX, sin activarlas |
| configs/verificar-cuotas.ps1 | Consulta de cuotas NTFS/FSRM |
| cron/backup-tarea32.cron | Calendario semanal y diario de ejemplo |
| windows/tarea-programada.md | Pasos para crear tareas de Windows |
| tests/test-backup.sh y tests/test-backup.ps1 | Pruebas aisladas de respaldo y restauración |
| docs/reporte-tecnico.md | Diseño, RPO/RTO, límites y resultados |
| docs/evidencia-restauracion.md | Registro textual de las pruebas aisladas |

## Requisitos

- Bash: GNU tar con soporte incremental, sha256sum, realpath y herramientas GNU comunes. En Windows se puede usar Git Bash.
- PowerShell: Windows PowerShell o PowerShell con .NET disponible.
- Cuotas Linux: volumen ext4 preparado para cuotas y permisos de administrador.
- Cuotas Windows: Windows Server con el rol FSRM para la plantilla FSRM.
- Antes de un uso real: un origen conocido, destino distinto del origen, espacio suficiente y una segunda copia disponible.

## 1. Verifica el paquete sin tocar datos reales

Desde C:\Dev\Rriojas\Unidad_3, abre Git Bash y ejecuta:

    bash -n Tarea_3.2/backup.sh
    bash Tarea_3.2/tests/test-backup.sh

Para PowerShell:

    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File Tarea_3.2/tests/test-backup.ps1

Las pruebas crean sus propios archivos temporales y comprueban:
- creación y restauración de copia completa e incremental;
- actualización, alta y eliminación de archivos;
- rechazo de checksum alterado;
- comprobación del hash de la copia secundaria;
- rechazo de cuatro destinos secundarios que se solapan con el origen o destino.

Resultado esperado: el mensaje final indica PASS. Estas pruebas no activan cuotas ni programan tareas.

## 2. Permisos compartidos en Linux

El ejemplo de la plantilla usa una carpeta de grupo con modo 3770:

- El 2 activa SGID: los elementos nuevos heredan el grupo de la carpeta.
- El 1 activa sticky bit: los integrantes no pueden borrar archivos ajenos.
- Los permisos rwx del propietario y del grupo permiten colaboración; otros usuarios quedan sin acceso.

En una VM de laboratorio, el patrón documentado es:

    sudo install -d -o root -g sistemas -m 3770 /srv/compartido/sistemas
    sudo setfacl -m g:sistemas:rwx /srv/compartido/sistemas
    sudo setfacl -d -m g:sistemas:rwx /srv/compartido/sistemas
    getfacl /srv/compartido/sistemas

La primera ACL concede acceso ahora; la ACL predeterminada se hereda en elementos nuevos. Sustituye el grupo y la ruta por los que existan en la VM. No apliques estos ejemplos a carpetas personales o de producción sin revisar sus permisos.

## 3. Cuotas de disco

Una cuota limita el espacio que consume un usuario o grupo. En la plantilla ext4 se muestran límites blandos y duros: para un usuario, 8 GiB y 10 GiB; para el grupo, 40 GiB y 45 GiB. El límite blando permite un periodo de aviso definido por el sistema; el duro no permite exceder el máximo.

Secuencia de laboratorio documentada para un volumen ext4:

1. Respaldar la configuración del volumen.
2. Añadir usrquota,grpquota a las opciones del punto de montaje en /etc/fstab de la VM.
3. Preparar y activar cuotas.
4. Aplicar límites y verificar el resultado.

Ejemplos de comandos de configuración, solo dentro de la VM autorizada:

    sudo quotacheck -cugm /srv/datos
    sudo quotaon -vug /srv/datos
    sudo setquota -u alumno 8589934592 10737418240 0 0 /srv/datos
    sudo setquota -g sistemas 42949672960 48318382080 0 0 /srv/datos
    sudo quota -v alumno
    sudo repquota -ug /srv/datos

El primer verificador de Tarea 3.2 es de solo lectura y comprueba opciones y estado. En Windows, fsrm-cuotas.ps1 es una plantilla para carpetas; los verificadores muestran los límites actuales. No ejecutes una plantilla de configuración en este equipo.

## 4. Crear respaldos

### Linux o Git Bash

El ejemplo de copia completa:

    bash Tarea_3.2/backup.sh --source /srv/datos --destination /var/backups/unidad3 --state /var/lib/unidad3.snar --mode full --secondary /mnt/respaldo-secundario

Después de modificar archivos, crea el incremental con los mismos origen, destino y estado:

    bash Tarea_3.2/backup.sh --source /srv/datos --destination /var/backups/unidad3 --state /var/lib/unidad3.snar --mode incremental --secondary /mnt/respaldo-secundario

Opciones principales:
- --source: carpeta de datos que se respaldará.
- --destination: carpeta de respaldos.
- --state: inventario de GNU tar necesario para comparar incrementales.
- --mode full o incremental: el tipo de copia.
- --secondary: carpeta secundaria que ya debe estar montada.
- --restore y --target: restaurar un archivo de respaldo a una carpeta elegida.
- --force: autoriza sobrescribir o aplicar eliminaciones en la carpeta de restauración.

Mantén el archivo de estado incremental fuera del origen. La primera ejecución incremental sin estado anterior se convierte en una copia completa. El destino secundario debe ser distinto del origen y del destino principal; el script rechaza rutas que se solapan. El script copia el archivo de respaldo y valida su checksum, pero no monta unidades ni hace una transferencia de red.

### Windows PowerShell

Ejemplo de copia completa:

    powershell.exe -NoProfile -File Tarea_3.2/backup.ps1 -SourcePath D:\Datos -DestinationPath E:\Respaldos\Unidad3 -StatePath E:\Respaldos\Unidad3\.backup-state.json -Mode Full -SecondaryPath F:\CopiaSecundaria

Ejemplo incremental:

    powershell.exe -NoProfile -File Tarea_3.2/backup.ps1 -SourcePath D:\Datos -DestinationPath E:\Respaldos\Unidad3 -StatePath E:\Respaldos\Unidad3\.backup-state.json -Mode Incremental -SecondaryPath F:\CopiaSecundaria

Parámetros importantes:
- SourcePath y DestinationPath: origen y destino principal.
- Mode: Full o Incremental.
- StatePath: inventario del respaldo anterior.
- SecondaryPath: segunda ubicación, disponible antes de ejecutar.
- RestoreArchive y TargetPath: ZIP de entrada y carpeta de recuperación.
- Force: permite sobrescribir o aplicar eliminaciones en la recuperación.

Sustituye las letras y rutas por las de tu VM; no copies literalmente los ejemplos si corresponden a discos reales.

## 5. Restaurar correctamente

1. Elige una carpeta vacía de laboratorio distinta del origen.
2. Comprueba que los respaldos y archivos SHA-256 esperados existen.
3. Restaura primero el archivo completo.
4. Restaura después cada incremental en orden cronológico.
5. Abre algunos archivos, compara el contenido y conserva la bitácora.

Ejemplo Linux:

    bash Tarea_3.2/backup.sh --restore /var/backups/unidad3/ARCHIVO_COMPLETO.tar.gz --target /srv/restauracion --force
    bash Tarea_3.2/backup.sh --restore /var/backups/unidad3/ARCHIVO_INCREMENTAL.tar.gz --target /srv/restauracion --force

Force puede reemplazar o borrar archivos del destino elegido; por eso la restauración de prueba se hace en una ruta aislada. Nunca restaures encima de los datos originales para una demostración.

### Restauración en Windows PowerShell

Restaura primero el ZIP completo y después los incrementales, todos en la misma carpeta de recuperación:

    powershell.exe -NoProfile -File Tarea_3.2/backup.ps1 -RestoreArchive E:\Respaldos\Unidad3\COMPLETO.zip -TargetPath D:\Restauracion -Force
    powershell.exe -NoProfile -File Tarea_3.2/backup.ps1 -RestoreArchive E:\Respaldos\Unidad3\INCREMENTAL.zip -TargetPath D:\Restauracion -Force

Sustituye los nombres por los ZIP reales. Force puede reemplazar archivos o aplicar eliminaciones dentro de D:\Restauracion.
## 6. Programar copias

El archivo cron propone una copia completa el domingo a las 02:00 e incrementales de lunes a sábado a las 02:00. La guía Windows propone las mismas frecuencias con el Programador de tareas. Son ejemplos; no se registró ninguna tarea en el host.

La política propone cuatro copias completas semanales y seis incrementales por semana. No hay borrado automático de archivos antiguos: una persona administradora debe revisar que la cadena siga completa antes de aplicar retención.

- RPO objetivo: 24 horas de cambios como máximo.
- RTO objetivo: 4 horas para recuperar el conjunto de datos de la práctica.

Estos valores no fueron medidos en producción.

## 7. Funciones del código

| Archivo | Función o bloque | Objetivo |
|---|---|---|
| backup.sh | usage | Mostrar las formas de copia y restauración |
| backup.sh | fail | Informar un error y salir sin continuar |
| backup.sh | log | Guardar fecha y resultado |
| backup.sh | need_value | Rechazar opciones sin valor |
| backup.sh | cleanup | Limpiar archivos temporales al fallar |
| backup.ps1 | Write-BackupLog | Escribir una línea de bitácora |
| backup.ps1 | Get-SafeChildPath | Impedir que una ruta del ZIP salga de la carpeta elegida |
| backup.ps1 | Get-Inventory | Enumerar archivos y hashes para encontrar cambios |
| backup.ps1 | Restore-Archive | Validar y restaurar contenido y eliminaciones del ZIP |

## Límites y solución de problemas

- El checksum SHA-256 detecta cambios accidentales, pero no protege contra alguien que pueda cambiar tanto el respaldo como el checksum.
- Los scripts no cifran y no preservan ACL ni propietarios del sistema de archivos.
- Si la verificación de checksum falla, no uses ese respaldo; conserva el original y busca otra copia íntegra.
- Si el incremental no se puede crear, revisa que StatePath siga disponible y fuera del origen.
- Si no existe espacio suficiente, no borres respaldos a ciegas: primero verifica la cadena de restauración.
- Una segunda copia mejora la recuperación, pero no reemplaza una copia desconectada o protegida contra cambios.

## Glosario

- ACL: lista que concede permisos adicionales a usuarios o grupos.
- Checksum: huella calculada del archivo para detectar cambios.
- Incremental: copia de cambios desde un punto de respaldo anterior.
- RPO: pérdida máxima de cambios aceptable, expresada como tiempo.
- RTO: tiempo objetivo para terminar una recuperación.
- SGID: permiso de carpeta que conserva el grupo propietario.
- Sticky bit: permiso que restringe borrar archivos de otras personas.