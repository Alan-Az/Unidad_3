# Manual de código y carpetas — Unidad 3

## Para qué sirve

Este documento explica los archivos de Tarea 3.2 y Tarea 3.3 para una persona que empieza. Indica qué función tiene cada carpeta y qué hace cada bloque de líneas en los scripts, pruebas y configuraciones. La numeración se refiere a las versiones actuales de los archivos en sus carpetas; cada intervalo cubre todas las líneas de código no vacías dentro de él. Las líneas vacías separan secciones. Los comentarios explican intención, pero no ejecutan acciones.

La Tarea 3.1 queda fuera de este manual y no se modifica.

## Antes de seguir

Los archivos están preparados para trabajar en una máquina virtual Ubuntu de práctica. No se instaló Ubuntu ni se activaron servicios, cuotas, tareas programadas o arreglos RAID en la computadora anfitriona. En particular:

- Los scripts POSIX y los scripts de RAID/CUPS son para Linux. Los archivos con extensión .ps1 y la guía de Programador de tareas son una alternativa para Windows, no se ejecutan en Ubuntu.
- Las cuotas y ACL de configuración son ejemplos que requieren que el alumno los aplique dentro de su VM. El crontab y el Programador de tareas son plantillas, no tareas ya registradas.
- Los respaldos esperan que el volumen o carpeta secundaria ya exista y esté montado. Los scripts no montan ese destino ni instalan un servicio de almacenamiento.
- RAID y colas de impresión comienzan en simulación. Las direcciones 192.0.2.x son ejemplos reservados para documentación, no impresoras o servidores reales.
- Los logs de degradación y reconstrucción son ejemplos simulados. Un PASS de pruebas aisladas confirma la lógica del script con datos temporales y comandos falsos; no demuestra que un disco, una impresora o un servidor real se haya probado.
- No uses discos con datos. Un RAID real puede escribir metadatos en los discos seleccionados. Para una demostración real se requieren dos discos virtuales desechables creados para esa práctica y verificados dentro de la VM.

## Por qué existe cada carpeta

| Carpeta | Motivo | Qué contiene |
|---|---|---|
| Unidad_3/Tarea_3.2/ | Reúne la actividad de permisos, cuotas y respaldos. | Scripts principales y README. |
| Tarea_3.2/configs/ | Separa las plantillas de configuración y los verificadores de cuotas del script de respaldo. | POSIX/ACL, cuotas FSRM para Windows, consultas de cuota Linux y Windows. |
| Tarea_3.2/cron/ | Guarda el ejemplo de calendario Linux en un formato que se puede revisar antes de instalarlo. | Respaldo completo semanal e incremental diario. |
| Tarea_3.2/docs/ | Conserva instrucciones, reporte técnico y evidencia de restauración en un solo lugar. | Manual, reporte, evidencia y PDF. |
| Tarea_3.2/tests/ | Aísla pruebas automáticas que usan directorios temporales y no datos personales. | Pruebas Bash y PowerShell. |
| Tarea_3.2/windows/ | Mantiene separado el procedimiento equivalente de Windows. | Guía del Programador de tareas. |
| Unidad_3/Tarea_3.3/ | Reúne los ejemplos de almacenamiento redundante y colas de impresión. | Scripts, configuraciones, logs, pruebas, README y reportes. |
| Tarea_3.3/config/ | Guarda archivos de configuración que los servicios leen, separados de los scripts que los administran. | Samba, NFS y CUPS. |
| Tarea_3.3/docs/ | Guarda explicación y reporte de la actividad. | Manual y reporte técnico en Markdown/PDF. |
| Tarea_3.3/logs/ | Conserva evidencia de ejemplo sin fingir que se desconectó un disco real. | Logs simulados de degradación y reconstrucción. |
| Tarea_3.3/scripts/ | Agrupa las herramientas que muestran o administran RAID y las colas CUPS. | Scripts Bash con simulación inicial. |
| Tarea_3.3/tests/ | Comprueba que el modo seguro no llama herramientas reales y que se rechazan entradas peligrosas. | Pruebas con herramientas reemplazadas por stubs. |

## Conceptos básicos

- **Línea de comando:** instrucción escrita en una terminal.
- **Parámetro u opción:** dato que se entrega a un programa, normalmente después de un nombre como --source.
- **Variable:** nombre que conserva temporalmente un valor para usarlo después.
- **Función:** grupo de instrucciones con nombre, útil para repetir una tarea.
- **Código de salida:** número que indica si un programa terminó bien; 0 suele significar éxito y otro número suele señalar un error.
- **Hash SHA-256:** huella calculada a partir de un archivo; comparar dos huellas ayuda a detectar cambios o corrupción.
- **Simulación:** muestra qué haría una operación sin ejecutar el cambio real.
- **ACL:** reglas adicionales que dan permisos a usuarios o grupos concretos.
- **SGID y sticky bit:** banderas de permisos de directorio; SGID conserva el grupo en archivos nuevos y sticky limita quién puede borrar archivos dentro de un directorio compartido.

# Tarea 3.2 — Respaldos y cuotas

## Script Bash: backup.sh

Este es el respaldo Linux. Las opciones controlan de dónde leer, dónde guardar, si la copia es completa o incremental, y si se recupera un archivo. La rama de restauración verifica la huella y revisa las rutas del archivo antes de extraerlo.

| Líneas | Explicación para principiantes |
|---|---|
| 1 | La línea inicial selecciona Bash para interpretar el archivo. |
| 2–5 | Comentario de propósito; set -Eeuo pipefail hace que errores, variables vacías y fallos dentro de tuberías detengan el script; IFS limita cómo se separan palabras; umask 077 crea archivos privados para el usuario. |
| 7–14 | usage() imprime cómo pedir ayuda, crear respaldos completos/incrementales y restaurar primero la copia completa y luego incrementales. También avisa que el destino secundario debe estar montado previamente. |
| 15 | fail() muestra un error por la salida de errores y termina con código 2. |
| 16–19 | log() antepone hora UTC al mensaje y lo escribe en pantalla y en el registro usando tee. |
| 20 | need_value() comprueba que una opción que necesita dato tenga un valor después de ella. |
| 22–29 | Declara valores iniciales: origen, destino, archivo de estado, modo, destino secundario, archivo a restaurar, carpeta de recuperación y confirmación. |
| 31–44 | while/case recorre las opciones. Reconoce --source, --destination, --state, --mode, --secondary, --restore, --target, --force y --help; shift consume cada opción y su valor. Una opción desconocida se rechaza. |
| 46–54 | La restauración requiere --force, archivo y destino; localiza el archivo .sha256, calcula sha256sum y no continúa si la huella no coincide. |
| 56–61 | tar -tzf lista lo que contiene el archivo antes de extraerlo; el bucle rechaza rutas absolutas y segmentos .. que podrían escapar de la carpeta objetivo. |
| 63–70 | Crea/resuelve el destino, registra el inicio, extrae sin cambiar propietario ni permisos originales, registra que terminó y sale de la rama de restauración. |
| 71 | Cierra la rama condicional de restauración. |
| 73–81 | Verifica que exista el origen, limita el modo a full o incremental, normaliza rutas con realpath y rechaza guardar dentro del propio origen. |
| 82–89 | Comprueba el destino secundario; debe existir y estar montado, y no puede ser el origen, el destino principal ni una subcarpeta del destino principal. |
| 90–92 | Resuelve la ruta de estado y evita que ese archivo quede dentro del origen que se respalda. |
| 93–98 | Crea destinos; define backup.log y .backup.lock; mkdir crea un candado exclusivo para impedir dos respaldos simultáneos. |
| 99–106 | Prepara nombres temporales. cleanup() borra salidas incompletas y libera el candado; trap ejecuta esa limpieza al salir, incluso si hubo error. |
| 108–112 | Si se pidió incremental pero falta el estado anterior, usa una copia completa inicial y lo deja registrado. |
| 114–118 | Construye fecha, nombre .tar.gz y nombres temporales para no publicar un archivo a medio escribir. |
| 119–123 | Copia el estado previo para incremental o empieza uno vacío para full. |
| 125–126 | tar con gzip y --listed-incremental produce el archivo comprimido y guarda qué cambió desde la ejecución previa. |
| 127–134 | Calcula SHA-256, mueve el archivo temporal al nombre final, crea su sidecar .sha256, actualiza el estado y escribe el registro. |
| 136–151 | Si hay destino secundario, copia archivo y sidecar, calcula y compara huellas, registra éxito o falla con código 1 si el segundo ejemplar no coincide. |

## Script PowerShell: backup.ps1

Es una alternativa para Windows PowerShell 5.1. Utiliza un ZIP y un manifiesto JSON que guarda el inventario de archivos, sus huellas y los borrados. No es el script que se ejecuta en Ubuntu.

| Líneas | Explicación para principiantes |
|---|---|
| 1–9 | #Requires fija la versión mínima; el bloque .SYNOPSIS/.DESCRIPTION explica respaldo, restauración, límites del destino secundario y orden de restauración. |
| 10–20 | CmdletBinding activa opciones estándar de PowerShell y param define SourcePath, DestinationPath, Mode, StatePath, SecondaryPath, RestoreArchive, TargetPath y Force. Mode acepta Full o Incremental. |
| 22–23 | ErrorActionPreference='Stop' convierte errores en fallos detenibles; Add-Type carga las funciones de compresión ZIP de .NET. |
| 25–30 | Write-BackupLog recibe ruta y mensaje, genera hora UTC, añade una línea UTF-8 y también la muestra en pantalla. |
| 32–43 | Get-SafeChildPath evita rutas absolutas y .., normaliza raíz/candidato y verifica que el resultado siga dentro de la raíz permitida. |
| 45–57 | Get-Inventory recorre archivos ocultos y normales, crea su ruta relativa y registra tamaño y hash SHA256. |
| 59–67 | Restore-Archive requiere AllowOverwrite (ligado a -Force), archivo y checksum; compara hash antes de extraer. |
| 69–76 | Crea la carpeta de recuperación, abre ZIP, localiza .backup-manifest.json, lee JSON y libera el lector después de usarlo. |
| 78–97 | Prepara entradas a extraer, omite el manifiesto, rechaza rutas repetidas y rutas inseguras, y evita sobrescribir archivos sin permiso. También valida las rutas eliminadas del manifiesto. |
| 99–113 | Crea las carpetas necesarias y copia cada archivo desde ZIP; finally asegura cerrar streams incluso si falla una copia. |
| 115–123 | Para un incremental aplica el registro de borrados, escribe restore.log y cierra el ZIP en finally. |
| 125–128 | Si se pidió RestoreArchive, exige TargetPath, llama a Restore-Archive con rutas absolutas y finaliza sin iniciar un respaldo nuevo. |
| 130–142 | Exige origen/destino, normaliza rutas y rechaza origen ausente, destino igual al origen o destino dentro del origen. |
| 143–156 | Comprueba que la copia secundaria exista y no coincida con origen, destino principal o subcarpetas de ellos. |
| 157–174 | Crea destino/estado, prohíbe poner el estado dentro del origen, define log y candado .backup.lock; si el candado existe, supone que otra ejecución está activa. |
| 176–178 | Crea una carpeta temporal con GUID (identificador único) y prepara try/finally para limpiar aunque algo falle. |
| 179–189 | Elige modo; incremental carga el estado previo, o vuelve a full en primera ejecución; prepara el inventario anterior. |
| 190–197 | Calcula inventario nuevo, compara SHA-256 para detectar añadidos/modificados y obtiene los borrados. |
| 198–212 | Crea área staging; para full copia toda la estructura; copia de forma segura cada archivo que cambió. |
| 214–223 | Crea manifiesto ordenado con versión, modo, hora, origen, cambios y borrados y lo escribe como JSON UTF-8. |
| 225–236 | Forma nombre ZIP con fecha/GUID, comprime en temporal, calcula SHA-256 y mueve ZIP/checksum al destino final. |
| 237–246 | Guarda inventario como estado nuevo, publica el estado temporal y escribe el log del respaldo. |
| 248–265 | Copia ZIP y checksum al destino secundario, compara hashes y registra éxito; si falla, vuelve a lanzar el error. |
| 266–270 | finally borra ZIP temporal, staging y candado para que una ejecución incompleta no deje basura ni bloquee la siguiente. |

## Plantillas de cuotas y permisos

### configs/fsrm-cuotas.ps1 — 34 líneas

| Líneas | Explicación |
|---|---|
| 1–7 | Requiere administrador, declara SupportsShouldProcess y define rutas de ejemplo UserHome/GroupFolder más el switch Apply. |
| 9 | Detiene el script ante errores. |
| 10–13 | Prepara cuotas de 10 GB para home y 45 GB para carpeta departamental. |
| 15–19 | Sin -Apply imprime vista previa y termina sin crear cuotas. |
| 20–22 | Comprueba que New-FsrmQuota exista; de lo contrario solicita instalar/activar FSRM en Windows. |
| 23–29 | Comprueba primero que cada carpeta exista y que todavía no tenga cuota aplicada. |
| 30–34 | ShouldProcess y New-FsrmQuota crean cuota dura solo con autorización; Out-Null evita mensajes de salida innecesarios. |

### configs/verificar-cuotas.ps1 — 26 líneas

| Líneas | Explicación |
|---|---|
| 1–6 | Requiere PowerShell 5.1; declara los parámetros obligatorios Volume y QuotaPaths. |
| 8 | Hace que los errores detengan el reporte. |
| 9–10 | Get-Volume consulta la unidad indicada; termina si la unidad no existe. |
| 11 | Muestra letra de unidad y sistema de archivos. |
| 12–17 | Recorre carpetas, consulta Get-FsrmQuota, muestra SIN CUOTA si falta y sigue con la siguiente. |
| 18–24 | Emite ruta, uso, límite, porcentaje ocupado y límite blando. |
| 26 | fsutil quota query consulta estado de cuotas NTFS. |

### configs/verificar-cuotas.sh — 21 líneas

| Líneas | Explicación |
|---|---|
| 1–3 | Selecciona Bash, indica que es de solo lectura y activa parada estricta ante errores. |
| 4–7 | Exige argumento de punto de montaje y termina con error 2 si no se dio. |
| 8–9 | Comprueba que estén instaladas findmnt y repquota. |
| 10–12 | findmnt consulta punto, tipo y opciones del volumen. |
| 13 | Exige ext4 para estos pasos de ejemplo. |
| 14–17 | Verifica que el montaje tenga usrquota y grpquota; de lo contrario avisa y termina. |
| 18 | Resume punto de montaje y tipo. |
| 19–20 | quotaon -p consulta si están activas las cuotas de usuario y grupo. |
| 21 | repquota -ug resume uso por usuario y grupo. |

### configs/posix-acl-cuotas.md — 46 líneas

Este archivo es una receta, no un programa que se ejecuta completo de una vez. Léelo y selecciona el volumen de práctica correcto antes de copiar comandos.

| Líneas | Explicación |
|---|---|
| 1, 5, 18, 35, 44 | Encabezado y separadores de secciones: permisos, cuotas Linux, verificación y alternativa Windows. |
| 3, 16, 33, 42, 46 | Advertencias y conceptos: VM/disco de datos desechables, herencia, GiB/inodos, comandos que cambian el volumen y FSRM/NTFS. |
| 7, 9–14 | Explica modo 3770; groupadd crea grupo; install -d crea carpeta con dueño/grupo/permisos; setfacl modifica ACL y ACL por defecto; getfacl/stat verifican. |
| 20–23 | Pasos para escoger volumen de laboratorio, guardar copia de /etc/fstab y activar índices/opciones de cuotas. |
| 25 | mount -o remount vuelve a montar aplicando opciones guardadas. |
| 26 | quotacheck -cugm crea/verifica archivos de control de cuotas. |
| 27 | quotaon -vug enciende cuotas de usuario y grupo. |
| 28–29 | setquota -u/-g configura límites blandos/duros en bytes para usuario o grupo. |
| 30–31 | quota y repquota consultan uso y límites. |
| 37–40 | findmnt y reportes de cuota comprueban sistema, opciones, cuotas activas y consumo. |

## Programación automática

### cron/backup-tarea32.cron — 6 líneas

| Líneas | Explicación |
|---|---|
| 1–3 | Comentarios: instalar solo después de cambiar rutas, montar destino secundario y elegir una copia completa semanal. |
| 4 | 0 2 * * 0 ejecuta el domingo a las 02:00 como root con modo full, origen, destino, estado y copia secundaria. |
| 5 | Comentario que introduce incrementales diarias de lunes a sábado. |
| 6 | 0 2 * * 1-6 programa incremental a las 02:00 de lunes a sábado con las mismas rutas. |

### windows/tarea-programada.md — 21 líneas

| Líneas | Explicación |
|---|---|
| 1, 12 | Título y sección que explica dónde crear la tarea en la interfaz de Windows. |
| 3, 21 | Usa cuenta de servicio con permisos mínimos; las rutas son ejemplos y el destino secundario debe existir. |
| 5–7 | Ejemplo de tarea semanal completa; powershell.exe, -NoProfile y -File indican a Windows que ejecute el archivo sin perfil personal y con los parámetros indicados. |
| 8–10 | Variante incremental para lunes a sábado. |
| 13–19 | Abre Programador de tareas, da nombre, frecuencia, ejecutable/argumentos, usuario menos privilegiado y condición de inicio; prueba manual y revisa ZIP, hash y log. |

## Pruebas de respaldo

Las pruebas crean contenido descartable bajo una carpeta temporal y la eliminan al terminar. Nunca deberían apuntarse a carpetas personales.

### tests/test-backup.sh — 90 líneas

| Líneas | Explicación |
|---|---|
| 1–6 | Ejecuta Bash estricto, define ubicaciones temporales para origen/destino/restauración/secundario y programa trap para borrarlas al salir. |
| 8–13 | fail() reporta prueba fallida y detiene; pass() reporta aprobación. |
| 15–34 | assert_rejected_secondary intenta un destino inválido y exige error sin crear estado, log, candado, estado temporal ni respaldo. |
| 35–43 | Prueba que el secundario no coincida con origen/destino ni sea carpeta dentro de ellos. |
| 44–49 | Rechaza destino anidado dentro del origen antes de crearlo. |
| 50–61 | Crea archivos de ejemplo; ejecuta full con secundario y verifica ZIP, sidecar y hashes iguales. |
| 62–76 | Confirma una copia completa; corrompe un ZIP de prueba y exige que restauración falle sin tocar destino; comprueba que el respaldo original siga igual. |
| 78–84 | Cambia, borra y agrega archivos; crea incremental y verifica el ZIP. |
| 85–90 | Restaura full y luego incremental; confirma cambio, alta y baja de archivo y muestra PASS. |

### tests/test-backup.ps1 — 88 líneas

| Líneas | Explicación |
|---|---|
| 1–8 | Detiene errores, encuentra backup.ps1 y prepara carpetas aleatorias bajo temporales. |
| 9–17 | Abre try, crea datos de prueba y define casos de destino secundario inválido. |
| 18–34 | Assert-RejectedSecondary exige error y ausencia de estado/log/lock/archivo/destino recién creado. |
| 35–45 | Prueba secundario igual o dentro del origen/destino. |
| 46–49 | Rechaza destino de respaldo metido dentro del origen antes de escribir. |
| 50–60 | Ejecuta completa con copia secundaria y compara ZIP, sidecar y hashes. |
| 61–70 | Cambia un byte del ZIP y comprueba que la restauración lo rechace y no cree destino. |
| 72–77 | Modifica, elimina y crea archivos; exige archivo incremental. |
| 79–84 | Restaura full + incremental y comprueba actualización, alta y baja de archivo. |
| 85–88 | finally elimina el directorio de prueba aunque se haya producido un error. |

# Tarea 3.3 — RAID, red e impresión

## Scripts de RAID

### scripts/raid1_setup.sh — 75 líneas

Este script prepara RAID 1 (un espejo de dos discos). Sin las dos opciones explícitas de aplicación y confirmación solo muestra el plan.

| Líneas | Explicación |
|---|---|
| 1–2 | Selecciona Bash y detiene errores de comandos en tuberías. |
| 4–8 | Define dos discos, arreglo, modo real desactivado y confirmación vacía. |
| 10–12 | usage() muestra cómo usar el script. |
| 14–17 | fail() escribe error en stderr y termina. |
| 19–29 | Lee --device1, --device2, --array, --apply, --confirm y --help; exige valores cuando toca y rechaza opción desconocida. |
| 31–41 | Exige dos miembros distintos bajo /dev y un arreglo que empiece con /dev/md. |
| 43–48 | Modo seguro: imprime el comando mdadm --create y avisa que no tocó discos. |
| 50–54 | Modo real exige el texto ERASE_DATA_ON_SELECTED_DEVICES, permisos root y herramientas mdadm, lsblk y wipefs. |
| 56–68 | Comprueba que cada miembro sea un dispositivo de bloque entero; rechaza firmas, particiones/hijos y montajes. |
| 70–75 | Rechaza arreglo existente; informa el plan y crea RAID 1. No formatea ni monta el volumen. |

### scripts/raid1_mount.sh — 51 líneas

| Líneas | Explicación |
|---|---|
| 1–2 | Bash y parada ante errores. |
| 4–7 | Define arreglo, carpeta de montaje, modo seguro y confirmación. |
| 9–12 | fail() imprime motivo y termina. |
| 14–23 | Lee --device, --mountpoint, --apply, --confirm y --help; rechaza parámetros inesperados. |
| 25–27 | Limita dispositivo a /dev/md/*, exige ruta absoluta y prohíbe montar sobre /. |
| 29–34 | Simulación imprime mount y comprueba que arreglo y sistema de archivos existan. |
| 36–41 | Modo real requiere token MOUNT_EXISTING_ARRAY, root, dispositivo de bloque y utilidades blkid, mount y findmnt. |
| 42–48 | Rechaza enlaces simbólicos, punto ya montado, ruta existente y cualquier formato distinto de ext4/XFS. |
| 49–51 | Crea carpeta, monta y aclara que no modificó /etc/fstab; por eso el montaje no queda persistente tras reinicio. |

### scripts/raid1_status.sh — 11 líneas

| Líneas | Explicación |
|---|---|
| 1–2 | Bash y parada ante errores. |
| 4 | Usa /dev/md0 como arreglo predeterminado. |
| 5–8 | Acepta --array RUTA; otros argumentos muestran ayuda. |
| 9 | Solo permite rutas /dev/md. |
| 10 | Comprueba mdadm y recuerda que se consulta en el servidor Linux. |
| 11 | exec mdadm --detail muestra el estado detallado del arreglo. |

## Scripts de CUPS

### scripts/print_queues.sh — 41 líneas

| Líneas | Explicación |
|---|---|
| 1–2 | Bash y parada ante errores. |
| 4–6 | Usa IP documental 192.0.2.44; deja aplicación desactivada y confirmación vacía. |
| 8–11 | fail() informa y termina. |
| 13–21 | Lee --printer-ip, --apply, --confirm y ayuda; rechaza opciones no reconocidas. |
| 23–25 | Forma y comprueba cuatro números de una dirección IPv4. |
| 27–32 | Simulación enseña dos comandos lpadmin con URI IPP y aclara que la IP de documentación no es una impresora. |
| 35–38 | Modo real requiere token CHANGE_CUPS_QUEUES, root, reemplazar IP documental e instalar lpadmin. |
| 39–41 | Crea las colas aula_normal/aula_prioridad con protocolo IPP y driverless everywhere; luego pide verificar con lpstat -t. |

### scripts/print_job.sh — 43 líneas

| Líneas | Explicación |
|---|---|
| 1–2 | Bash y parada ante errores. |
| 4–8 | Valores por defecto: cola aula_normal, prioridad 40, archivo vacío y simulación habilitada. |
| 10–13 | fail() informa y termina. |
| 15–25 | Lee --queue, --priority, --file, --apply, --confirm y ayuda; rechaza opciones desconocidas. |
| 27 | Permite solo las colas declaradas por el proyecto. |
| 28–29 | Prioridad debe ser entero entre 1 y 100. |
| 30 | Exige nombre de archivo a imprimir. |
| 32–36 | Modo seguro muestra lp -d ... -q ... pero no imprime. |
| 38–41 | Impresión real requiere token SEND_FILE_TO_PRINTER, archivo regular, no enlace simbólico y programa lp disponible. |
| 42–43 | lp envía el documento a la cola con prioridad elegida; lpstat -o ayuda a ver trabajos pendientes. |

## Archivos de configuración de red e impresión

### config/smb.conf — 21 líneas

| Líneas | Explicación |
|---|---|
| 1–2 | Comentarios de plantilla; reemplaza grupo y usuarios reales antes de instalar. |
| 3 | Inicia sección global de Samba. |
| 4–10 | Define grupo de trabajo, servidor independiente, autenticación con usuarios, bloquea invitados, exige SMB2_10 y configura archivo/tamaño de registro. |
| 12 | Inicia recurso compartido unidad3. |
| 13–20 | Da ruta compartida, la hace visible y escribible, bloquea invitados, limita a un grupo, fuerza ese grupo, fija máscaras seguras 0660/2770 y hereda grupo/permisos. |

### config/exports — 3 líneas

| Líneas | Explicación |
|---|---|
| 1–2 | Comentarios: 192.0.2.0/24 es red reservada para documentación; sustituir por la subred privada autorizada de la VM. |
| 3 | Exporta /srv/raid1/compartido con lectura/escritura, escritura sincronizada, sin comprobación de subárbol y root_squash para que root remoto no actúe como root local. |

### config/cupsd.conf — 21 líneas

| Líneas | Explicación |
|---|---|
| 1 | Advierte que es plantilla restrictiva con acceso remoto apagado. |
| 2–5 | Escucha solo en localhost:631; apaga exploración/compartición por defecto y conserva interfaz web local. |
| 6–9 | <Location /> limita acceso al propio equipo. |
| 10–13 | /admin queda solo para localhost. |
| 14–19 | /admin/conf exige autenticación y grupo del sistema, pero sigue limitado al equipo local. |
| 20–21 | Comentarios: abrir solo a una LAN autorizada; no usar Allow All ni exponer el puerto 631 a Internet. |

## Prueba aislada Tarea 3.3

### tests/test_tarea33.sh — 82 líneas

| Líneas | Explicación |
|---|---|
| 1–6 | Bash con errores estrictos; encuentra raíz del proyecto, crea carpeta temporal y la borra al salir. |
| 8–14 | fail() y pass() informan resultado y cortan ante la primera falla. |
| 16–19 | bash -n comprueba sintaxis de todos los scripts. |
| 21–29 | Crea stubs temporales para mdadm, mount, lpadmin y lp; registran si fueron invocados, y PATH los prioriza sobre programas reales. |
| 31–34 | Ejecuta RAID setup sin --apply; exige que muestre simulación y que mdadm no haya sido llamado. |
| 36–39 | Comprueba que montaje se simule sin invocar mount. |
| 41–45 | Comprueba que colas IPP se muestren, pero no se llame lpadmin en simulación. |
| 47–51 | Crea archivo temporal y verifica que impresión simulada con prioridad 80 no ejecute lp. |
| 53–57 | Prueba envío autorizado contra stub lp y revisa que recibiera cola, prioridad y archivo. |
| 59–62 | Rechaza dos miembros RAID iguales. |
| 63–69 | Rechaza dispositivos ficticios para modo real antes de invocar mdadm. |
| 71–74 | Rechaza una IP fuera de rango. |
| 76–80 | Rechaza IP documental en modo real y confirma que no se invoca lpadmin. |
| 82 | Muestra que el conjunto de pruebas terminó. |

## Archivos de evidencia y lectura adicional

Los README explican propósito, parámetros y límites de cada tarea. Los manuales y reportes en docs son la explicación operativa para la actividad y sus PDF son versiones listas para revisar. En Tarea_3.2, docs/evidencia-restauracion.md describe la recuperación de ejemplo; no implica que el anfitrión se haya restaurado. En Tarea_3.3, logs/degradacion_simulada.log y logs/reconstruccion_simulada.log documentan una secuencia de práctica, no lecturas de discos reales.

## Orden recomendado para estudiar

1. Lee el README de la tarea para saber cómo ejecutar pruebas de forma segura.
2. Revisa las carpetas y sus propósitos antes de abrir código.
3. Lee primero las plantillas y explica qué parte es solo ejemplo.
4. En backup.sh/backup.ps1, estudia validaciones antes de compresión/restauración.
5. Ejecuta solo las pruebas automáticas indicadas en los README y comprueba que usan temporal.
6. Para RAID e impresión, empieza siempre por ayuda y simulación. No uses modo real en el equipo anfitrión.
7. Consulta el reporte PDF y verifica visualmente sus capturas y diagramas.

## Términos que pueden aparecer

- **Full/completo:** copia todo el conjunto elegido.
- **Incremental:** guarda cambios desde el respaldo anterior y necesita la cadena previa para recuperar el estado final.
- **Estado/manifest:** registro de archivos y huellas utilizado para saber qué cambió.
- **Sidecar:** archivo pequeño que acompaña al respaldo y contiene su hash.
- **Candado/lock:** marca que impide que dos respaldos escriban a la vez.
- **Destino secundario:** segunda ubicación para una copia; debe ser otro volumen ya montado.
- **RAID 1:** dos discos mantienen una copia espejo; no sustituye un respaldo.
- **IPP:** protocolo de impresión sobre red.
- **Stub:** programa falso de prueba que registra llamadas sin afectar discos, impresoras o montajes reales.


## Complemento de Tarea 3.3: configuración CUPS y prueba integrada

### config/cupsd.conf — 21 líneas

Es una plantilla de configuración restrictiva. Editar el archivo no instala ni reinicia CUPS. Antes de aplicarlo en una VM, valida la sintaxis y conserva una forma de volver a la configuración anterior.

| Líneas | Explicación |
|---|---|
| 1 | Comentario que identifica la plantilla y el acceso remoto apagado por defecto. |
| 2 | Listen localhost:631 limita la escucha de CUPS a la propia máquina. |
| 3–5 | Desactiva anuncios de impresoras, activa la interfaz web local y deja compartir desactivado por defecto. |
| 6 | Abre la regla Location para la ruta raíz del servidor. |
| 7–8 | Ordena la evaluación de permisos y permite solo localhost. |
| 9 | Cierra esa regla Location. |
| 10–13 | Abre, restringe y cierra la regla de administración; solo localhost puede llegar a ella. |
| 14–19 | Abre configuración administrativa, exige autenticación del grupo del sistema, limita la solicitud a localhost y cierra la regla. |
| 20–21 | Comentarios de seguridad: en una LAN se autoriza solo la subred privada correcta; no se permite todo origen ni se publica el puerto 631 en Internet. |

### tests/test_tarea33.sh — 82 líneas

Esta prueba crea un directorio temporal y comandos sustitutos para simular mdadm, mount, lpadmin y lp. Así comprueba salidas y validaciones sin crear arreglos, montar discos o imprimir. Las líneas vacías solo separan bloques.

| Líneas | Explicación |
|---|---|
| 1–6 | Selecciona Bash, activa salida ante errores, resuelve la carpeta raíz del proyecto, crea un área temporal y programa su eliminación al terminar. |
| 8–14 | fail() muestra un motivo y termina con error; pass() muestra una comprobación exitosa. |
| 16–19 | Recorre todos los scripts Bash y ejecuta bash -n para revisar sintaxis antes de las pruebas funcionales. |
| 21–29 | Crea ejecutables falsos para mdadm, mount, lpadmin y lp; cada uno escribe sus argumentos en una traza. chmod los hace ejecutables y PATH prioriza estos sustitutos. |
| 31–34 | Llama al plan RAID con dispositivos ficticios; exige salida de simulación con mdadm --create y confirma que no se llamó mdadm. |
| 36–39 | Llama al plan de montaje con un dispositivo simulado; valida el texto mount y comprueba que mount falso no se ejecutó. |
| 41–45 | Revisa que la simulación de CUPS describa las dos colas y la URI IPP reservada; exige que lpadmin no se haya ejecutado. |
| 47–51 | Crea un archivo temporal, solicita impresión simulada a la cola prioritaria y comprueba cola/prioridad sin invocar lp. |
| 53–57 | Prueba el flujo confirmado contra lp falso. Lee su traza, valida cola/prioridad/archivo y deja claro que ninguna impresora recibió el trabajo. |
| 59–64 | Rechaza que se use dos veces el mismo miembro RAID; muestra el PASS y limpia la traza para la siguiente comprobación. |
| 65–69 | Intenta el modo real con rutas falsas y token de confirmación; exige el rechazo antes de cualquier llamada mdadm. |
| 71–74 | Rechaza un octeto IPv4 fuera del rango válido y reporta el resultado. |
| 76–80 | Rechaza la IP reservada de documentación cuando se solicita aplicación real; confirma que no se llamó lpadmin. |
| 82 | Imprime el resumen final de la prueba aislada. |
