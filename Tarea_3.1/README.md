# Tarea 3.1: Automatización de Administración de Usuarios, Grupos y Políticas de Acceso

Este proyecto contiene la suite completa de scripts de automatización y directivas de seguridad para la gestión de identidades en Linux (Ubuntu/Debian), diseñado bajo estándares de **Clean Code** y aislamiento seguro de privilegios.

---

## 1. Esquema Organizativo y Roles

| Rol / Departamento | Grupo Primario | Grupos Secundarios | Privilegios Administrativos | Horario de Acceso | Aislamiento de Home |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Sistemas** | `sistemas` | `admin` | Total (`ALL=(ALL:ALL) ALL` en sudoers) | 24/7 (Sin restricción) | `0700` (`rwx------`) |
| **Finanzas** | `finanzas` | `contabilidad`, `auditoria` | Ninguno (Sin acceso a sudo) | Lun-Vie 08:00 a 18:00 | `0700` (`rwx------`) |
| **Operaciones** | `operaciones` | `logistica`, `mantenimiento`| Consulta (`systemctl status`, `journalctl`) | Lun-Vie 08:00 a 18:00 | `0700` (`rwx------`) |

---

## 2. Estructura de Archivos

```text
Tarea_3.1/
├── README.md                           # Documentación completa y guía de ejecución
├── usuarios.csv                        # Lote de usuarios de prueba
├── altas.sh                            # Script de aprovisionamiento masivo
├── bajas.sh                            # Script de revocación, terminación y respaldo
└── configs/
    ├── configurar_seguridad.sh         # Instalador seguro de directivas
    ├── sudoers_tarea31                 # Reglas de elevación restringida
    ├── time.conf.snippet               # Reglas de horario pam_time
    └── faillock.conf.snippet           # Política de bloqueo de 3 intentos
```

---

## 3. Instrucciones de Ejecución en Máquina Virtual Linux

### Paso 1: Clonar o copiar los archivos a la VM
Dentro de la terminal de tu máquina virtual (Ubuntu/Debian):
```bash
git clone <URL_DE_TU_REPOSITORIO>
cd Unidad_3/Tarea_3.1
chmod +x altas.sh bajas.sh configs/configurar_seguridad.sh
```

### Paso 2: Ejecutar el aprovisionamiento de altas
```bash
sudo ./altas.sh usuarios.csv
```
*   Crea grupos departamentales y secundarios si no existen.
*   Crea cuentas de usuario con shell interactiva y home.
*   Genera contraseña temporal aleatoria criptográfica con `openssl`.
*   Fuerza expiración inmediata con `chage -d 0` (cambio obligado en primer login).
*   Aplica `chmod 700 /home/<usuario>`.
*   Registra credenciales temporales en `/root/credenciales_temporales.txt`.

Para consultar las contraseñas temporales generadas:
```bash
sudo cat /root/credenciales_temporales.txt
```

### Paso 3: Aplicar las directivas de seguridad (Sudoers, Horarios y Bloqueo)
```bash
sudo ./configs/configurar_seguridad.sh
```

---

## 4. Guía de Pruebas de Validación (Para Capturas y Video de YouTube)

### Prueba A: Aislamiento estricto de directorios
1. Iniciar sesión como usuario de finanzas:
   ```bash
   su - jperez
   ```
2. Intentar ingresar al directorio de otro usuario:
   ```bash
   cd /home/cgarcia
   ```
   **Resultado esperado**: `bash: cd: /home/cgarcia: Permission denied`.

### Prueba B: Cambio de contraseña forzado
1. Conectarse por terminal o consola como `cgarcia` usando su contraseña temporal:
   ```bash
   su - cgarcia
   ```
2. El sistema solicita:
   `You are required to change your password immediately (administrator enforced).`
3. Ingresar contraseña actual y definir una nueva.

### Prueba C: Control de Sudoers
1. Probar desde usuario `sistemas` (`mlopez`):
   ```bash
   su - mlopez
   sudo whoami
   ```
   **Resultado**: Imprime `root` tras validar clave.
2. Probar desde usuario `finanzas` (`jperez`):
   ```bash
   su - jperez
   sudo whoami
   ```
   **Resultado**: `jperez is not in the sudoers file. This incident will be reported.`
3. Probar comando permitido en `operaciones` (`cgarcia`):
   ```bash
   su - cgarcia
   sudo systemctl status ssh
   ```
   **Resultado**: Permite ver el estado del servicio.

### Prueba D: Bloqueo por 3 intentos fallidos (`pam_faillock`)
1. Intentar cambiar a un usuario fallando deliberadamente la contraseña 3 veces:
   ```bash
   su - jperez   # Fallar intento 1
   su - jperez   # Fallar intento 2
   su - jperez   # Fallar intento 3
   ```
2. Verificar el bloqueo como administrador:
   ```bash
   sudo faillock --user jperez
   ```
   Se mostrarán las 3 marcas de tiempo y el estado bloqueado.
3. Para desbloquear manualmente tras la prueba:
   ```bash
   sudo faillock --user jperez --reset
   ```

### Prueba E: Baja de usuario y respaldo
Ejecutar la baja de una cuenta:
```bash
sudo ./bajas.sh rvega
```
*   Mata procesos de `rvega`.
*   Genera respaldo comprimido en `/var/backups/homes/rvega_*.tar.gz`.
*   Elimina la cuenta del sistema y remueve `/home/rvega`.

---

## 5. Requisitos del Video en YouTube
*   **Webcam**: Cámara visible en la esquina inferior derecha durante toda la grabación.
*   **Secuencia demostrada**:
    1. Ejecución de `./altas.sh usuarios.csv`.
    2. Demostración de aislamiento de `/home/` (`Permission denied`).
    3. Login con contraseña temporal y cambio obligatorio.
    4. Prueba de `sudo` permitido para `sistemas` y denegado para `finanzas`.
    5. Fallo de 3 intentos y visualización de `faillock`.
    6. Ejecución de `./bajas.sh` mostrando el `.tar.gz` de respaldo generado.

