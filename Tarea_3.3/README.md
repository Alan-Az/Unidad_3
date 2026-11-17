# Tarea 3.3 - RAID 1, NAS y colas de impresión

Este paquete demuestra una solución Linux para almacenamiento redundante y publicación de archivos e impresoras. El modo de prueba simula la operación; no necesita discos, no monta sistemas y no instala servicios.

## Estructura

- config/smb.conf: plantilla de un recurso Samba protegido por grupos.
- config/exports: ejemplo NFS con root squash y una red de documentación reservada.
- config/cupsd.conf: ejemplo CUPS que solo escucha en loopback hasta que el administrador lo adapte.
- scripts/raid1_setup.sh: muestra por defecto el comando RAID; el modo real pide confirmación y valida dos discos vacíos.
- scripts/raid1_mount.sh: muestra el montaje; en modo real solo monta un arreglo que ya tenga sistema de archivos.
- scripts/raid1_status.sh: consulta mdadm en modo de solo lectura.
- scripts/print_queues.sh: muestra las colas CUPS; configurar colas requiere confirmación explícita.
- scripts/print_job.sh: asigna prioridad por trabajo; enviar a una impresora requiere confirmación explícita.
- tests/test_tarea33.sh: verificaciones aisladas para modo de simulación.
- logs/: ejemplos marcados como simulados, no eventos de hardware.

## Diseño

Se usa RAID 1 con dos discos de capacidad igual. Cada escritura se replica en ambos miembros; el volumen tolera la pérdida de uno. RAID no reemplaza un respaldo. La NAS expone la carpeta solo a grupos autorizados, con NFS y Samba como plantillas alternativas. CUPS administra dos colas: normal y prioritaria. Las impresoras driverless IPP Everywhere se conectan por IPP/TCP 631; usa un modelo disponible de lpinfo -m para impresoras antiguas.

## Pruebas seguras

Desde Git Bash en Windows o Bash en Linux:

    bash -n scripts/raid1_setup.sh
    bash -n scripts/raid1_mount.sh
    bash -n scripts/raid1_status.sh
    bash -n scripts/print_queues.sh
    bash -n scripts/print_job.sh
    bash tests/test_tarea33.sh

Las pruebas usan rutas ficticias en el modo por defecto y comandos simulados. No prueban discos físicos, red, CUPS real ni impresoras.

## Operación en un servidor de laboratorio Linux

1. Instalar mdadm, Samba, NFS server y CUPS en una máquina de laboratorio dedicada.
2. Crear una copia de seguridad de los discos y elegir dos dispositivos vacíos. Confirmar con lsblk, findmnt y wipefs -n antes de continuar.
3. Crear el grupo compartido y agregar solo a los usuarios autorizados: sudo groupadd -f unidad3_compartido y sudo usermod -aG unidad3_compartido USUARIO. Configurar la contraseña Samba del usuario con sudo smbpasswd -a USUARIO. La carpeta compartida se crea después de montar el RAID.
4. Revisar config/smb.conf, config/exports y config/cupsd.conf; reemplazar grupos, rutas e IP reservada por valores reales de la red autorizada.
5. Crear el arreglo con scripts/raid1_setup.sh --apply --device1 /dev/sdb --device2 /dev/sdc --confirm ERASE_DATA_ON_SELECTED_DEVICES. El comando elimina estructuras previas; nunca usarlo con discos que contengan información.
6. Revisar el arreglo con scripts/raid1_status.sh. Solo en los discos virtuales vacíos del laboratorio, crear un sistema de archivos con sudo mkfs.ext4 /dev/md/unidad3. Elegir un punto de montaje nuevo que todavía no exista y después ejecutar scripts/raid1_mount.sh --apply --device /dev/md/unidad3 --mountpoint /srv/raid1 --confirm MOUNT_EXISTING_ARRAY. mkfs.ext4 borra lo que hubiera en el dispositivo seleccionado.
7. Después del montaje, crear la carpeta compartida con sudo install -d -o root -g unidad3_compartido -m 2770 /srv/raid1/compartido. Así queda dentro del volumen RAID y no se oculta al montarlo.
8. Aplicar Samba/NFS/CUPS siguiendo las configuraciones. El ejemplo CUPS escucha solo en localhost; habilitar clientes LAN únicamente después de definir una subred privada concreta.
9. Simular el fallo en una VM o discos virtuales desechables, verificar el estado degradado, reemplazar un miembro y observar la reconstrucción. No desconectar físicamente un disco de producción.

## Configuración de colas

La plantilla crea dos colas de ejemplo: aula_normal y aula_prioridad. print_job.sh usa prioridad 40 para trabajos normales y 80 para urgentes. El ejemplo de IP 192.0.2.44 pertenece a un bloque reservado para documentación. Sustituirlo por la dirección de una impresora de laboratorio antes de ejecutar --apply.

CUPS acepta prioridades por trabajo del 1 al 100; 100 es la más alta. print_job.sh valida el rango antes de enviar un archivo. La prioridad ordena trabajos pendientes, pero no interrumpe una página que ya se está imprimiendo. Compartir una impresora permite enviar trabajos desde la LAN, por lo que el archivo cupsd.conf mantiene el acceso remoto desactivado hasta que se configure un rango autorizado.

## Evidencia

Los registros de degradación y reconstrucción incluidos son simulados para la práctica. No indican una operación observada en discos. El resultado de test_tarea33.sh confirma el comportamiento del modo seguro y la ausencia de invocación de comandos de sistema durante la simulación.
