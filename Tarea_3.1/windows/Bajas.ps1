#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Revocación y eliminación segura de cuentas locales en Windows.
.DESCRIPTION
    Deshabilita la cuenta de inmediato, respalda su carpeta personal
    en un archivo ZIP dentro de C:\Backups\Homes\ y elimina la cuenta de la
    base de datos de seguridad local (SAM).
.PARAMETER Target
    Nombre de usuario o ruta a archivo CSV para procesar bajas por lote.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Target
)

$ErrorActionPreference = 'Stop'

$LogFile = "C:\Windows\Temp\bajas_usuarios.log"
$BackupDir = "C:\Backups\Homes"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    Write-Output $line
    Add-Content -Path $LogFile -Value $line -Force
}

function Remove-UserSecurely {
    param([Parameter(Mandatory = $true)][string]$UserName)

    if (-not (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)) {
        Write-Log 'WARN' "El usuario local '$UserName' no existe en el sistema. Omitiendo."
        return
    }

    # 1. Deshabilitar cuenta para revocar inicios de sesión
    Disable-LocalUser -Name $UserName
    Write-Log 'INFO' "Cuenta '$UserName' deshabilitada."

    # 2. Respaldar carpeta personal si existe
    $homeDir = "C:\Users\$UserName"
    if (Test-Path -Path $homeDir) {
        if (-not (Test-Path -Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }

        $dateStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $zipFile = Join-Path -Path $BackupDir -ChildPath "${UserName}_${dateStamp}.zip"
        
        try {
            Compress-Archive -Path "$homeDir\*" -DestinationPath $zipFile -Force
            Write-Log 'INFO' "Carpeta personal respaldada en: $zipFile"
            Remove-Item -Path $homeDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log 'WARN' "No se pudo respaldar/eliminar completamente '$homeDir': $_"
        }
    }

    # 3. Eliminar usuario de la base SAM
    Remove-LocalUser -Name $UserName
    Write-Log 'INFO' "Usuario '$UserName' eliminado del sistema."
}

# --- Punto de Entrada ---
if (Test-Path -Path $Target -PathType Leaf) {
    Write-Log 'INFO' "=== Procesando bajas por lote desde: $Target ==="
    $rows = Import-Csv -Path $Target
    foreach ($row in $rows) {
        $uName = $row.usuario.Trim()
        if ($uName -and $uName -ne "usuario") {
            Remove-UserSecurely -UserName $uName
        }
    }
} else {
    Write-Log 'INFO' "=== Procesando baja individual para: $Target ==="
    Remove-UserSecurely -UserName $Target
}

Write-Log 'INFO' "=== Operación de bajas finalizada ==="

