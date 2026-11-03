# Tarea 3.1: Automatización de Administración de Usuarios, Grupos y Políticas de Acceso

Este proyecto contiene la suite completa de scripts de automatización y directivas de seguridad para la gestión de identidades, con soporte nativo para **Linux (Bash)** y **Windows (PowerShell)** bajo estándares de **Clean Code**.

---

## 1. Esquema Organizativo y Roles

| Rol / Departamento | Grupo Primario | Grupos Secundarios | Privilegios Administrativos | Horario de Acceso | Aislamiento de Home |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Sistemas** | `sistemas` | `admin` | Total (Sudoers en Linux / Administradores en Windows) | 24/7 (Sin restricción) | `0700` / ACL sin herencia |
| **Finanzas** | `finanzas` | `contabilidad`, `auditoria` | Ninguno (Sin privilegios elevados) | Lun-Vie 08:00 a 18:00 | `0700` / ACL sin herencia |
| **Operaciones** | `operaciones` | `logistica`, `mantenimiento`| Consulta restringida (`systemctl status`, `journalctl`) | Lun-Vie 08:00 a 18:00 | `0700` / ACL sin herencia |

---

## 2. Estructura de Archivos

```text
Tarea_3.1/
├── README.md                           # Documentación completa y guía de ejecución
├── usuarios.csv                        # Lote de usuarios de prueba (compartido)
├── linux/                              # Suite de scripts para Linux (Ubuntu/Debian)
│   ├── altas.sh                        # Aprovisionamiento masivo en Bash
│   ├── bajas.sh                        # Revocación, terminación y respaldo
│   └── configs/
│       ├── configurar_seguridad.sh     # Instalador de directivas PAM y sudoers
│       ├── sudoers_tarea31             # Reglas de elevación restringida
│       ├── time.conf.snippet           # Reglas de horario pam_time
│       └── faillock.conf.snippet       # Política de bloqueo de 3 intentos
└── windows/                            # Suite de scripts para Windows (PowerShell)
    ├── Altas.ps1                       # Aprovisionamiento masivo en PowerShell
    ├── Bajas.ps1                       # Revocación y respaldo ZIP
    └── configs/
        └── Configurar-Seguridad.ps1    # Políticas de bloqueo (net accounts) y elevación
```

---

## 3. Instrucciones de Ejecución

### Opción A: Entorno Linux (Ubuntu/Debian)

1. **Dar permisos de ejecución**:
   ```bash
   cd Tarea_3.1/linux
   chmod +x altas.sh bajas.sh configs/configurar_seguridad.sh
   ```

2. **Ejecutar alta de usuarios por lote**:
   ```bash
   sudo ./altas.sh ../usuarios.csv
   ```
   *Credenciales temporales generadas en:* `/root/credenciales_temporales.txt`.

3. **Aplicar políticas de seguridad (Sudoers, pam_time y faillock)**:
   ```bash
   sudo ./configs/configurar_seguridad.sh
   ```

4. **Ejecutar baja de usuario y respaldo**:
   ```bash
   sudo ./bajas.sh rvega
   ```

---

### Opción B: Entorno Windows (PowerShell con Permisos de Administrador)

1. **Abrir PowerShell como Administrador** y navegar a la carpeta:
   ```powershell
   cd Tarea_3.1\windows
   ```

2. **Ejecutar alta de usuarios por lote**:
   ```powershell
   .\Altas.ps1 -CsvPath ..\usuarios.csv
   ```
   *Credenciales temporales generadas en:* `C:\Windows\Temp\credenciales_temporales.txt`.

3. **Aplicar políticas de seguridad (Bloqueo SAM y elevación de Sistemas)**:
   ```powershell
   .\configs\Configurar-Seguridad.ps1
   ```

4. **Ejecutar baja de usuario y respaldo**:
   ```powershell
   .\Bajas.ps1 -Target rvega
   ```

---

## 4. Guía de Pruebas de Validación (Para Capturas y Video de YouTube)

| # | Prueba | Linux (Bash) | Windows (PowerShell) | Resultado Esperado |
| :--- | :--- | :--- | :--- | :--- |
| **1** | Aislamiento de carpetas | `su - jperez` seguido de `cd /home/cgarcia` | Iniciar con `jperez` y abrir `C:\Users\cgarcia` | `Permission denied` / Acceso denegado |
| **2** | Password temporal expirada | Iniciar sesión por consola | Iniciar sesión en pantalla de login | Exige cambio de contraseña inmediato |
| **3** | Elevación administrativa | `sudo whoami` desde `mlopez` y `jperez` | Ejecutar terminal elevada con credencial | Permitido en Sistemas, denegado en Finanzas |
| **4** | Bloqueo por 3 fallos | 3 contraseñas erróneas -> `sudo faillock --user jperez` | 3 contraseñas erróneas -> `net user jperez` | Cuenta bloqueada |
| **5** | Baja y respaldo | `sudo ./bajas.sh rvega` | `.\Bajas.ps1 -Target rvega` | Cuenta removida y home respaldado (`.tar.gz` o `.zip`) |
