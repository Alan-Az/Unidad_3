# Plantilla Linux: ACL y cuotas

Esta guía es una plantilla para una máquina virtual Debian/Ubuntu. Los comandos que requieren sudo cambian el sistema de archivos o habilitan cuotas; no se ejecutaron en el equipo de trabajo. Use primero un disco y datos desechables.

## Permisos de carpeta compartida

El modo 3770 combina SGID (2) y sticky bit (1): el grupo propietario se hereda en archivos nuevos y solo el dueño del archivo, el dueño del directorio o root puede eliminar entradas.

    sudo groupadd --force sistemas
    sudo install -d -o root -g sistemas -m 3770 /srv/compartido/sistemas
    sudo setfacl -m g:sistemas:rwx /srv/compartido/sistemas
    sudo setfacl -d -m g:sistemas:rwx /srv/compartido/sistemas
    sudo getfacl /srv/compartido/sistemas
    stat -c '%A %a %U:%G %n' /srv/compartido/sistemas

La ACL por defecto se hereda al crear archivos o carpetas dentro del directorio. Ajuste el grupo y los permisos a la matriz de acceso real. No comparta todo el árbol con otros usuarios.

## Cuotas por usuario y grupo en ext4

1. Identifique primero un volumen de laboratorio y su punto de montaje. No copie el ejemplo literalmente sobre una partición con datos.
2. En una VM vacía, agregue usrquota,grpquota a las opciones de ese punto de montaje en /etc/fstab. Guarde una copia del archivo antes del cambio.
3. Monte o vuelva a montar el volumen y cree los índices de cuota.
4. Aplique límites de usuario y grupo, después consulte el estado.

    sudo mount -o remount /srv/datos
    sudo quotacheck -cugm /srv/datos
    sudo quotaon -vug /srv/datos
    sudo setquota -u alumno 8589934592 10737418240 0 0 /srv/datos
    sudo setquota -g sistemas 42949672960 48318382080 0 0 /srv/datos
    sudo quota -v alumno
    sudo repquota -ug /srv/datos

En este ejemplo el límite blando del usuario es 8 GiB y el límite duro es 10 GiB; para el grupo, 40 GiB y 45 GiB. Un cero en los dos campos de inodos significa que no se configuró una cuota por cantidad de archivos. Pruebe con una cuenta sin privilegios, escriba un archivo de prueba hasta alcanzar el límite y confirme que el sistema lo bloquea. No use datos reales para esa prueba.

## Verificación antes de aplicar

    findmnt --target /srv/datos
    findmnt --target /srv/datos --output SOURCE,FSTYPE,OPTIONS
    sudo quotaon -p /srv/datos
    sudo repquota -ug /srv/datos

La salida debe mostrar el volumen correcto, ext4 y las cuotas activas. Repquota muestra uso actual, límites y advertencias. Estos comandos son de lectura; los comandos de remount, quotacheck, quotaon y setquota modifican el volumen y se reservan para la VM autorizada.

## Equivalente en Windows

NTFS permite cuotas por usuario en el volumen. FSRM aplica cuotas a carpetas; para representar cuotas por usuario use una carpeta de inicio por persona, y para la cuota departamental use una carpeta compartida del departamento. La plantilla fsrm-cuotas.ps1 solo imprime la vista previa si no se pasa -Apply y usa ShouldProcess para pedir confirmación de cada cambio. Ejecútela únicamente en Windows Server con FSRM y carpetas de prueba.