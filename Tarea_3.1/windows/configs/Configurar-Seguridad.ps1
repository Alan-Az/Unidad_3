#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configuración de políticas de seguridad local en Windows:
    bloqueo de cuentas por intentos fallidos y control de administración delegada.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== 1. Aplicando Política de Bloqueo por Intentos Fallidos ===" -ForegroundColor Cyan
# 3 intentos fallidos bloquean la cuenta durante 5 minutos dentro de una ventana de 15 minutos
net accounts /lockoutthreshold:3 /lockoutduration:5 /lockoutwindow:15
Write-Host "[OK] Política de bloqueo configurada (Umbral: 3 fallos | Duración: 5 min | Ventana: 15 min)." -ForegroundColor Green

Write-Host "`n=== 2. Configurando Elevación Administrativa (Equivalente Sudoers) ===" -ForegroundColor Cyan
# El grupo departamental 'sistemas' recibe permisos de elevación administrativa en Windows
$adminGroupName = (Get-LocalGroup | Where-Object { $_.SID -eq 'S-1-5-32-544' }).Name # Nombre nativo (Administrators / Administradores)

if (Get-LocalGroup -Name "sistemas" -ErrorAction SilentlyContinue) {
    $sistemasMembers = Get-LocalGroupMember -Group "sistemas" -ErrorAction SilentlyContinue
    foreach ($m in $sistemasMembers) {
        if (-not (Get-LocalGroupMember -Group $adminGroupName -Member $m.Name -ErrorAction SilentlyContinue)) {
            Add-LocalGroupMember -Group $adminGroupName -Member $m.Name
            Write-Host "[OK] Usuario '$($m.Name)' (de Sistemas) agregado a '$adminGroupName'." -ForegroundColor Green
        }
    }
} else {
    Write-Host "[INFO] Grupo 'sistemas' aún no existe. Ejecuta primero Altas.ps1." -ForegroundColor Yellow
}

Write-Host "`n=== 3. Estado Actual de Políticas Locales de Seguridad ===" -ForegroundColor Cyan
net accounts
