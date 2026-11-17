# Guion detallado de grabación — Tarea 3.3

## Qué vas a mostrar

Este video corresponde únicamente a Tarea 3.3. La Tarea 3.1 ya está hecha y no se toca; Tarea 3.2 tiene su propio guion. En Ubuntu muestra primero la explicación y las simulaciones seguras de los scripts. La carpeta actual no contiene evidencia de un RAID real degradado/reconstruido ni una impresión de red real: los logs incluidos son ejemplos marcados como simulación. No presentes esos ejemplos como operaciones que sí ocurrieron.

Graba toda la pantalla con OBS o equivalente. Deja la cámara en la esquina inferior derecha, sin cubrir editor ni terminal. Amplía el texto. Para resaltar código, arrastra el mouse por el margen de números desde la línea indicada hasta la última línea indicada; no escribas dentro del archivo mientras explicas.

~~~text
Duración sugerida: 10 a 14 minutos
Entorno: máquina virtual Ubuntu
Modo de esta demostración: simulación y pruebas aisladas
Nunca añadas --apply a los comandos de simulación
~~~

No crees una carpeta llamada Linux. Abre en Ubuntu la carpeta Tarea_3.3 copiada a tu carpeta personal o compartida con la VM. Windows C:\Dev\Rriojas\Unidad_3 no es una ruta que Bash Ubuntu pueda abrir sin una carpeta compartida configurada.

## Antes de grabar: confirma que estás en el proyecto correcto

Abre la Terminal de Ubuntu y escribe:

~~~bash
cd ~/Unidad_3/Tarea_3.3
pwd
printf '%s\n' config docs logs scripts tests README.md
~~~

Si guardaste Unidad_3 en otra ruta, cambia el primer comando por esa ubicación real. pwd debe terminar en Tarea_3.3. Si cd muestra error, localiza la carpeta de la VM antes de seguir. En el editor, expande config, docs, logs, scripts y tests.

Di: “Estoy dentro de Tarea 3.3 en mi máquina virtual Ubuntu. El proyecto contiene plantillas de red e impresión, scripts, pruebas aisladas, reportes y logs de ejemplo. Primero explicaré qué hace cada parte y después ejecutaré las simulaciones, que no modifican discos ni envían trabajos a una impresora.”

## Escena 1 — explica para qué existe cada carpeta

En el explorador de archivos del editor, señala cada carpeta y di:

- config/: “Aquí están las plantillas de Samba, NFS y CUPS. Describen una configuración, pero no la instalan ni la aplican por sí solas.”
- docs/: “Aquí está el reporte y el manual técnico. Reúnen el diseño, los límites de la prueba y la evidencia.”
- logs/: “Aquí se guardan ejemplos de degradación y reconstrucción. El propio proyecto los marca como simulados; no son registros obtenidos al desconectar discos.”
- scripts/: “Aquí están los cinco programas Bash: creación y montaje de RAID, consulta de estado, configuración de colas y envío de trabajos.”
- tests/: “Aquí hay una prueba aislada. Crea herramientas falsas en un directorio temporal para verificar la simulación sin cambiar servicios reales.”

Luego di: “El diseño usa RAID 1: dos discos guardan una copia espejo, así que el arreglo puede seguir funcionando si uno falla. RAID no sustituye los respaldos. La capacidad útil se aproxima a la de un solo miembro.”

## Escena 2 — recorre raid1_setup.sh

Abre scripts/raid1_setup.sh y resalta estos rangos. Después de cada selección, di el texto sugerido.

Selecciona líneas 1–17.

Di: “La línea 1 indica que se use Bash. La línea 2 detiene el script ante errores y fallos de tuberías. Las variables guardan los dos discos, el nombre del arreglo y la confirmación. Por defecto apply vale no, de modo que el programa empieza en simulación. usage muestra las opciones; fail imprime el motivo de rechazo y termina.”

Selecciona líneas 19–29.

Di: “Este ciclo lee lo que escribo después del nombre del script. device1 y device2 reciben los discos; array cambia el nombre del RAID; apply solicita la rama real y confirm contiene la frase de confirmación. La ayuda explica el uso y cualquier parámetro desconocido se rechaza.”

Selecciona líneas 31–41.

Di: “Estas validaciones exigen dos discos diferentes, rutas explícitas dentro de /dev y un destino dentro de /dev/md. Evitan aceptar el mismo miembro dos veces o una ruta con forma inesperada.”

Selecciona líneas 43–48.

Di: “Este es el camino predeterminado que voy a probar. Imprime el comando mdadm que se planea usar, incluye el aviso de que no tocó discos y termina. No ejecuta mdadm porque no añadí --apply.”

Selecciona líneas 50–75.

Di: “El resto solo se alcanza si alguien habilita la aplicación real. Requiere confirmación explícita, privilegios de administrador y herramientas disponibles. Examina que cada dispositivo sea un disco completo, que no tenga firmas, particiones ni montajes, y que el nombre del arreglo todavía no exista. Al final sí ejecutaría mdadm --create. Por eso no usaré esta rama en la grabación.”

En la terminal ejecuta el ejemplo seguro:

~~~bash
bash scripts/raid1_setup.sh --device1 /dev/mock-a --device2 /dev/mock-b
~~~

Deja la salida visible y di: “Las rutas mock son ficticias. La salida marcada SIMULACIÓN muestra el plan, pero no creó un arreglo ni escribió metadatos en ningún disco.”

## Escena 3 — recorre raid1_mount.sh y raid1_status.sh

Abre scripts/raid1_mount.sh. Resalta líneas 1–12 y di:

Di: “Aquí se define Bash, el comportamiento ante errores, el arreglo predeterminado, el punto de montaje y el modo seguro. La función fail presenta los errores. La simulación comienza activa y la confirmación está vacía.”

Resalta líneas 14–22 y di:

Di: “Este ciclo interpreta dispositivo, punto de montaje, solicitud de aplicación y confirmación. Si falta un valor o llega una opción desconocida, el script se detiene con un mensaje.”

Resalta líneas 24–33 y di:

Di: “El script acepta como origen solo una ruta bajo /dev/md, requiere que el punto de montaje sea una ruta absoluta y evita usar la raíz del sistema. Sin --apply, imprime el comando mount planeado y aclara que primero deben existir el arreglo y su sistema de archivos.”

Resalta líneas 35–48 y di:

Di: “Esta es la rama de montaje real: requiere una confirmación, administrador, un dispositivo de bloque, un sistema de archivos ext4 o xfs y un punto de montaje libre. Si todo es válido, monta el arreglo. No actualiza fstab, así que el montaje no queda configurado para el próximo reinicio.”

En la terminal ejecuta:

~~~bash
bash scripts/raid1_mount.sh --device /dev/md/mock --mountpoint /tmp/unidad3-demo
~~~

Di: “También es simulación. No existe aquí una orden de montaje activa; solo se muestra el plan para una ruta ficticia.”

Abre scripts/raid1_status.sh y selecciona líneas 1–11. Di:

Di: “Este archivo es una consulta de estado. Acepta opcionalmente el nombre de un arreglo, verifica que la ruta esté bajo /dev/md, comprueba que exista mdadm y finalmente ejecuta mdadm --detail. Para ver un estado real debe existir un RAID real en esta VM. No lo ejecuto como si hubiera un arreglo cuando no lo hay; mostraré los logs de ejemplo claramente identificados como simulados.”

## Escena 4 — recorre el script que configura colas CUPS

Abre scripts/print_queues.sh.

Selecciona líneas 1–11 y di:

Di: “El script usa Bash y se detiene ante errores. La IP predeterminada, 192.0.2.44, es una dirección reservada para documentación, no es una impresora. apply empieza en no. La función fail comunica errores y termina.”

Selecciona líneas 13–25 y di:

Di: “Este ciclo recibe la IP, el indicador apply y la confirmación. Después valida que la dirección tenga cuatro octetos entre 0 y 255. Si escribo una IP fuera de rango o una opción desconocida, no continúa.”

Selecciona líneas 27–33 y di:

Di: “Este es el modo que voy a mostrar. Presenta dos colas de ejemplo: aula_normal y aula_prioridad, usando IPP. Escribe la IP reservada en las órdenes que propone, avisa que es documentación y termina sin ejecutar lpadmin.”

Selecciona líneas 35–41 y di:

Di: “La rama real exige la frase de confirmación, permisos de administrador, una IP real que reemplace la reservada y el programa lpadmin instalado. Solo después crearía las colas. No activo esa rama en esta simulación.”

En la terminal ejecuta:

~~~bash
bash scripts/print_queues.sh
~~~

Di: “La salida debe comenzar con SIMULACIÓN y mostrar las dos órdenes lpadmin previstas. Eso demuestra la lógica de presentación del script, no que CUPS tenga las colas instaladas.”

## Escena 5 — recorre print_job.sh y prueba una prioridad

Abre scripts/print_job.sh. Selecciona líneas 1–13 y di:

Di: “Estas líneas preparan Bash, los errores, la cola normal predeterminada, prioridad 40, el archivo vacío, el modo seguro y la función que informa fallos.”

Selecciona líneas 15–30 y di:

Di: “El ciclo recibe cola, prioridad y archivo. Luego limita las colas a aula_normal o aula_prioridad, valida que la prioridad sea un entero entre 1 y 100 y exige un archivo.”

Selecciona líneas 32–36 y di:

Di: “Sin --apply, el programa imprime el comando lp que se usaría y sale. No manda nada a CUPS.”

Selecciona líneas 38–43 y di:

Di: “La rama real requiere una confirmación exacta, que el archivo exista y no sea un enlace simbólico, y que lp esté instalado. Después enviaría el trabajo y se podría consultar con lpstat. No usaré esa opción en esta práctica.”

Crea un archivo ficticio y simula una impresión prioritaria:

~~~bash
printf 'Documento ficticio para la demostracion.\n' > /tmp/tarea33-demo.txt
bash scripts/print_job.sh --queue aula_prioridad --priority 80 --file /tmp/tarea33-demo.txt
~~~

Di: “El comando muestra que elegiría la cola aula_prioridad con prioridad 80. La palabra SIMULACIÓN confirma que no envió el documento a una impresora.”

## Escena 6 — explica las plantillas Samba, NFS y CUPS

Abre config/smb.conf y recorre las líneas 1–21.

- Selecciona 1–3 y di: “Los comentarios indican que habrá que reemplazar el grupo y los usuarios de ejemplo. global inicia las opciones generales del servicio Samba.”
- Selecciona 4–10 y di: “Se elige un servidor independiente con autenticación por usuario, se bloquean invitados, se fija una versión mínima SMB y se define dónde guardar logs y su tamaño máximo.”
- Selecciona 12–21 y di: “La sección unidad3 comparte /srv/raid1/compartido. Solo el grupo indicado puede usarla; se asigna ese grupo a nuevos archivos y se definen máscaras de archivo y directorio para mantener permisos compartidos. Es una plantilla, todavía no es una carpeta accesible por red.”

Abre config/exports y selecciona sus líneas 1–3. Di:

Di: “Este ejemplo NFS usa 192.0.2.0/24, una red reservada para documentación. La línea final exporta la carpeta con escritura sincronizada y root_squash para que el root remoto no conserve privilegios de root en el servidor. Antes de usar NFS en un laboratorio se debe reemplazar la red por la subred privada autorizada.”

Abre config/cupsd.conf y recorre líneas 1–21.

- Selecciona 1–5 y di: “El acceso remoto queda apagado: CUPS escucha en localhost, no anuncia impresoras y no comparte por defecto.”
- Selecciona 6–13 y di: “Las rutas principales y de administración permiten acceso local solamente.”
- Selecciona 14–21 y di: “La configuración administrativa requiere autenticación del grupo del sistema. Los comentarios prohíben abrir CUPS a cualquier dirección o exponer el puerto 631 a Internet. Para una impresora en red, primero se debe definir una subred privada y una regla limitada.”

Di: “Estos archivos describen configuraciones. Editar o mostrar una plantilla no instala Samba, NFS o CUPS, ni demuestra que un cliente remoto pueda conectarse.”

## Escena 7 — ejecuta el test_tarea33.sh y explica lo que comprueba

Abre tests/test_tarea33.sh. Desplázate línea por línea; selecciona cada bloque y explica:

- Líneas 1–18: “Calcula la raíz del proyecto, crea un directorio temporal y configura su limpieza automática. Las funciones fail y pass hacen legible cada resultado. El bucle ejecuta bash -n para verificar la sintaxis de los scripts.”
- Líneas 20–34: “Crea versiones falsas de mdadm, mount, lpadmin y lp. Las llamadas se anotarían en un archivo de traza. Después verifica que la simulación de RAID solo imprima el plan y no llame a mdadm.”
- Líneas 36–47: “Comprueba el montaje simulado, las dos colas CUPS y la impresión con prioridad 80. Las herramientas falsas permiten observar si se habrían llamado, sin operar sobre servicios reales.”
- Líneas 49–62: “Para la rama de impresión confirmada usa lp falso y verifica que el registro contenga la cola, la prioridad y el archivo. No se envía realmente.”
- Líneas 64–82: “Comprueba que se rechacen miembros RAID repetidos, discos ficticios en modo real, IPv4 fuera de rango y la IP reservada para documentación. Luego imprime el resultado y el temporal se elimina.”

Vuelve a la raíz Tarea_3.3 en la terminal y ejecuta:

~~~bash
bash -n scripts/raid1_setup.sh && bash -n scripts/raid1_mount.sh && bash -n scripts/raid1_status.sh && bash -n scripts/print_queues.sh && bash -n scripts/print_job.sh
bash tests/test_tarea33.sh
~~~

Deja toda la salida de la prueba visible. Di:

Di: “La primera orden revisa la sintaxis Bash de los cinco scripts. La segunda ejecuta pruebas aisladas. Si aparece el mensaje final de éxito, se probaron estos casos con comandos ficticios y rutas de práctica. Esto no confirma un RAID real, una red compartida ni una impresión física.”

## Escena 8 — muestra los logs y aclara la evidencia pendiente

Abre logs/degradacion_simulada.log y logs/reconstruccion_simulada.log en el editor. Lee las líneas visibles y di:

Di: “Estos logs muestran el aspecto de un ejemplo de degradación y reconstrucción. Sus nombres y contenido dicen que son simulados; no los presentaré como si mdadm hubiera observado un fallo real.”

Luego abre docs/reporte-tecnico.md y señala el diagrama RAID, la carpeta compartida y las colas. Di:

Di: “El reporte resume la topología y la configuración prevista. Para demostrar el punto de fallo y reconstrucción real hacen falta discos virtuales vacíos conectados a esta VM y capturas de mdadm antes, durante y después. Para probar impresión en red se necesita CUPS activo, una impresora o destino IPP de laboratorio y una estación cliente autorizada. Esos resultados no se producen con la prueba aislada de este proyecto.”

## Cierre — texto para decir

Di: “En esta grabación recorrí cada script y cada plantilla, probé el modo de simulación y ejecuté las pruebas aisladas. No desconecté discos, no formateé volúmenes y no envié una impresión real. Los archivos permiten explicar el flujo seguro y validar algunas reglas; la evidencia de RAID degradado/reconstruido y de impresión por red debe obtenerse aparte dentro de una VM de laboratorio.”

Mantén la cámara visible hasta terminar. Si no realizaste la práctica real, conserva la palabra simulación en la narración, en los logs y en el reporte.

## Lista rápida para revisar el video

- [ ] Cámara en la esquina inferior derecha y texto legible.
- [ ] Explicaste por qué existe cada carpeta.
- [ ] Mostraste rangos de líneas y narraste su función.
- [ ] Ejecutaste las simulaciones sin --apply.
- [ ] Ejecutaste el análisis de sintaxis y tests/test_tarea33.sh.
- [ ] Diferenciaste las pruebas aisladas de la operación real.
- [ ] Identificaste los logs como simulados.
- [ ] No afirmaste una desconexión de disco ni una impresión de red que no hayas realizado.
