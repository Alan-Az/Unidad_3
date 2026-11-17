# Guion de video — Tarea 3.2: permisos, cuotas y respaldos

## Objetivo y formato

Este guion corresponde únicamente a la Tarea 3.2. Sigue el orden de una grabación de pantalla e indica qué mostrar, qué decir y qué resultado observar. La Tarea 3.1 ya está realizada y queda fuera de este proyecto; la Tarea 3.3 tiene su propio guion.

Graba la pantalla con OBS o una herramienta equivalente. Activa la cámara y colócala en la esquina inferior derecha, sin cubrir la terminal ni el código. Habla despacio, aumenta el zoom del editor y deja pausas para que se lean las salidas. La demostración se hace en una máquina virtual Ubuntu de práctica; no ejecutes comandos de cuotas o permisos sobre Windows anfitrión.

## Carpetas de este proyecto

| Carpeta o archivo | Por qué existe y qué enseñar |
|---|---|
| Tarea_3.2/ | Contiene lo relacionado con permisos, cuotas y respaldos, separado de las demás actividades. |
| configs/ | Guarda plantillas POSIX/ACL y herramientas para consultar cuotas. Incluye una plantilla FSRM de Windows, alternativa que no se ejecuta en Ubuntu. |
| cron/ | Conserva el calendario de respaldo como ejemplo editable. El archivo no instala ni programa cron. |
| docs/ | Reúne explicación, reporte técnico y evidencia de restauración. Sirve para leer el diseño y guardar evidencia cuando el alumno haga la práctica. |
| tests/ | Aísla pruebas automáticas con datos temporales. Prueba la lógica del respaldo/restauración, no cuotas reales; nunca debe usar carpetas personales. |
| windows/ | Explica cómo crear una tarea programada en Windows, alternativa al cron de Ubuntu. |
| backup.sh | Respaldo principal para Ubuntu/Linux: completo, incremental, registro, hash, copia secundaria y restauración. |
| backup.ps1 | Alternativa para Windows PowerShell; no se ejecuta en Ubuntu. |
| README.md | Punto de entrada: resume el propósito, el uso y las precauciones. |

## Antes de grabar

1. Abre la máquina virtual Ubuntu y confirma que es la VM de laboratorio, no el anfitrión. Usa una cuenta de práctica.
2. Abre Tarea_3.2 en el editor. Aumenta la letra para que se vean el código y el número de línea.
3. En OBS, agrega la captura de pantalla y la cámara. Pon la cámara abajo a la derecha y comprueba que no tape comandos ni resultados.
4. Ten lista una carpeta temporal de prueba dentro de la VM. Nunca elijas una carpeta con tus documentos personales.
5. Di: “Los ejemplos principales se ejecutan en Ubuntu. Las cuotas del sistema y una programación real requieren una VM de laboratorio y configuración deliberada. Las pruebas automáticas usan datos temporales; no equivalen a cuotas de producción”.

## Grabación paso a paso

### Escena 1 — Presentar la actividad y el árbol

Muestra Tarea_3.2 y expande configs, cron, docs, tests y windows. Señala cada carpeta y explica su propósito con la tabla anterior. Aclara que docs conserva el reporte y evidencia del alumno; una plantilla o captura de ejemplo no demuestra por sí misma una restauración real.

Narra: “La actividad cubre permisos POSIX y ACL, cuotas por usuario y grupo, y respaldos completos e incrementales. Separé recetas, automatización, pruebas y documentos para encontrar cada cosa sin mezclarlas”.

### Escena 2 — Recorrer backup.sh línea por línea

Abre backup.sh. Recorre el archivo de arriba abajo; desplaza la pantalla para que se vean los números de línea. Explica cada línea visible usando la guía por bloques: menciona los nombres de variables, opciones y comandos, y explica qué dato recibe o qué efecto tiene cada uno. Los intervalos cubren las líneas actuales del archivo; no omitas líneas ejecutables entre ellos.

| Líneas | Qué explicar mientras se muestran |
|---|---|
| 1–5 | La primera línea elige Bash. Los comentarios describen el propósito; las opciones estrictas detienen el script ante errores o variables vacías. IFS controla cómo se separan palabras. umask 077 crea archivos privados por defecto. |
| 7–20 | usage() imprime ayuda; fail() informa y termina con error; log() añade hora UTC y escribe en pantalla y en el registro; need_value() verifica que una opción tenga su valor. |
| 22–44 | Las variables guardan origen, destino, estado, modo, copia secundaria y restauración. while/case interpreta los parámetros. shift avanza a la opción siguiente. Se rechazan las opciones desconocidas. |
| 46–71 | Restaurar exige confirmación. Primero compara SHA-256 y revisa las rutas dentro del archivo. Rechaza rutas absolutas o con .. para evitar extraer fuera del destino. Después registra inicio/fin y sale de la rama de restauración. |
| 73–92 | Comprueba el origen y el modo; normaliza rutas; evita guardar el respaldo dentro de su propio origen. Exige un destino secundario existente/montado y distinto del origen y destino principal. |
| 93–106 | Prepara el log y un candado exclusivo para impedir dos respaldos simultáneos. cleanup() borra temporales y libera el candado; trap asegura limpieza al salir, también cuando hay error. |
| 108–126 | Si se solicita incremental sin estado previo, empieza con un respaldo completo. Prepara nombres temporales y usa tar con gzip y el inventario incremental. |
| 127–151 | Calcula el hash, publica el archivo al moverlo a su nombre final, crea el sidecar .sha256 y actualiza el estado. Si hay copia secundaria, copia archivo/hash, compara huellas y registra el resultado. |

Narra: “El hash es una huella del archivo. Compararla permite detectar cambios o corrupción. Para restaurar una cadena incremental se necesita primero la copia completa y después cada incremental, en orden”.

### Escena 3 — Mostrar ayuda y probar el respaldo

En la terminal, desde Tarea_3.2, enseña la ayuda; no crea un respaldo:

    bash backup.sh --help

Explica que un destino secundario debe existir y estar montado antes de usarlo y que las rutas de ejemplo se cambian por carpetas descartables de la VM. Después ejecuta la prueba automática:

    bash tests/test-backup.sh

Deja visible toda la salida. Explica que la prueba usa archivos temporales, rechaza destinos inválidos, compara hashes, detecta corrupción y restaura una cadena completa más incremental. PASS significa que pasó esa prueba aislada; no demuestra que se haya probado un servidor secundario real. No apuntes la prueba a datos personales.

### Escena 4 — Explicar cuotas y ACL

Abre configs/posix-acl-cuotas.md. Es una receta para leer y adaptar, no un programa que se ejecuta entero a ciegas.

| Líneas | Qué explicar |
|---|---|
| 1, 5, 18, 35, 44 | Títulos y separadores de permisos, cuotas Linux, verificación y alternativa Windows. |
| 3, 16, 33, 42, 46 | Advertencias: VM/disco desechable, herencia, unidades y revisar el impacto antes de aplicar cambios. |
| 7, 9–14 | Explica modo 3770: SGID hereda el grupo y sticky limita quién borra archivos. groupadd crea grupo; install -d crea carpeta; setfacl define ACL y reglas por defecto; getfacl/stat verifican. |
| 20–23 | Selecciona un volumen de laboratorio y guarda copia de la configuración antes de editar opciones. Nunca cambies el volumen anfitrión. |
| 25–31 | Remonta, prepara/activa cuotas, establece límites de usuario y grupo y consulta el consumo. Cuota blanda admite periodo de gracia; cuota dura impide exceder el límite. |
| 37–40 | Comprueba sistema de archivos, opciones y reportes. Si las cuotas no están habilitadas, informa el resultado real; no inventes una salida exitosa. |
| 42–46 | Presenta FSRM/NTFS como alternativa Windows; no mezcles esos comandos con Ubuntu. |

Di que no activarás cuotas sobre la partición raíz de una instalación real. Para mostrar ACL, lee la receta o aplícala solo dentro de un volumen desechable de la VM.

### Escena 5 — Revisar verificadores y cuota Windows

| Archivo y líneas | Qué explicar |
|---|---|
| configs/verificar-cuotas.sh, 1–3 | Selecciona Bash y activa errores estrictos; el script consulta, no configura. |
| 4–9 | Exige un punto de montaje y verifica herramientas de consulta. |
| 10–18 | findmnt identifica el volumen; el ejemplo espera ext4 y opciones de cuotas. |
| 19–21 | quotaon -p y repquota -ug consultan estado y uso; no crean cuotas. |
| configs/verificar-cuotas.ps1, 1–8 | Requiere PowerShell, recibe volumen y rutas y detiene el informe ante errores. |
| 9–17 | Consulta el volumen y busca cada cuota FSRM; muestra SIN CUOTA si falta y sigue con la ruta siguiente. |
| 18–26 | Presenta uso, límite y porcentaje y consulta cuotas NTFS. Es Windows, no Ubuntu. |
| configs/fsrm-cuotas.ps1, 1–13 | Declara requisitos, parámetros, rutas y límites de ejemplo. -Apply es el interruptor para solicitar cambios reales. |
| 15–22 | Sin -Apply imprime la vista previa y sale; luego verifica que exista el cmdlet FSRM. |
| 23–34 | Comprueba que las carpetas existan y que no tengan ya cuota. ShouldProcess protege la creación y permite confirmar cada cambio. |

### Escena 6 — Cron y alternativa Windows

Abre cron/backup-tarea32.cron. Explica que programa un respaldo completo semanal el domingo a las 02:00 y respaldos incrementales de lunes a sábado a la misma hora. Repite: “Es una plantilla; no está instalada”. Antes de programarla habría que cambiar rutas, verificar el destino montado y elegir una cuenta con permisos adecuados.

Abre windows/tarea-programada.md y recorre sus 21 líneas: título, rutas de ejemplo, comando semanal, variante incremental y pasos en la interfaz del Programador de tareas. Esa alternativa ejecuta backup.ps1; no forma parte del Ubuntu.

### Escena 7 — Explicar los archivos restantes

Explica backup.ps1 como alternativa Windows, siguiendo sus bloques actuales: 1–20 requisitos y parámetros; 22–57 manejo de errores, log, rutas seguras e inventario/hash; 59–128 validación y restauración ZIP; 130–178 validación de rutas, secundario, candado y temporales; 179–246 cambios, ZIP, manifiesto y estado; 248–270 copia secundaria y limpieza. Repite que no se ejecuta en Ubuntu.

Muestra tests/test-backup.sh (líneas 1–90) y tests/test-backup.ps1 (líneas 1–88). La primera prueba rutas, destino secundario, checksum, copia completa/incremental y restauración. La segunda repite esas comprobaciones con PowerShell y limpia el temporal en finally. Son pruebas automáticas; no programan cron ni configuran cuotas.

### Escena 8 — Evidencia y cierre

Si preparaste una carpeta desechable y un segundo destino temporal dentro de la VM, explica el comando de respaldo usando esas rutas reales. Para evidenciar recuperación, crea un archivo de práctica, respáldalo, elimina únicamente esa copia desechable, restaura en otra carpeta y abre el archivo recuperado. Muestra el log y compara los hashes. No borres archivos personales.

Cierra diciendo: “Esta actividad separa la receta de permisos, la consulta de cuotas y la automatización de respaldos. Las pruebas trabajan con datos temporales. Una configuración real de cuotas o cron solo se aplica dentro de una VM preparada, con sus rutas de laboratorio verificadas”. Mantén la cámara visible hasta terminar.

## Lista rápida antes de entregar

- [ ] La pantalla se ve y la cámara permanece abajo a la derecha.
- [ ] Se explicó por qué existe cada carpeta y qué contiene.
- [ ] Se recorrieron de arriba abajo los scripts, pruebas y plantillas, explicando cada línea visible.
- [ ] Se mostró la ayuda y la prueba automática con su resultado real.
- [ ] Se distinguieron Ubuntu/Linux, Windows, ejemplos y cambios reales.
- [ ] La restauración, si se grabó, usa solo archivos desechables de la VM.
- [ ] No se afirma que cron, cuotas o un secundario estén configurados sin haberlo observado.
