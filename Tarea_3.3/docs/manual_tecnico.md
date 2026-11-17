# Manual técnico — Tarea 3.3
## RAID 1, carpeta de red y colas de impresión

Este manual describe la solución Linux de laboratorio incluida en Tarea 3.3: espejo RAID 1, carpeta compartida por Samba o NFS y colas CUPS. Los scripts empiezan en simulación. Los registros de fallo y reconstrucción son ejemplos; no se desconectó ni reconstruyó ningún disco real.

## Ruta rápida

1. Ejecuta primero la prueba aislada desde Git Bash.
2. Usa una VM con dos discos virtuales vacíos para una práctica real.
3. Revisa el plan de cada script antes de agregar las opciones de aplicación.
4. Verifica RAID, carpeta y colas por separado.

## Alcance y seguridad

| Elemento | Estado |
|---|---|
| RAID 1 | Script con validaciones; el modo normal solo muestra el plan |
| Montaje | Script con confirmación; no modifica fstab |
| Samba, NFS y CUPS | Plantillas de configuración, no se instalaron en el equipo |
| Degradación y reconstrucción | Registros textuales simulados |
| Pruebas | Modo simulado y comandos ficticios; sin hardware |
| Red NFS e IP de impresora | Rangos de documentación que deben reemplazarse en laboratorio |

RAID 1 mantiene los mismos datos en dos discos. Si falla uno, el arreglo puede continuar degradado, pero ya no tiene redundancia. Si fallan ambos, pueden perderse los datos. RAID no sustituye a los respaldos.

## Archivos del paquete

| Archivo | Función |
|---|---|
| scripts/raid1_setup.sh | Valida y prepara un arreglo RAID 1 |
| scripts/raid1_status.sh | Consulta mdadm --detail |
| scripts/raid1_mount.sh | Monta un arreglo ya formateado en una ruta nueva |
| scripts/print_queues.sh | Crea dos colas CUPS de ejemplo con IPP |
| scripts/print_job.sh | Envía un archivo con prioridad a una de las colas |
| config/smb.conf | Plantilla de carpeta Samba con autenticación y grupo |
| config/exports | Plantilla NFS con root_squash |
| config/cupsd.conf | CUPS local, sin compartir con la red por defecto |
| tests/test_tarea33.sh | Pruebas aisladas de simulación y validación |
| logs/degradacion_simulada.log | Ejemplo de arreglo con un miembro activo |
| logs/reconstruccion_simulada.log | Ejemplo después de completar resync |
| docs/reporte-tecnico.md | Topología, procedimiento de laboratorio y límites |

## Requisitos del laboratorio

- Una VM Linux desechable con acceso de administrador.
- mdadm, Samba, NFS y CUPS instalados en esa VM, según la distribución elegida.
- Dos discos virtuales vacíos, separados del disco de arranque.
- Una impresora IPP autorizada para pruebas reales; de lo contrario, limitarse a simulación.
- Respaldo verificado de cualquier información que se conserve.

No ejecutes el procedimiento real en los discos del equipo de trabajo.

## 1. Probar sin hardware

Desde la raíz Unidad_3:

    bash -n Tarea_3.3/scripts/raid1_setup.sh
    bash -n Tarea_3.3/scripts/raid1_mount.sh
    bash -n Tarea_3.3/scripts/raid1_status.sh
    bash -n Tarea_3.3/scripts/print_queues.sh
    bash -n Tarea_3.3/scripts/print_job.sh
    bash Tarea_3.3/tests/test_tarea33.sh

Las pruebas revisan el plan de simulación, entradas inválidas, discos repetidos, URI IPP y la ausencia de montaje en modo de prueba. PASS solo significa que se verificó la lógica aislada; no demuestra que un arreglo, NAS o impresora reales funcionen.

## 2. Preparar RAID 1 en una VM

### Antes de crear el arreglo

1. Confirma que la VM tiene dos discos virtuales vacíos y apunta sus identificadores.
2. Comprueba cada dispositivo con lsblk, findmnt y wipefs en modo de solo lectura.
3. Verifica que ninguno sea el disco de arranque, tenga particiones montadas o datos que conservar.
4. Ejecuta el modo de simulación y compara cuidadosamente los dos dispositivos mostrados.

Ejemplo de consulta de firma sin borrar:

    sudo wipefs -n -i -O TYPE /dev/sdb

Ejemplo de simulación, desde Tarea_3.3:

    bash scripts/raid1_setup.sh --device1 /dev/sdb --device2 /dev/sdc

### Aplicación real en discos virtuales descartables

Solo dentro de la VM autorizada, y después de comprobar los dispositivos:

    sudo bash scripts/raid1_setup.sh --device1 /dev/sdb --device2 /dev/sdc --array /dev/md/unidad3 --apply --confirm ERASE_DATA_ON_SELECTED_DEVICES

La creación escribe metadatos RAID y destruye estructuras anteriores de los dos dispositivos. No cambies la frase de confirmación ni selecciones discos del equipo de trabajo.

Consulta el arreglo:

    sudo bash scripts/raid1_status.sh
    sudo bash scripts/raid1_status.sh --array /dev/md/unidad3

El estado debe mostrar ambos miembros activos antes de continuar. Si mdadm falta, ejecuta la consulta en la VM Linux con el paquete instalado.

### Formatear y montar

Formatear borra el contenido del dispositivo. En la VM, solo después de confirmar el nombre del arreglo:

    sudo mkfs.ext4 /dev/md/unidad3

Escoge un punto de montaje nuevo que no exista. El script rechaza enlaces simbólicos, rutas relativas, ubicaciones ya montadas o una carpeta existente que pudiera quedar oculta.

    sudo bash scripts/raid1_mount.sh --device /dev/md/unidad3 --mountpoint /srv/raid1 --apply --confirm MOUNT_EXISTING_ARRAY

El montaje no se agrega a fstab, así que no es persistente después de reiniciar. Configura persistencia aparte solo en la VM y después de verificar el UUID y la configuración.

## 3. Crear la carpeta compartida

Después de montar el arreglo, crea el grupo y agrega solo las cuentas autorizadas:

    sudo groupadd -f unidad3_compartido
    sudo usermod -aG unidad3_compartido USUARIO
    sudo smbpasswd -a USUARIO
    sudo install -d -o root -g unidad3_compartido -m 2770 /srv/raid1/compartido

El modo 2770 conserva el grupo en elementos nuevos y limita el acceso a propietario y grupo. Cambia USUARIO por una cuenta real de la VM; nunca pongas una contraseña en el historial de comandos.

### Samba

La plantilla config/smb.conf:
- requiere usuario y grupo; no permite invitados;
- usa máscaras para colaboración del grupo;
- apunta a /srv/raid1/compartido;
- no abre acceso anónimo.

Copia o integra el bloque revisado en la configuración de Samba de la VM y valida con testparm. Para acceso de red, limita el servicio a la subred privada autorizada y activa el firewall únicamente en esa red.

### NFS

config/exports limita el ejemplo a 192.0.2.0/24, un rango reservado para documentación; no representa una LAN real. root_squash evita que root del cliente se convierta en root del servidor. Antes de exportar, reemplaza la red y ruta por los valores de la VM y permite solo clientes autorizados.

## 4. Configurar las colas CUPS

La plantilla config/cupsd.conf escucha en localhost y mantiene el descubrimiento y el uso compartido desactivados. Así, la impresora no queda expuesta a la red antes de elegir una subred privada.

La simulación muestra dos colas:
- aula_normal: trabajo habitual.
- aula_prioridad: ejemplo urgente.

Para impresoras driverless compatibles, print_queues.sh usa IPP Everywhere sobre TCP 631. En una impresora antigua, consulta modelos disponibles con lpinfo -m y selecciona el modelo correcto en el laboratorio.

Simulación desde Tarea_3.3:

    bash scripts/print_queues.sh

Crear colas reales requiere una IP real de la impresora, --apply y la confirmación CHANGE_CUPS_QUEUES:

    sudo bash scripts/print_queues.sh --printer-ip IP_DE_LABORATORIO --apply --confirm CHANGE_CUPS_QUEUES

Para preparar una impresión real, el archivo debe existir y la cola debe estar lista. Prioridad aceptada: de 1 a 100; el ejemplo usa 40 para normal y 80 para urgente.

    bash scripts/print_job.sh --queue aula_prioridad --priority 80 --file /ruta/al/documento.pdf

La simulación no envía el documento. La impresión real requiere --apply y SEND_FILE_TO_PRINTER:

    sudo bash scripts/print_job.sh --queue aula_prioridad --priority 80 --file /ruta/al/documento.pdf --apply --confirm SEND_FILE_TO_PRINTER

La prioridad ordena trabajos pendientes; no interrumpe una página que ya se imprime. Sustituye la IP y el archivo por datos de laboratorio autorizados.

## 5. Simular fallo y reconstrucción

La evidencia incluida en logs/degradacion_simulada.log y logs/reconstruccion_simulada.log no proviene de hardware. Para observar un resync real:

1. Usa solo una VM desechable con respaldo.
2. Registra el estado de los dos miembros con mdadm --detail.
3. Desconecta un disco virtual desde la interfaz del hipervisor.
4. Confirma que el arreglo aparece degradado con un miembro.
5. Adjunta un disco virtual vacío de reemplazo y añádelo al arreglo desde la VM.
6. Espera a que termine la reconstrucción y registra de nuevo el estado.
7. Comprueba archivos de muestra y conserva una copia de la evidencia.

Nunca simules desconectar físicamente un disco de producción.

## Funciones y confirmaciones del código

| Archivo | Bloque | Propósito |
|---|---|---|
| raid1_setup.sh | usage | Mostrar opciones y frase de confirmación |
| raid1_setup.sh | fail | Detener una ejecución con error de validación |
| scripts RAID e impresión | fail | Rechazar parámetros, rutas o dispositivos inseguros |
| raid1_status.sh | consulta final | Ejecutar mdadm --detail; no altera el arreglo |
| print_queues.sh | opciones --apply y --confirm | Evitar cambios de CUPS por accidente |
| print_job.sh | opciones --apply y --confirm | Evitar enviar documentos sin autorización |

## Verificación y solución de problemas

- Si el modo de simulación no muestra el dispositivo previsto, no agregues --apply.
- Si el script rechaza un disco, revisa que no tenga montajes, particiones o firmas que quieras conservar.
- Si CUPS no encuentra la impresora, verifica IP, ruta IPP y que el modelo sea compatible.
- Si no aparece la cola, revisa el servicio CUPS en la VM y consulta lpstat -t.
- Si el arreglo está degradado, no retires el único miembro activo; registra el estado y revisa el procedimiento de reparación de la distribución.
- Los logs de ejemplo deben conservar la palabra SIMULADO; no los presentes como evidencia de hardware real.

## Glosario

- CUPS: servicio que administra impresoras y colas en Linux.
- IPP: protocolo de impresión de red, normalmente sobre TCP 631.
- NAS: servidor que ofrece archivos por red.
- NFS: protocolo para compartir carpetas entre equipos Unix/Linux.
- RAID 1: espejo que duplica datos en dos miembros.
- Resync: reconstrucción de la copia espejo después de reemplazar un miembro.
- Samba: implementación de carpetas compartidas compatibles con SMB.