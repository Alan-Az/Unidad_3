# Reporte técnico — Tarea 3.2

## Alcance y resultado

Se prepara un diseño multiplataforma para permisos, cuotas y copias de seguridad. Las cuotas se documentan para ext4 y Windows Server FSRM. Los respaldos se implementan en Bash y PowerShell. La evidencia funcional proviene de pruebas con datos temporales; no se modificó un volumen real ni se programó una tarea en este equipo.

## Diseño de permisos

Los directorios compartidos usan el grupo propietario del área y el modo 3770. El bit SGID conserva el grupo de colaboración en elementos nuevos y el sticky bit evita que miembros borren archivos de otros. Las ACL de acceso y las ACL predeterminadas conceden permisos a grupos específicos; el resto de usuarios no recibe acceso.

## Diseño de cuotas

En Linux se habilitan cuotas de usuario y grupo en un volumen ext4 de laboratorio. El ejemplo establece 8 GiB blandos y 10 GiB duros para una cuenta, y 40 GiB blandos y 45 GiB duros para un grupo. En Windows, NTFS permite cuota por usuario; FSRM agrega una cuota por carpeta para directorios de inicio y áreas departamentales. Se incluyen verificadores de solo lectura para ext4 y FSRM; consultan montaje, actividad y límites con quota, repquota, Get-FsrmQuota y fsutil quota query. Solo se verificó su sintaxis en este entorno; las cuotas reales quedan pendientes de un servidor o VM de laboratorio.

La verificación de cuotas reales queda pendiente de una VM o servidor de laboratorio. El equipo de preparación no habilitó cuotas en sus particiones. Las cifras anteriores son configuración de ejemplo, no uso ni límites medidos de un volumen real.

## Política de respaldo

| Tipo | Frecuencia | Retención objetivo | Uso |
|---|---:|---:|---|
| Completo | Semanal, domingo 02:00 | Cuatro semanas | Punto base de cada cadena |
| Incremental | Diario, lunes-sábado 02:00 | Seis incrementales por semana | Cambios desde el respaldo anterior |

RPO objetivo: 24 horas. RTO objetivo: 4 horas para el conjunto de datos de la práctica. Son objetivos de diseño, no valores medidos en producción. La retención no se ejecuta automáticamente para evitar borrar una cadena válida. Mantenga una copia secundaria en otro medio, preferiblemente desconectado o con permisos restringidos.

## Restauración simulada

Pruebas automatizadas en carpetas temporales:
- Se generó un respaldo completo de archivos de prueba y su checksum SHA-256.
- Se modificó un archivo, se añadió otro y se borró un tercero.
- Se generó una copia incremental, se restauró el completo y luego el incremental.
- El archivo modificado tuvo el contenido nuevo, el archivo añadido se recuperó y el archivo borrado permaneció borrado.
- Una copia con checksum alterado fue rechazada antes de crear el destino de restauración.
- La copia secundaria local recibió el ZIP o tar.gz y su checksum; el hash del archivo copiado se comparó con el original antes de registrar éxito.
- Se rechazaron los cuatro destinos secundarios inválidos: igual al origen, dentro del origen, igual al destino principal y dentro del destino principal; no se crearon logs, estado, bloqueo ni archivos de respaldo.

Estas son pruebas simuladas. No se usaron datos del usuario ni un dispositivo secundario real. El detalle y los comandos están en docs/evidencia-restauracion.md.

## Programación

Se entregan un ejemplo cron semanal/diario y una guía del Programador de tareas de Windows. No se registró ninguna tarea en el host. Para su uso, sustituya las rutas, revise permisos y confirme que la copia secundaria esté montada.

## Limitaciones

Los scripts no preservan ACL ni propietarios, no cifran, no montan dispositivos y no hacen transferencia de red directa. La suma SHA-256 detecta cambios accidentales del archivo de respaldo, pero no reemplaza una firma o una protección contra un atacante que también pueda cambiar el checksum. Para información sensible, use cifrado y proteja separadamente las claves.
