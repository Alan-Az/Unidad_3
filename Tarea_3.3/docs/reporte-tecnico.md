# Reporte técnico - Tarea 3.3

## Objetivo y alcance

Diseñar un servidor de almacenamiento con RAID 1, una carpeta compartida por Samba o NFS y dos colas de impresión CUPS por TCP/IP. La práctica se entrega como configuración y simulación. No se instalaron paquetes ni se alteraron discos, montajes, red o impresoras de este equipo.

## Diagrama lógico

    Disco A (vacío) ─┐
                     ├── RAID 1 /dev/md/unidad3 ── ext4 ── /srv/raid1
    Disco B (vacío) ─┘                                  ├── Samba: [unidad3]
                                                        ├── NFS: /srv/raid1/compartido
                                                        └── CUPS: aula_normal / aula_prioridad
    Cliente LAN autorizado ── SMB2/NFS ────────────────┘
    Cliente de impresión ── IPP/TCP 631 ── CUPS ── IPP/TCP 631 ── Impresora

RAID 1 conserva una copia espejada en cada miembro. Con un miembro fuera de servicio el volumen puede seguir disponible, pero pierde redundancia. Una falla simultánea de ambos discos puede perder los datos; RAID no es respaldo.

## Procedimiento de instalación propuesto

1. Usar una VM o servidor de laboratorio con dos discos virtuales vacíos e identificados por número de serie.
2. Instalar mdadm, Samba, NFS y CUPS desde el gestor de paquetes de la distribución elegida.
3. Validar cada disco con lsblk, findmnt y wipefs -n. El script rechaza particiones, firmas conocidas, miembros repetidos, rutas no /dev y discos montados.
4. Ejecutar primero el modo de simulación: scripts/raid1_setup.sh --device1 /dev/sdb --device2 /dev/sdc.
5. Si la salida coincide con los dispositivos seleccionados, el administrador puede aplicar en el laboratorio con --apply y la frase ERASE_DATA_ON_SELECTED_DEVICES. Esta acción escribe metadatos RAID y destruye datos previos de esos dispositivos.
6. Consultar scripts/raid1_status.sh. Crear un sistema de archivos solo después de verificar el arreglo y documentar esa acción aparte.
7. Montar el volumen ya formateado en un punto nuevo que no exista con scripts/raid1_mount.sh --apply --confirm MOUNT_EXISTING_ARRAY. El script no monta sobre rutas que ya contienen datos ni edita fstab.
8. Configurar Samba o NFS para la subred del laboratorio y validar con testparm o exportfs -rav.
9. Configurar CUPS con acceso local, luego agregar únicamente la red privada autorizada y validar las dos colas con lpstat -t.

## Simulación de fallo y reconstrucción

La evidencia en logs/degradacion_simulada.log y logs/reconstruccion_simulada.log es una simulación textual. Representa el resultado esperado: 1 miembro activo de 2 durante la degradación y 2 miembros activos después del resync. No se desconectó ningún disco real ni se ejecutó mdadm contra hardware.

Para repetirla de forma segura, usar una VM desechable con discos virtuales descartables. Desconectar un miembro desde el hipervisor, observar mdadm --detail, añadir un nuevo disco virtual vacío y esperar el resync. Registrar el estado antes y después. Nunca usar estos pasos en un servidor con datos sin un respaldo verificado.

## NAS y permisos

La plantilla Samba usa autenticación de usuario, prohíbe acceso invitado y limita la carpeta a unidad3_compartido. Agregue solo usuarios autorizados a ese grupo y cree la carpeta con grupo propietario compartido y modo 2770. Las máscaras 0660 y 2770 permiten que el grupo comparta archivos y conservan el grupo propietario en directorios nuevos. La plantilla NFS limita la exportación a 192.0.2.0/24, bloque de documentación; sustituirlo por una red privada concreta antes de aplicar. root_squash evita que el root remoto tenga privilegios root sobre el servidor.

## Colas de impresión

La plantilla cupsd.conf escucha en localhost y mantiene Browsing y DefaultShared desactivados. print_queues.sh usa una URI IPP y el modelo driverless everywhere; para impresoras antiguas, consultar modelos disponibles con lpinfo -m. El script crea dos colas de ejemplo: aula_normal y aula_prioridad. La prioridad se asigna a cada trabajo mediante print_job.sh, que usa 40 para trabajos normales y 80 para urgentes. CUPS admite valores entre 1 y 100, con 100 como prioridad máxima; una prioridad mayor no detiene un trabajo que ya está imprimiéndose. Las colas se comparten solamente después de habilitar la subred LAN autorizada. La dirección 192.0.2.44 es ficticia para documentación; debe cambiarse por la IP de la impresora del laboratorio.

## Pruebas observadas

El test aislado valida la sintaxis Bash, comprueba que la simulación imprime los comandos esperados sin invocarlos, rechaza miembros RAID duplicados y rechaza los dispositivos ficticios en modo de aplicación. También verifica que la IP de documentación no se use como impresora real. No se probaron mdadm, Samba, NFS o CUPS contra servicios reales en esta estación.
## Referencias técnicas
- CUPS lpadmin: https://openprinting.github.io/cups/doc/man-lpadmin.html
- CUPS prioridad de trabajos: https://openprinting.github.io/cups/doc/man-lp.html
- Samba smb.conf: https://www.samba.org/samba/docs/current/man-html/smb.conf.5
- Linux NFS exports: https://www.man7.org/linux/man-pages/man5/exports.5.html
- util-linux wipefs: https://man7.org/linux/man-pages/man8/wipefs.8.html
