# Guion detallado de grabación — Tarea 3.2

## Qué vas a mostrar

Este video es solo del proyecto Tarea 3.2. La Tarea 3.1 ya está hecha y no se modifica. Graba la pantalla en Ubuntu; coloca tu cámara en la esquina inferior derecha. Aumenta el zoom del editor y deja quieta cada selección mientras explicas.

No crees una carpeta llamada Linux. Conserva la estructura actual: abre en Ubuntu la carpeta Tarea_3.2 que copiaste a tu carpeta personal o que compartiste con la máquina virtual. Una ruta de Windows como C:\Dev\Rriojas\Unidad_3 no funciona directamente en la terminal Ubuntu a menos que hayas configurado una carpeta compartida.

~~~text
Duración sugerida: 9 a 12 minutos
Editor: VS Code o editor de texto con números de línea visibles
Terminal: Bash dentro de la VM Ubuntu
Cámara: esquina inferior derecha
~~~

## Antes de grabar: abre el proyecto y comprueba la ruta

En la VM, abre Terminal y escribe:

~~~bash
cd ~/Unidad_3/Tarea_3.2
pwd
printf '%s\n' *
~~~

Si guardaste la carpeta en otra ubicación, cambia solo la ruta del primer comando. La salida de pwd debe terminar en Tarea_3.2. La lista debe incluir backup.sh, configs, cron, docs y tests. Si la terminal dice que la ruta no existe, abre la carpeta real de la VM desde el administrador de archivos; no continúes con una ruta inventada.

Di: “Estoy dentro de la carpeta de la actividad 3.2 en mi máquina virtual Ubuntu. Aquí están separados el script de respaldo, las plantillas de permisos y cuotas, el ejemplo de programación, las pruebas y el reporte. Voy a trabajar con datos temporales de práctica.”

## Escena 1 — presenta la estructura y el propósito

En el editor, abre README.md y selecciona con el mouse las líneas 1–19. Mantén la selección visible mientras dices:

Di: “Esta actividad propone una política de respaldos completos e incrementales y guarda dos versiones del script: Bash para Linux y PowerShell para Windows. En esta grabación voy a demostrar la versión Bash dentro de Ubuntu. Las carpetas configs y cron contienen plantillas: tenerlas en el proyecto no significa que las cuotas o la programación ya estén activadas en el sistema.”

Ahora señala en el explorador del editor estas carpetas, una por una: configs, cron, docs y tests. Di:

Di: “La carpeta configs explica ACL y cuotas. cron contiene un ejemplo de horario. docs reúne el reporte y la evidencia de las pruebas. tests contiene una prueba que usa carpetas temporales. Esta separación permite encontrar cada parte sin mezclarla con los proyectos 3.1 y 3.3.”

## Escena 2 — explica las primeras líneas de backup.sh

Abre backup.sh. Selecciona las líneas 1–5 y di:

Di: “La primera línea pide ejecutar este archivo con Bash. La línea 3 activa opciones estrictas: el script se detiene si ocurre un error, si se usa una variable vacía o si falla una parte de una tubería. IFS organiza cómo se separan algunos valores y umask restringe los permisos de los archivos nuevos para que el respaldo no quede abierto para todas las cuentas.”

Selecciona las líneas 7–20 y di:

Di: “La función usage muestra cómo se usa el programa. Aquí aparecen las opciones para respaldar y para restaurar. También se aclara que una copia incremental depende de una completa anterior y que el destino secundario debe estar montado antes. Las funciones fail, log y need_value centralizan los errores, el registro con fecha y la comprobación de que cada opción reciba un valor.”

Selecciona las líneas 22–44 y di:

Di: “Estas variables empiezan vacías o con un valor seguro por defecto. Después, el ciclo recorre cada argumento de la terminal: source elige los datos de origen, destination el destino principal, state guarda el estado incremental y mode elige entre full e incremental. Las opciones de restore y target seleccionan el archivo y la carpeta donde se recuperará. Si el usuario escribe una opción desconocida o deja un valor vacío, el script informa el error.”

## Escena 3 — explica restauración y protecciones

Selecciona las líneas 46–70 y di:

Di: “Este bloque se ejecuta cuando pedimos restaurar. Exige la confirmación --force, comprueba que existan el archivo y su suma SHA-256 y compara ambas sumas antes de extraer. También inspecciona los nombres dentro del archivo y rechaza rutas que intenten salir de la carpeta de destino. Al final extrae sin restaurar propietario ni permisos del equipo que creó el archivo y registra el resultado. Por eso la restauración del ejemplo apunta a una carpeta temporal vacía.”

Selecciona las líneas 73–106 y di:

Di: “Antes de crear una copia, el script comprueba que el origen exista, que el modo sea válido y que el destino no esté dentro del origen. También valida que el destino secundario no sea el origen ni esté dentro del destino principal. Crea un bloqueo para evitar dos respaldos simultáneos y registra una limpieza para retirar los archivos temporales si el proceso termina.”

Selecciona las líneas 108–134 y di:

Di: “Aquí se prepara el archivo. Si se pide incremental sin que exista un estado previo, la primera ejecución se convierte en completa y lo deja escrito en el log. GNU tar crea el archivo comprimido usando el estado incremental. Luego se calcula SHA-256, se guarda la suma junto al archivo y se actualiza el estado para la siguiente ejecución.”

Selecciona las líneas 136–151 y di:

Di: “Esta parte es opcional. Si se indicó un segundo destino que ya existe y está montado, copia el archivo y su suma; después calcula otra vez la suma y compara los valores. El script no monta discos ni conecta por sí mismo a un NAS. Si falla la copia secundaria, deja constancia del error y termina con fallo.”

## Escena 4 — prepara datos de prueba en una carpeta temporal

Vuelve a la terminal. Explica que todos los archivos de esta demostración se crean en una carpeta temporal dentro de tu usuario Ubuntu. Escribe cada bloque despacio:

~~~bash
DEMO=$(mktemp -d "$HOME/tarea32.XXXXXX")
mkdir -p "$DEMO/origen" "$DEMO/copias" "$DEMO/secundario"
printf 'version 1\n' > "$DEMO/origen/nota.txt"
printf 'este archivo se borrara en la prueba\n' > "$DEMO/origen/borrar.txt"
printf 'Carpeta temporal: %s\n' "$DEMO"
~~~

Di: “La variable DEMO guarda una ruta nueva y temporal. Estoy creando dos archivos de texto ficticios, un destino principal y un destino secundario local de prueba. No estoy usando documentos personales ni un disco del anfitrión.”

## Escena 5 — ejecuta la copia completa y revisa su integridad

Escribe:

~~~bash
bash backup.sh --source "$DEMO/origen" --destination "$DEMO/copias" --state "$DEMO/estado.snar" --mode full --secondary "$DEMO/secundario"
~~~

Espera a que termine. Señala la línea que dice “Respaldo full creado y verificado”. Di:

Di: “Esta es una copia completa: incluye el contenido actual del origen. El registro indica que se creó y verificó. El destino secundario de esta práctica es otra carpeta temporal; representa el paso de copia, pero no es un segundo disco ni un servidor NAS.”

Ahora ejecuta la verificación del archivo y la comparación de la copia secundaria:

~~~bash
FULL=$(printf '%s\n' "$DEMO"/copias/*_full.tar.gz)
(cd "$DEMO/copias" && sha256sum -c "$(basename "$FULL").sha256")
cmp "$FULL" "$DEMO/secundario/$(basename "$FULL")" && printf 'Copia secundaria identica: si\n'
tail -n 5 "$DEMO/copias/backup.log"
~~~

Di: “sha256sum -c confirma que el archivo coincide con la suma guardada. cmp no imprime diferencias cuando los dos archivos son iguales; por eso aparece el mensaje de copia idéntica. Las últimas líneas del log conservan la evidencia de la operación.”

## Escena 6 — cambia datos y genera una incremental

Escribe:

~~~bash
printf 'version 2\n' > "$DEMO/origen/nota.txt"
rm -- "$DEMO/origen/borrar.txt"
printf 'archivo agregado despues\n' > "$DEMO/origen/nuevo.txt"
bash backup.sh --source "$DEMO/origen" --destination "$DEMO/copias" --state "$DEMO/estado.snar" --mode incremental --secondary "$DEMO/secundario"
~~~

Di: “Modifiqué una nota, eliminé el archivo de prueba y agregué otro. Ahora el modo incremental registra los cambios desde la copia anterior y conserva la relación con el archivo de estado. En una política real, las incrementales se restauran después de su copia completa y en orden.”

## Escena 7 — recupera y demuestra el resultado

Escribe estos comandos en este orden:

~~~bash
INCR=$(printf '%s\n' "$DEMO"/copias/*_incremental.tar.gz)
bash backup.sh --restore "$FULL" --target "$DEMO/restaurado" --force
bash backup.sh --restore "$INCR" --target "$DEMO/restaurado" --force
IFS= read -r CONTENIDO < "$DEMO/restaurado/nota.txt"
printf 'Nota recuperada: %s\n' "$CONTENIDO"
test -f "$DEMO/restaurado/nuevo.txt" && printf 'Archivo nuevo recuperado: si\n'
test ! -e "$DEMO/restaurado/borrar.txt" && printf 'El borrado tambien se refleja: si\n'
tail -n 5 "$DEMO/copias/restore.log"
~~~

Di: “Primero restauro la copia completa y después la incremental, ambas en una carpeta nueva. La nota recuperada muestra la versión 2; el archivo nuevo está presente y el archivo que eliminé ya no aparece. Esta prueba demuestra la restauración de estos datos temporales, no de un servidor productivo.”

## Escena 8 — ejecuta las pruebas automáticas

En la terminal escribe:

~~~bash
bash tests/test-backup.sh
~~~

Deja la salida completa visible. Di:

Di: “Esta prueba automatizada crea sus propios archivos temporales y verifica la copia completa, la incremental, la suma, la restauración y algunos rechazos de rutas inseguras. Si todas las comprobaciones terminan con PASS, el script se comporta como se espera en estos casos aislados. La prueba limpia su propia carpeta temporal al terminar.”

## Escena 9 — muestra permisos, ACL y cuotas sin cambiar el volumen

Abre configs/posix-acl-cuotas.md. Selecciona las líneas 5–16 y di:

Di: “Esta sección propone una carpeta compartida con SGID y sticky bit. SGID ayuda a que los archivos nuevos conserven el grupo del directorio; sticky limita quién puede borrar archivos de otros. Las líneas setfacl agregan una ACL y una ACL predeterminada para la herencia. En esta grabación las presento como instrucciones del proyecto y no las aplico a un volumen real.”

Selecciona las líneas 18–42 y di:

Di: “Aquí se explica el procedimiento de cuotas en ext4: identificar el volumen correcto, habilitar usrquota y grpquota, crear los índices, activar cuotas y definir límites. Los números son ejemplos, no límites ya instalados. No voy a cambiar /etc/fstab ni ejecutar setquota sobre el disco anfitrión. Para que esta parte cuente como validación real, se necesita una partición virtual desechable, cuotas habilitadas y capturas de quota y repquota después de probar con archivos de práctica.”

Si quieres mostrar solo el bit POSIX en un directorio temporal, escribe:

~~~bash
mkdir -p "$DEMO/compartido"
chmod 3770 "$DEMO/compartido"
stat -c '%A %a %U:%G %n' "$DEMO/compartido"
~~~

Di: “El modo numérico 3770 combina sticky bit y SGID con acceso de lectura, escritura y ejecución para propietario y grupo. Esta comprobación se limita a una carpeta temporal; no demuestra por sí sola la herencia de ACL ni una cuota de disco.”

## Escena 10 — explica la política y el cron de ejemplo

Abre cron/backup-tarea32.cron y selecciona las líneas 1–6. Di:

Di: “Este archivo propone una copia completa el domingo a las dos de la mañana y una incremental de lunes a sábado a la misma hora. Es un ejemplo, no un cron activo. Las rutas deben ajustarse y el destino secundario debe estar montado antes de programarlo. No voy a copiarlo a /etc/cron.d durante esta demostración.”

Abre docs/reporte-tecnico.md y selecciona la parte de la política. Di:

Di: “El RPO de 24 horas y el RTO de 4 horas son objetivos propuestos. El RPO describe cuántos cambios se podrían perder según la frecuencia del respaldo; el RTO es el tiempo objetivo para volver a disponer de los datos. En esta práctica no medimos el tiempo de recuperación de un servidor real.”

## Cierre — resume con precisión

Di: “En esta grabación ejecuté en Ubuntu el script Bash con archivos temporales: creé una copia completa, una incremental, verifiqué SHA-256, comparé la copia secundaria y recuperé los archivos. También recorrí las plantillas de ACL, cuotas y cron. No afirmo que las cuotas estén activas, que cron esté instalado ni que se haya probado el RTO o el RPO en un servidor real. Para entregar evidencia de esas partes, debo completarlas y capturarlas en una VM con un volumen de laboratorio.”

Antes de terminar, muestra en pantalla las carpetas tests, configs y cron y la salida final de restauración. No publiques contraseñas, documentos personales ni rutas que contengan datos privados.
