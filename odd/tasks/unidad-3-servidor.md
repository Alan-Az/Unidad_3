# Unidad 3: entregables de administración del servidor
Objetivo: completar Tarea 3.2 y Tarea 3.3 en sus carpetas, preservar Tarea 3.1 y entregar guion y manual legibles.
Branch: feat/unidad-3-servidor (Windows denegó la escritura en .git; checkout actual main). Delivery: ask-on-risk; forecast: ~900 authored lines; test runner: Bash syntax/simulation, PowerShell AST/simulation, artifact readback.
## Specs
### S1 — Tarea 3.2
Alcance autorizado: crear entregables dentro de Tarea_3.2/. Requisitos textuales: “Tarea 3.2: Permisos avanzados, cuotas de disco y política de respaldos automatizados”; “Configura permisos POSIX estándar y Listas de Control de Acceso (ACLs) avanzadas en el sistema de archivos (directorios compartidos con sticky bits, SGID y herencia de permisos).”; “Configura cuotas de disco por usuario y grupo.”; “Diseña una política formal de respaldos (completos, diferenciales/incrementales).”; “Desarrolla y programa un script (cron o Tareas Programadas) que genere respaldos automáticos comprimidos, cree logs de verificación y los monte/transfiera a un medio secundario o servidor de almacenamiento.”
Entregables: reporte técnico PDF con RTO/RPO, verificación de cuotas y restauración; backup.sh, backup.ps1, ejemplos de cron/Tareas Programadas y plantillas de configuración. Pruebas aisladas; no instalar cuotas ni programar tareas en este equipo.
### S2 — Tarea 3.3
Alcance autorizado: crear entregables dentro de Tarea_3.3/. Requisitos textuales: “Tarea 3.3: Configuración de almacenamiento redundante (RAID/NAS) y colas de impresión”; “Configura un arreglo de discos redundante por software (RAID 1 o RAID 5 usando mdadm o Storage Spaces) y monta una unidad compartida de red (NFS o Samba).”; “Instala y configura un servidor de impresión (CUPS o Servidor de Impresión de Windows), administrando controladores, colas de impresión, asignación de prioridades y compartición mediante TCP/IP.”
Supuesto: Linux con RAID 1 mdadm, Samba/NFS y CUPS, ya que el usuario pidió smb.conf, exports, scripts de montaje RAID, logs de degradación/reconstrucción y mencionó mdadm --detail. Aceptación: reporte PDF con topología, simulación de fallo/reconstrucción y colas; configuraciones y scripts; cambios de discos/servicios protegidos por confirmación explícita. Pruebas con comandos simulados y sin dispositivos reales.
### S3 — Documentación compartida y límites
Mantener en la raíz Manual_Codigo_Unidad_3.md y Guion_Video_Unidad_3.md como índice. Crear un guion independiente para la Tarea 3.2 en Tarea_3.2/Guion_Video_Tarea_3.2.md y otro para la Tarea 3.3 en Tarea_3.3/Guion_Video_Tarea_3.3.md. Explicar en cada tutorial, línea por línea, el código de su proyecto, para qué existe cada carpeta y cómo realizar la grabación de pantalla con cámara en la esquina inferior derecha. Orientar la demostración a una VM Ubuntu, distinguiendo ejemplos, simulaciones y cambios reales. La Tarea 3.1 ya está realizada y no se modifica. No publicar en GitHub/YouTube ni afirmar que hay enlaces públicos; preparar el contenido local.
## Tasks
- T1 — S1 — delegated direct — status: in progress — commit: pending (no se pudo crear branch).
- T2 — S2 — inline parent fallback — status: in progress — commit: pending (delegated writer access failed; parent can write).
- T3 — S3 — inline — status: complete — commit: pending (no se pudo crear la rama de trabajo).

## Log
### L1 — Solicitud original
neceicto que planetes lo isugientes actividades, todo se desarollara en la carpeta de C:\Dev\Rriojas\Unidad_3, ya cada actividad tiene asiganda una carpeta para su respectivo contenido mencionado en las actividades, lo que se plantea es lo sigueinte,&#x20;

### Unidad 3: Gestión del servidor

- **Competencia específica:** Conoce, configura y gestiona usuarios, sistemas de archivos y dispositivos mediante el uso de la interfaz gráfica y línea de comandos para el sistema operativo.

**Tarea 3.1: Automatización de administración de usuarios, grupos y políticas de acceso**

- **Instrucciones para el alumno:**

1. Diseña un esquema organizativo con roles y grupos departamentales (e.g., Sistemas, Finanzas, Operaciones).
2. Desarrolla scripts en Bash/PowerShell para la creación automatizada de cuentas de usuario, asignación de directorios home, contraseñas temporales forzadas, expiración y membresía a grupos secundarios.
3. Aplica restricciones de seguridad: horarios de acceso, control de sudoers/grupos de administración y políticas de bloqueo por intentos fallidos.

- **Entregables en Teams:**\
\
1. Manual técnico en PDF con diagramación de grupos, tabla de permisos por rol, código documentado y capturas de validación.
2. Enlace a repositorio público de GitHub: Carpeta Unidad_3/Tarea_3.1/ con los scripts de automatización de altas/bajas de usuarios y asignación de directivas.
3. Enlace público de YouTube: Video ejecutando los scripts de creación de usuarios por lotes, probando permisos de ejecución/acceso restringido y demostrando el aislamiento de directorios con cámara web en la esquina inferior derecha en tu canal de YouTube.

\
**Tarea 3.2: Permisos avanzados, cuotas de disco y política de respaldos automatizados**

- **Instrucciones para el alumno:**\
\
1. Configura permisos POSIX estándar y Listas de Control de Acceso (ACLs) avanzadas en el sistema de archivos (directorios compartidos con sticky bits, SGID y herencia de permisos).
2. Configura cuotas de disco por usuario y grupo.
3. Diseña una política formal de respaldos (completos, diferenciales/incrementales).
4. Desarrolla y programa un script (cron o Tareas Programadas) que genere respaldos automáticos comprimidos, cree logs de verificación y los monte/transfiera a un medio secundario o servidor de almacenamiento.

\
- **Entregables en Teams:**\
\
1. Reporte técnico en PDF con el diseño de la política de respaldo (RTO/RPO), verificación de cuotas de disco y evidencia de restauración exitosa a partir de un respaldo.
2. Enlace a repositorio público de GitHub: Carpeta Unidad_3/Tarea_3.2/ con los scripts de respaldo (backup.sh / backup.ps1), crontabs de ejemplo y plantillas de configuración.
3. Enlace público de YouTube: Video explicando la lógica del script de respaldo, la ejecución manual y calendarizada, y una prueba de recuperación de archivos borrados con cámara web en la esquina inferior derecha en tu canal de YouTube.

\
**Tarea 3.3: Configuración de almacenamiento redundante (RAID/NAS) y colas de impresión**

- **Instrucciones para el alumno:**\
\
1. Configura un arreglo de discos redundante por software (RAID 1 o RAID 5 usando mdadm o Storage Spaces) y monta una unidad compartida de red (NFS o Samba).
2. Instala y configura un servidor de impresión (CUPS o Servidor de Impresión de Windows), administrando controladores, colas de impresión, asignación de prioridades y compartición mediante TCP/IP.

\
- **Entregables en Teams:**\
\
1. Reporte técnico en PDF con los diagramas de volumen RAID, simulación de fallo/reconstrucción de disco y configuración de colas de impresión.
2. Enlace a repositorio público de GitHub: Carpeta Unidad_3/Tarea_3.3/ con los archivos de configuración (smb.conf, exports, scripts de montaje RAID) y logs de degradación/reconstrucción.
3. Enlace público de YouTube: Video demostrando el estado del arreglo RAID (mdadm --detail o PowerShell), simulación de desconexión de disco y prueba de impresión en red con cámara web en la esquina inferior derecha en tu canal de YouTube.

toma en concidereacion lo siguiente neceitaras desarollar cada actividad en su respectiva careta comko se detalle en el texto anterior, desarolla y prueba cada activiadad a excepcion de la activdad 3.1 ya que esa ya esta realizada, si neceitas puedes inspirarte en esta para desarollar una estructura similar pero no la modifques, tienes permisos totales, realiza lo nececisario, siepre y cunado no afecte negativamente al equipo, si se acaba tu cuota espera el reinicio para proceder automaticmaente, tienes permitodo desplegar diversos agentes, pero no exageres en disingar tareas simples a modelos altos, lleva logica y seguimiento de los agnetes, ademas no los audites siempre, dales su tarea, espera a que acaben, auditarlos, corrigelos hast teer los resutlados esperados y ya, mientras ellos trabajan tu apagate para que no consumas tokens de mas solo observando, solo auditoa y que se consiga lo que se requiere, sige una estrucutra como la mencionada, si no se mencioan alguna estructura selecciona la mas logica y en cuestion a lo realizado, encecito que al final realizez un archivo .md donde realizez un guion del viodo, ademas de un archivo en el cual especifiques y documentos cada codigo, ya sea cada clase cada metodo etc, explicando su fuioncon y objetivo, tanto asi como para que alguein que no sepa nada de progrmacion u/o ofimatica logre entenderlo
### L2 — Delegation fallback
The delegated Tarea 3.3 writer could not write files in its process even after a parent-level folder grant. Parent resumed T2 inline; no Tarea 3.1 files were changed.

### L3 — Corrección del usuario, 2026-11-16
okey el guion del vido explica linea de codigo por linea de codigo y la rason de ser de cada carpeta ademas de los pasos para hacerlos por tutorial grabado en la pantalla

### L4 — Corrección del usuario, 2026-11-16
si separalos es un gion por proyecto y el de la activiadad 3.1 ya esta echa

Se crearon guiones independientes en Tarea_3.2 y Tarea_3.3; Tarea_3.1 quedó intacta.
