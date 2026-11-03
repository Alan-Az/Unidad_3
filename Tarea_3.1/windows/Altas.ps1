#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Aprovisionamiento automatizado de cuentas de usuario por lotes en Windows.
.DESCRIPTION
    Lee un archivo CSV con la estructura departamental, crea grupos locales,
    genera usuarios con contraseñas temporales forzadas a cambiar en el primer
    inicio, define fecha de expiración, aplica restricción de horarios y
    establece aislamiento estricto de carpetas home mediante ACLs de NTFS.
.PARAMETER CsvPath
    Ruta al archivo CSV con los datos de usuarios.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$CsvPath = "$PSScriptRoot\..\usuarios.csv"
)

$ErrorActionPreference = 'Stop'

$LogFile = "C:\Windows\Temp\altas_usuarios.log"
$CredentialsFile = "C:\Windows\Temp\credenciales_temporales.txt"

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

function Ensure-LocalGroup {
    param([Parameter(Mandatory = $true)][string]$GroupName)
    
    if (-not (Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $GroupName -Description "Grupo departamental $GroupName" | Out-Null
        Write-Log 'INFO' "Grupo local '$GroupName' creado."
    }
}

function New-SecureTemporaryPassword {
    $alphaUpper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $alphaLower = "abcdefghjkmnpqrstuvwxyz"
    $digits = "23456789"
    $symbols = "!@#$%^&*"
    
    $rnd = New-Object System.Random
    $chars = @(
        $alphaUpper[$rnd.Next(0, $alphaUpper.Length)],
        $alphaLower[$rnd.Next(0, $alphaLower.Length)],
        $digits[$rnd.Next(0, $digits.Length)],
        $symbols[$rnd.Next(0, $symbols.Length)]
    )
    
    $allChars = $alphaUpper + $alphaLower + $digits + $symbols
    for ($i = 0; $i -lt 8; $i++) {
        $chars += $allChars[$rnd.Next(0, $allChars.Length)]
    }
    
    # Barajar caracteres
    $shuffled = -join ($chars | Sort-Object { $rnd.Next() })
    return "Temp.$shuffled"
}

function Set-HomeIsolation {
    param(
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $true)][string]$FolderPath
    )
    
    if (-not (Test-Path -Path $FolderPath)) {
        New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null
    }

    $acl = Get-Acl -Path $FolderPath
    # Deshabilitar herencia y descartar reglas heredadas ($true, $false)
    $acl.SetAccessRuleProtection($true, $false)

    $inherit = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $prop = [System.Security.AccessControl.PropagationFlags]::None
    $allow = [System.Security.AccessControl.AccessControlType]::Allow

    # Reglas explícitas: Propietario, Administradores y SYSTEM
    $ruleUser = New-Object System.Security.AccessControl.FileSystemAccessRule($UserName, "FullControl", $inherit, $prop, $allow)
    $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", $inherit, $prop, $allow)
    $ruleSystem = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", $inherit, $prop, $allow)

    $acl.AddAccessRule($ruleUser)
    $acl.AddAccessRule($ruleAdmins)
    $acl.AddAccessRule($ruleSystem)

    Set-Acl -Path $FolderPath -AclObject $acl
}

# --- Punto de Entrada ---
if (-not (Test-Path -Path $CsvPath -PathType Leaf)) {
    Write-Error "No se encontró el archivo CSV en la ruta: $CsvPath"
}

Write-Log 'INFO' "=== Iniciando aprovisionamiento masivo en Windows desde: $CsvPath ==="
Set-Content -Path $CredentialsFile -Value "# Credenciales temporales generadas $(Get-Date)" -Force

$rows = Import-Csv -Path $CsvPath

foreach ($row in $rows) {
    $uName = $row.usuario.Trim()
    $fName = $row.nombre_completo.Trim()
    $pGroup = $row.grupo_primario.Trim()
    $sGroups = $row.grupos_secundarios.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $days = [int]$row.expira_dias

    if (Get-LocalUser -Name $uName -ErrorAction SilentlyContinue) {
        Write-Log 'WARN' "El usuario local '$uName' ya existe. Omitiendo."
        continue
    }

    # 1. Asegurar existencia de grupos
    Ensure-LocalGroup -GroupName $pGroup
    foreach ($sg in $sGroups) {
        Ensure-LocalGroup -GroupName $sg
    }

    # 2. Generar contraseña temporal
    $plainPass = New-SecureTemporaryPassword
    $securePass = ConvertTo-SecureString -String $plainPass -AsPlainText -Force
    $expDate = (Get-Date).AddDays($days)

    # 3. Crear usuario
    New-LocalUser -Name $uName `
                   -Password $securePass `
                   -FullName $fName `
                   -AccountExpires $expDate `
                   -PasswordNeverExpires:$false | Out-Null

    # 4. Forzar cambio de contraseña en primer inicio de sesión
    Set-LocalUser -Name $uName -PasswordExpired $true

    # 5. Asignar membresía a grupos
    Add-LocalGroupMember -Group $pGroup -Member $uName
    foreach ($sg in $sGroups) {
        Add-LocalGroupMember -Group $sg -Member $uName
    }

    # 6. Restricción de horario laboral (solo permitido Lun-Vie 08:00 a 18:00 para no-sistemas)
    if ($pGroup -ne "sistemas") {
        net user $uName /time:M-F,08:00-18:00 | Out-Null
    }

    # 7. Aislamiento estricto de directorio home en C:\Users\<usuario>
    $homeDir = "C:\Users\$uName"
    Set-HomeIsolation -UserName $uName -FolderPath $homeDir

    Write-Log 'INFO' "Usuario '$uName' creado exitosamente | Grupo: $pGroup | Expira: $expDate"
    Add-Content -Path $CredentialsFile -Value "Usuario: $uName | Password Temporal: $plainPass | Expira: $expDate"
}

Write-Log 'INFO' "=== Aprovisionamiento finalizado. Credenciales registradas en: $CredentialsFile ==="
