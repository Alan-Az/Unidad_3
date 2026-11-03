# Guion y Checklist para Video de YouTube (Tarea 3.1)

**Requisito de la actividad**: Cámara web visible obligatoriamente en la esquina inferior derecha durante toda la grabación.  
**Duración recomendada**: Entre 4 y 7 minutos.  
**Herramienta de grabación**: OBS Studio (Captura de ventana de VirtualBox / terminal + Captura de dispositivo de video).

---

## Cronograma de Grabación Paso a Paso

### 1. Introducción (0:00 - 0:45)
* **En pantalla**: Terminal limpia y cámara web activa en esquina inferior derecha.
* **Qué decir**:
  > *"Hola, mi nombre es [Tu Nombre], estudiante de la materia de Sistemas Operativos. En este video voy a demostrar el funcionamiento de la Tarea 3.1: Automatización de administración de usuarios, grupos y políticas de acceso en Linux."*
* **Muestra**: Breve visualización de la estructura de carpetas:
  ```bash
  ls -la
  cat ../usuarios.csv
  ```

---

### 2. Aprovisionamiento por Lotes (0:45 - 1:45)
* **Qué hacer**:
  1. Ejecutar el script de altas:
     ```bash
     sudo ./altas.sh ../usuarios.csv
     ```
  2. Mostrar las contraseñas temporales generadas:
     ```bash
     sudo cat /root/credenciales_temporales.txt
     ```
  3. Verificar que las carpetas personales se crearon con permisos `700`:
     ```bash
     ls -ld /home/*
     ```
* **Qué explicar**: Explicar que el script creó los grupos departamentales (`sistemas`, `finanzas`, `operaciones`), asignó contraseñas temporales aleatorias y restringió los permisos a `rwx------`.

---

### 3. Demostración de Aislamiento de Directorios (1:45 - 2:30)
* **Qué hacer**:
  1. Iniciar sesión como usuario de finanzas:
     ```bash
     su - jperez
     ```
  2. Intentar ingresar a la carpeta de otro usuario (Operaciones):
     ```bash
     cd /home/cgarcia
     ```
* **Resultado en pantalla**: `bash: cd: /home/cgarcia: Permission denied`.
* **Qué explicar**: Explicar cómo el permiso `0700` garantiza la privacidad interdepartamental impidiendo que un usuario acceda a los archivos de otro.

---

### 4. Primer Inicio de Sesión y Cambio Obligatorio de Clave (2:30 - 3:30)
* **Qué hacer**:
  1. Cerrar sesión anterior con `exit`.
  2. Iniciar sesión como `cgarcia` usando su contraseña temporal copiada del archivo de credenciales:
     ```bash
     su - cgarcia
     ```
* **Resultado en pantalla**: El sistema muestra:  
  `You are required to change your password immediately (administrator enforced).`
* **Acción**: Ingresar la clave temporal y definir una nueva contraseña personalizada.
* **Qué explicar**: Explicar que `chage -d 0` marca la contraseña como caducada al instante de la creación para forzar al usuario a renovarla.

---

### 5. Control de Sudoers y Elevación Administrativa (3:30 - 4:45)
* **Qué hacer**:
  1. Probar desde usuario `sistemas` (`mlopez`):
     ```bash
     su - mlopez
     sudo whoami
     ```
     *Muestra:* `root`.
  2. Probar desde usuario `finanzas` (`jperez`):
     ```bash
     su - jperez
     sudo whoami
     ```
     *Muestra:* `jperez is not in the sudoers file. This incident will be reported.`
  3. Probar comando permitido en `operaciones` (`cgarcia`):
     ```bash
     su - cgarcia
     sudo systemctl status ssh
     ```
     *Muestra:* El estado del servicio ssh.
* **Qué explicar**: Demostrar cómo el archivo `/etc/sudoers.d/tarea31_seguridad` restringe la administración completa a Sistemas y limita a Operaciones solo a tareas de monitoreo.

---

### 6. Prueba de Bloqueo por Intentos Fallidos (`faillock`) (4:45 - 5:45)
* **Qué hacer**:
  1. Regresar a tu cuenta administradora (`exit`).
  2. Fallar deliberadamente 3 veces la contraseña de `jperez`:
     ```bash
     su - jperez   # Error 1
     su - jperez   # Error 2
     su - jperez   # Error 3
     ```
  3. Mostrar el estado de bloqueo en PAM:
     ```bash
     sudo faillock --user jperez
     ```
* **Resultado en pantalla**: Muestra los 3 registros de fallos y el estado bloqueado durante 300 segundos.

---

### 7. Script de Bajas y Respaldo Automático (5:45 - 6:30)
* **Qué hacer**:
  1. Ejecutar la baja del usuario `rvega`:
     ```bash
     sudo ./bajas.sh rvega
     ```
  2. Mostrar que se generó el respaldo comprimido:
     ```bash
     ls -lh /var/backups/homes/
     ```
  3. Comprobar que el usuario ya no existe en el sistema:
     ```bash
     id rvega
     ```
* **Qué explicar**: El script mató los procesos del usuario, empaquetó su carpeta home en `.tar.gz` para resguardo forense y lo eliminó de la base de datos de usuarios.

---

### 8. Despedida (6:30 - 7:00)
* **Qué decir**:
  > *"Con estas pruebas queda validado el funcionamiento de la automatización de altas, bajas, aislamiento de directorios y políticas de seguridad para la Tarea 3.1. Gracias."*

