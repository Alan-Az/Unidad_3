
# Guion de video — Tarea 3.3: RAID, red e impresión

## Objetivo y formato

Este guion corresponde únicamente a la Tarea 3.3. Está ordenado como tutorial grabado en pantalla e indica qué mostrar, qué narrar y qué resultado observar. La Tarea 3.1 ya está hecha y queda intacta; la Tarea 3.2 tiene su propio guion.

Graba con OBS o equivalente. Coloca la cámara web en la esquina inferior derecha y asegúrate de que no tape terminal, editor o salidas. Aumenta el zoom y deja cada comando visible. Usa una máquina virtual Ubuntu. La demostración se mantiene en simulación: crear arreglos RAID reales puede escribir metadatos en los discos seleccionados y formatear o montar discos puede destruir datos. No uses dispositivos del anfitrión.

## Carpetas de este proyecto

| Carpeta o archivo | Por qué existe y qué enseñar |
|---|---|
| Tarea_3.3/ | Agrupa la actividad de redundancia, compartición de archivos y colas de impresión. |
| config/ | Separa archivos que leerían los servicios: Samba, NFS y CUPS. Son plantillas que requieren adaptar rutas y red antes de instalarlas. |
| docs/ | Guarda explicación y reporte técnico. Ahí se documenta la topología, simulación de fallo/reconstrucción y pruebas. |
| logs/ | Mantiene evidencia de ejemplo de estado degradado y reconstrucción. Son registros simulados; no prueban que se desconectó un disco físico. |
| scripts/ | Agrupa programas Bash para mostrar/preparar RAID y administrar colas o trabajos CUPS. |
| tests/ | Contiene una prueba aislada con herramientas falsas para confirmar que la simulación no llama mdadm, mount, lpadmin o lp reales. |
| README.md | Presenta el proyecto y explica el modo seguro y sus condiciones. |

## Antes de grabar

1. Inicia la VM Ubuntu de laboratorio. Confirma que la ventana activa es la máquina virtual, no Windows anfitrión.
2. Abre Tarea_3.3 en el editor y muestra el árbol de carpetas. Aumenta el tamaño del texto.
3. En OBS, agrega captura de pantalla y cámara; deja la cámara en la esquina inferior derecha.
4. No uses discos reales ni opciones --apply. La prueba usa dispositivos ficticios y herramientas reemplazadas. La IP 192.0.2.44 pertenece a un rango reservado para documentación, no identifica una impresora real.
5. Di: “La demostración comienza en simulación. No desconecto un disco físico ni envío trabajos a una impresora real. Para una práctica real hacen falta discos virtuales desechables y autorización del administrador de la VM”.

## Grabación paso a paso

### Escena 1 — Presentar la meta y el árbol

Muestra la carpeta raíz y abre config, docs, logs, scripts y tests. Explica la razón de cada una con la tabla. Después señala que el proyecto eligió RAID 1: dos dispositivos forman un espejo; si falla uno, el arreglo puede seguir disponible con el otro, pero la capacidad útil se aproxima a la de un solo disco.

Narra: “Esta actividad cubre almacenamiento redundante, una carpeta compartida por red y administración de colas de impresión. Los archivos están separados entre configuración, automatización, pruebas y evidencia para poder revisar cada parte”.

### Escena 2 — Recorrer raid1_setup.sh línea por línea

Abre scripts/raid1_setup.sh. Desplázate de arriba abajo, enseñando los números. Lee cada variable, parámetro y comando visible y explica su efecto. Los intervalos cubren el archivo actual; explica también comentarios y líneas auxiliares.

| Líneas | Qué explicar en pantalla |
|---|---|
| 1–2 | El shebang selecciona Bash; las opciones estrictas detienen la ejecución ante errores y fallos dentro de tuberías. |
| 4–8 | Variables por defecto para dos dispositivos, nombre del arreglo, aplicación apagada y confirmación vacía. El valor predeterminado conserva modo seguro. |
| 10–17 | usage() enseña ejemplos; fail() informa por stderr y finaliza con código de error. |
| 19–29 | El bucle lee --device1, --device2, --array, --apply y --confirm. Las opciones con valor consumen el siguiente argumento; --help muestra ayuda; una opción desconocida falla. |
| 31–41 | Valida que los dos miembros sean dispositivos distintos bajo /dev y que el arreglo empiece por /dev/md. |
| 43–48 | Sin aplicación real imprime el comando mdadm --create planeado y termina sin escribir discos. Esta es la parte que se muestra. |
| 50–54 | La rama real requiere frase de confirmación destructiva, permisos root y mdadm, lsblk y wipefs. Explica por qué no la ejecutas. |
| 56–68 | Inspecciona cada miembro: debe ser dispositivo de bloque completo, sin particiones/hijos, firmas existentes ni montajes. |
| 70–75 | Rechaza un arreglo existente y crea RAID 1 solo tras validaciones y confirmación. No crea sistema de archivos ni monta el arreglo. |

En la terminal, desde Tarea_3.3, muestra una simulación segura con rutas ficticias:

    bash scripts/raid1_setup.sh --device1 /dev/mock-a --device2 /dev/mock-b

Se espera ver una operación marcada como simulación y que mdadm no se ejecute. No añadas --apply.

### Escena 3 — Explicar montaje y estado del RAID

Abre scripts/raid1_mount.sh y recorre todo el archivo de arriba abajo.

| Líneas | Qué explicar |
|---|---|
| 1–7 | Bash y parada ante errores; valores iniciales del arreglo, punto de montaje, simulación y confirmación. |
| 9–12 | fail() informa y termina de forma controlada. |
| 14–23 | El analizador recibe dispositivo, punto de montaje y opciones de aplicación/confirmación; rechaza opciones desconocidas. |
| 25–27 | Solo admite un arreglo /dev/md, exige ruta absoluta y evita montar sobre la raíz. |
| 29–34 | Simulación muestra la orden mount solicitada y comprueba arreglo/sistema de archivos, sin montar. |
| 36–41 | El modo real exige token de confirmación, root, dispositivo de bloque y utilidades del sistema. |
| 42–48 | Rechaza enlaces simbólicos, montajes previos, rutas existentes y formatos fuera de ext4/XFS. |
| 49–51 | Crea el punto y monta tras validar. No actualiza fstab, así que no persiste al reiniciar. |

Abre scripts/raid1_status.sh y explica sus 11 líneas: Bash y parada por errores (1–2), arreglo predeterminado (4), lectura de --array y ayuda (5–8), validación de ruta md (9), comprobación de mdadm y recordatorio del servidor Linux (10), y mdadm --detail para consultar el estado (11). Es una consulta; si no existe un RAID real en la VM, no inventes una salida. Puedes mostrar el comando esperado y el log de ejemplo, etiquetados como simulación.

### Escena 4 — Explicar las colas de impresión

Abre scripts/print_queues.sh. Recorre el código completo y señala estas partes:

| Líneas | Qué explicar |
|---|---|
| 1–6 | Bash, manejo estricto, IP reservada de documentación, aplicación desactivada y confirmación vacía. |
| 8–11 | fail() presenta errores y termina. |
| 13–21 | El bucle analiza --printer-ip, --apply, --confirm y ayuda; exige valores y rechaza opciones desconocidas. |
| 23–25 | Divide y comprueba los cuatro octetos de una dirección IPv4; evita valores fuera del rango. |
| 27–32 | Simula las colas aula_normal y aula_prioridad con IPP. La IP reservada es de ejemplo y lpadmin no se ejecutó. |
| 35–38 | Aplicar cambios requiere confirmación, root, una IP real reemplazada y lpadmin instalado. |
| 39–41 | Crea colas driverless IPP y comparte la prioritaria; indica cómo consultar con lpstat. |

Muestra el comando seguro:

    bash scripts/print_queues.sh

Explica la salida y confirma que la prueba automatizada verifica que lpadmin no se llamó.

Después abre scripts/print_job.sh y recorre sus 43 líneas.

| Líneas | Qué explicar |
|---|---|
| 1–8 | Selección de Bash, manejo de errores, cola normal, prioridad predeterminada, archivo vacío y modo de simulación. |
| 10–13 | fail() presenta el problema y termina. |
| 15–25 | Lee cola, prioridad, archivo y confirmación; procesa ayuda y parámetros desconocidos. |
| 27–30 | Limita la cola a las definidas, restringe prioridad al entero de 1 a 100 y exige un archivo. |
| 32–36 | En simulación muestra lp, cola y prioridad sin enviar el archivo. |
| 38–41 | En modo real exige token SEND_FILE_TO_PRINTER, archivo regular que no sea enlace simbólico y el programa lp disponible. |
| 42–43 | lp envía el trabajo; lpstat permite consultar la cola. No uses la rama real en este video. |

### Escena 5 — Revisar configuración de red e impresión

Abre config/smb.conf y recorre sus 21 líneas.

| Líneas | Qué explicar |
|---|---|
| 1–2 | Comentarios: adapta grupo y usuarios para el laboratorio. |
| 3 | Inicia la sección global de Samba. |
| 4–10 | Define grupo de trabajo, servidor independiente, autenticación por usuarios, invitados bloqueados, versión SMB mínima y archivo/límite del log. |
| 12 | Inicia el recurso compartido unidad3. |
| 13–20 | Define ruta, visibilidad, escritura, invitados bloqueados, grupo permitido/forzado y máscaras. 2770 conserva grupo y permisos compartidos. |
| 21 | Revisa el cierre/separador según la versión del archivo visible. |

Abre config/exports. Explica las tres líneas: dos comentarios aclaran que 192.0.2.0/24 solo documenta una red; la última exporta /srv/raid1/compartido con escritura sincronizada, sin comprobación de subárbol y root_squash para reducir privilegios de root remoto. Sustituye la red solo dentro de la VM privada.

Abre config/cupsd.conf y explica cada directiva en orden:

| Líneas | Qué explicar |
|---|---|
| 1 | Comentario: es plantilla restrictiva y el acceso remoto empieza apagado. |
| 2 | Listen localhost:631 limita el servicio al propio equipo. |
| 3–5 | Browsing desactiva anuncios; WebInterface habilita la interfaz; DefaultShared desactiva compartir por defecto. |
| 6–9 | La sección Location de raíz admite acceso solo desde localhost. |
| 10–13 | La administración también queda limitada a localhost. |
| 14–19 | Editar configuración requiere autenticación del grupo del sistema y acceso local. |
| 20–21 | Comentarios sobre agregar solo una subred privada autorizada; no usar Allow All ni exponer puerto 631 a Internet. |

Di: “Son plantillas. Editarlas no instala Samba, NFS ni CUPS. Primero se validan rutas y red de la VM; no se exponen servicios a Internet”.

### Escena 6 — Ejecutar la prueba aislada

Muestra tests/test_tarea33.sh completo; desplázate de principio a fin sin saltar líneas. Mientras lo haces, explica toda su secuencia:

1. Bash y opciones estrictas activan manejo de errores. root calcula la carpeta del proyecto; mktemp crea un entorno temporal; trap lo elimina al terminar.
2. fail() y pass() etiquetan fallos y aprobaciones. Un bucle corre bash -n en cada script para revisar sintaxis.
3. Crea sustitutos de mdadm, mount, lpadmin y lp dentro del temporal. Guardan las llamadas en una traza. PATH hace que la prueba encuentre esos sustitutos antes que las herramientas reales.
4. Prueba crear RAID en modo seguro: busca el comando simulado y comprueba que mdadm falso no se haya llamado.
5. Prueba montaje simulado y verifica que solo se haya mostrado mount.
6. Prueba que la salida CUPS incluya las dos colas, mientras lpadmin sigue sin ejecutarse.
7. Crea un archivo de texto temporal y solicita un trabajo simulado a aula_prioridad con prioridad 80; comprueba que lp no se haya llamado.
8. Prueba la rama de confirmación usando lp falso. La traza debe contener cola, prioridad y archivo; no se envía nada a una impresora.
9. Verifica el rechazo de miembros RAID duplicados, dispositivos ficticios en modo real, octetos IPv4 fuera de rango e IP reservada de documentación en modo real.
10. Imprime resumen final y elimina la carpeta temporal.

Ejecuta desde la raíz del proyecto:

    bash tests/test_tarea33.sh

Lee la salida real. PASS significa que pasó el escenario aislado con sustitutos; no significa que se creó RAID, se conectó una impresora o se compartió una carpeta real.

### Escena 7 — Mostrar logs y reporte

Abre logs/ y docs/. Muestra el nombre del log que contiene la carpeta y explica su texto como ejemplo de simulación, no como evidencia de desconexión física. En el reporte, revisa que el diagrama indique los dos discos espejo, la carpeta compartida, cómo se detectaría degradación y qué cola representa cada prioridad. Si la práctica real no se hizo, di “simulación” y deja pendientes las capturas reales.

### Escena 8 — Cierre

Resume: “El modo predeterminado muestra un plan. La prueba sustituye herramientas del sistema por comandos falsos y comprueba que la simulación no las ejecute. RAID real, montaje y cambios CUPS requieren recursos desechables y autorización en una VM; no se tocaron discos del anfitrión”. Mantén la cámara visible hasta acabar.

## Lista rápida antes de entregar

- [ ] Cámara en esquina inferior derecha sin tapar la pantalla.
- [ ] Se explicó la razón de cada carpeta.
- [ ] Se recorrieron scripts, pruebas y los tres archivos de configuración de arriba abajo.
- [ ] Se mostró RAID y colas en simulación, sin --apply.
- [ ] Se ejecutó la prueba aislada y se explicó su resultado real.
- [ ] Los logs se identificaron como simulados.
- [ ] No se afirma que se desconectó un disco o se imprimió en red si no se observó esa operación.
