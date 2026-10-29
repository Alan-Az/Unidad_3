#Requires -Version 5.1
<#
.SYNOPSIS
    Automated user provisioning, deprovisioning, and security hardening for Windows.
    Tiers: 1. direccion, 2. gerencia, 3. operaciones, 4. soporte.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Elevate,
    [switch]$Deprovision,
    [string]$TargetUser = "all",
    [string]$TempPasswordPlain = "TempPass2026!",
    [string]$HomeRoot = "C:\Users"
)

$ErrorActionPreference = "Stop"

# Load .env if present
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line.Split("=", 2)
            if ($parts.Count -eq 2) {
                [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
            }
        }
    }
}

if ($env:TEMP_PASS -and $TempPasswordPlain -eq "TempPass2026!") {
    $TempPasswordPlain = $env:TEMP_PASS
}

$LockoutAttempts = if ($env:LOCKOUT_MAX_ATTEMPTS) { [int]$env:LOCKOUT_MAX_ATTEMPTS } else { 3 }
$LockoutMinutes  = if ($env:LOCKOUT_DURATION_MINUTES) { [int]$env:LOCKOUT_DURATION_MINUTES } else { 15 }

function Write-LogInfo    { param([string]$Msg) Write-Host "[INFO]     $Msg" -ForegroundColor Cyan }
function Write-LogStep    { param([string]$Msg) Write-Host "`n>>> [PASO] $Msg" -ForegroundColor Yellow }
function Write-LogCreate  { param([string]$Msg) Write-Host "[CREAR]    $Msg" -ForegroundColor Green }
function Write-LogEdit    { param([string]$Msg) Write-Host "[EDITAR]   $Msg" -ForegroundColor Magenta }
function Write-LogDelete  { param([string]$Msg) Write-Host "[BAJA]     $Msg" -ForegroundColor Red }
function Write-LogSec     { param([string]$Msg) Write-Host "[SEGURIDAD]$Msg" -ForegroundColor DarkYellow }
function Write-LogSuccess { param([string]$Msg) Write-Host "[EXITO]    $Msg" -ForegroundColor Green }
function Write-LogSim     { param([string]$Msg) Write-Host "           [SIMULACION] $Msg" -ForegroundColor DarkGray }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $DryRun) {
    if ($Elevate) {
        Write-LogInfo "Solicitando elevacion UAC para ejecutar como Administrador..."
        $extraArgs = if ($Deprovision) { "-Deprovision -TargetUser `"$TargetUser`"" } else { "" }
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $extraArgs"
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait
        exit 0
    }
    Write-Host "[AVISO] La sesion actual no cuenta con privilegios de Administrador." -ForegroundColor Yellow
    Write-Host "        Cambiando automaticamente a modo -DryRun (Simulacion)." -ForegroundColor Yellow
    Write-Host "        (Para aplicar cambios use: .\setup_users.ps1 -Elevate)`n" -ForegroundColor DarkGray
    $DryRun = $true
}

function Invoke-Step {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-LogSim $Description
    } else {
        & $Action
    }
}

$isSpanishOS = ((Get-UICulture).TwoLetterISOLanguageName -eq "es")
$ScheduleBroad  = if ($isSpanishOS) { "L-S,07:00-21:00" } else { "M-Sa,07:00-21:00" }
$ScheduleStrict = if ($isSpanishOS) { "L-V,08:00-17:00" } else { "M-F,08:00-17:00" }

$TargetGroups = @(
    @{ Name = "direccion";          Description = "Nivel 1: Directivo y Estrategico (KPI: Margen neto, EBITDA, cuota de mercado)" },
    @{ Name = "gerencia";           Description = "Nivel 2: Tactico / Mandos Medios (KPI: Plazos, costo por entrega, productividad)" },
    @{ Name = "operaciones";        Description = "Nivel 3: Operativo / Ejecucion (KPI: Tickets, entregables, ventas cerradas)" },
    @{ Name = "soporte";            Description = "Nivel 4: Soporte y Gobernanza (KPI: Rotacion, uptime, cumplimiento legal)" },
    @{ Name = "sudo";               Description = "Administracion total de infraestructura y seguridad" },
    @{ Name = "auditoria_finanzas"; Description = "Acceso a auditoria presupuestal, fiscal y cumplimiento" },
    @{ Name = "uso_operaciones";    Description = "Acceso a recursos y herramientas operativas" },
    @{ Name = "impresoras";         Description = "Uso y cola de servicios de impresion" }
)

# 9 functional operational roles (removed redundant read-only roles: cfo, cro, mkt_gerente, ventas_gerente, ejec_cuentas)
$TargetUsers = @(
    @{
        Name        = "ceo"
        FullName    = "Director General (CEO)"
        Description = "Estrategia, supervivencia y crecimiento (KPI: Margen neto, EBITDA)"
        Tier        = "Directivo"
        Primary     = "direccion"
        Secondary   = @("sudo", "gerencia", "operaciones", "soporte", "auditoria_finanzas", "uso_operaciones", "impresoras")
        AdminLevel  = "Full"
        Expires     = [datetime]"2028-12-31T23:59:59"
        Times       = "ALL"
    },
    @{
        Name        = "coo"
        FullName    = "Director de Operaciones (COO)"
        Description = "Supervision de procesos diarios y alineacion estrategica"
        Tier        = "Directivo"
        Primary     = "direccion"
        Secondary   = @("gerencia", "operaciones", "soporte", "auditoria_finanzas", "uso_operaciones", "impresoras")
        AdminLevel  = "Supervisor"
        Expires     = [datetime]"2028-12-31T23:59:59"
        Times       = "ALL"
    },
    @{
        Name        = "pm_gerente"
        FullName    = "Gerente de Proyecto (Project Manager)"
        Description = "Coordinacion, tiempos y presupuestos (KPI: Cumplimiento de plazos)"
        Tier        = "Tactico"
        Primary     = "gerencia"
        Secondary   = @("operaciones", "auditoria_finanzas", "uso_operaciones", "impresoras")
        AdminLevel  = "Supervisor"
        Expires     = [datetime]"2027-06-30T23:59:59"
        Times       = $ScheduleBroad
    },
    @{
        Name        = "tech_lead"
        FullName    = "Lider Tecnico (Lead Developer)"
        Description = "Estandares tecnicos, mentoria y arquitectura del sistema"
        Tier        = "Tactico"
        Primary     = "gerencia"
        Secondary   = @("operaciones", "uso_operaciones", "impresoras")
        AdminLevel  = "Supervisor"
        Expires     = [datetime]"2027-06-30T23:59:59"
        Times       = $ScheduleBroad
    },
    @{
        Name        = "esp_operativo"
        FullName    = "Especialista Operativo (Dev / Diseno)"
        Description = "Produccion, calidad y ejecucion diaria (KPI: Entregables de codigo)"
        Tier        = "Operativo"
        Primary     = "operaciones"
        Secondary   = @("uso_operaciones", "impresoras")
        AdminLevel  = "None"
        Expires     = [datetime]"2027-01-31T23:59:59"
        Times       = $ScheduleStrict
    },
    @{
        Name        = "esp_soporte"
        FullName    = "Especialista en Atencion al Cliente"
        Description = "Resolucion de incidentes diarios (KPI: Tickets resueltos)"
        Tier        = "Operativo"
        Primary     = "operaciones"
        Secondary   = @("uso_operaciones", "impresoras")
        AdminLevel  = "None"
        Expires     = [datetime]"2027-01-31T23:59:59"
        Times       = $ScheduleStrict
    },
    @{
        Name        = "rh_talento"
        FullName    = "Recursos Humanos y Talento"
        Description = "Habilitacion interna y clima laboral (KPI: Rotacion de personal)"
        Tier        = "Soporte"
        Primary     = "soporte"
        Secondary   = @("impresoras")
        AdminLevel  = "None"
        Expires     = [datetime]"2027-12-31T23:59:59"
        Times       = $ScheduleBroad
    },
    @{
        Name        = "ti_secops"
        FullName    = "TI y Seguridad Informatica (SecOps)"
        Description = "Estabilidad tecnica y ciberseguridad (KPI: Tiempo de inactividad)"
        Tier        = "Soporte"
        Primary     = "soporte"
        Secondary   = @("sudo", "direccion", "gerencia", "operaciones", "auditoria_finanzas", "uso_operaciones", "impresoras")
        AdminLevel  = "Full"
        Expires     = [datetime]"2028-12-31T23:59:59"
        Times       = "ALL"
    },
    @{
        Name        = "legal_compliance"
        FullName    = "Legal y Cumplimiento (Compliance)"
        Description = "Gestion de riesgo y normativa sectorial (KPI: Cumplimiento legal)"
        Tier        = "Soporte"
        Primary     = "soporte"
        Secondary   = @("auditoria_finanzas", "impresoras")
        AdminLevel  = "Supervisor"
        Expires     = [datetime]"2027-12-31T23:59:59"
        Times       = $ScheduleBroad
    }
)

# ----------------- DEPROVISIONING (BAJAS) -----------------
if ($Deprovision) {
    Write-LogStep "Iniciando proceso de BAJA de usuarios (Objetivo: $TargetUser)..."
    function Remove-UserAccount([string]$uName) {
        Write-LogDelete "Procesando baja de usuario: '$uName'..."
        Invoke-Step "Cerrar procesos y sesiones de '$uName'" {
            Get-Process -IncludeUserName -ErrorAction SilentlyContinue | Where-Object { $_.UserName -like "*\$uName" } | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Invoke-Step "Remove-LocalUser -Name '$uName'" {
            if (Get-LocalUser -Name $uName -ErrorAction SilentlyContinue) {
                Remove-LocalUser -Name $uName
            }
        }
        $uHome = Join-Path $HomeRoot $uName
        if (Test-Path $uHome) {
            Invoke-Step "Remover carpeta home '$uHome'" {
                Remove-Item -Path $uHome -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if ($TargetUser -eq "all") {
        foreach ($u in $TargetUsers) { Remove-UserAccount $u.Name }
        Write-LogDelete "Eliminando grupos locales departamentales y funcionales creados..."
        foreach ($grp in $TargetGroups) {
            $gName = $grp.Name
            if ($gName -ne "sudo") {
                Invoke-Step "Remove-LocalGroup -Name '$gName'" {
                    if (Get-LocalGroup -Name $gName -ErrorAction SilentlyContinue) {
                        Remove-LocalGroup -Name $gName
                    }
                }
            }
        }
    } else {
        Remove-UserAccount $TargetUser
    }
    Write-LogSuccess "Operacion de baja finalizada."
    exit 0
}

# ----------------- PROVISIONING -----------------
Write-LogInfo "Cultura del sistema: $((Get-UICulture).Name) (Modo idioma: $(if ($isSpanishOS) {'Espanol'} else {'Ingles'}))"

Write-LogStep "Fase 1/4: Creacion y verificacion de grupos locales con descripcion..."
foreach ($grp in $TargetGroups) {
    $gName = $grp.Name
    $gDesc = $grp.Description
    if (Get-LocalGroup -Name $gName -ErrorAction SilentlyContinue) {
        Write-LogInfo "Grupo local existente: '$gName'"
    } else {
        Write-LogCreate "Creando grupo local: '$gName' ($gDesc)..."
        Invoke-Step "New-LocalGroup -Name '$gName'" { New-LocalGroup -Name $gName -Description $gDesc | Out-Null }
    }
}

Write-LogStep "Fase 2/4: Aprovisionamiento con ACLs estrictas en Home Root ($HomeRoot)..."
$SecurePass = ConvertTo-SecureString $TempPasswordPlain -AsPlainText -Force
$AdminGroupSid = "S-1-5-32-544"
$EventLogSid   = "S-1-5-32-573"
$PerfLogSid    = "S-1-5-32-559"
$PrintOpSid    = "S-1-5-32-550"

foreach ($u in $TargetUsers) {
    $name = $u.Name
    $homeDir = Join-Path $HomeRoot $name
    $userExists = Get-LocalUser -Name $name -ErrorAction SilentlyContinue

    if (-not $userExists) {
        Write-LogCreate "Creando cuenta '$name' [$($u.Tier) - $($u.FullName)]..."
        Invoke-Step "New-LocalUser -Name '$name'" {
            New-LocalUser -Name $name -Password $SecurePass -FullName $u.FullName -Description $u.Description -AccountExpires $u.Expires -PasswordNeverExpires:$false | Out-Null
        }
    } else {
        Write-LogEdit "Modificando cuenta '$name'..."
        Invoke-Step "Set-LocalUser -Name '$name'" {
            Set-LocalUser -Name $name -Password $SecurePass -FullName $u.FullName -Description $u.Description -AccountExpires $u.Expires -PasswordNeverExpires:$false
        }
    }

    # Strict Home Isolation via ACL
    Write-LogSec "Aislando home '$homeDir' (Herencia deshabilitada; solo Administradores y '$name')..."
    Invoke-Step "Configurar carpeta y ACL para '$name'" {
        if (-not (Test-Path $homeDir)) {
            New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
        }
        $acl = Get-Acl $homeDir
        $acl.SetAccessRuleProtection($true, $false) # Disable inheritance
        
        $adminGroup = [System.Security.Principal.SecurityIdentifier]::new($AdminGroupSid)
        $systemSid   = [System.Security.Principal.SecurityIdentifier]::new("S-1-5-18")
        $ruleAdmin = [System.Security.AccessControl.FileSystemAccessRule]::new($adminGroup, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $ruleSystem = [System.Security.AccessControl.FileSystemAccessRule]::new($systemSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $ruleUser   = [System.Security.AccessControl.FileSystemAccessRule]::new($name, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        
        $acl.AddAccessRule($ruleAdmin)
        $acl.AddAccessRule($ruleSystem)
        $acl.AddAccessRule($ruleUser)
        Set-Acl -Path $homeDir -AclObject $acl

        & net.exe user $name "/homedir:$homeDir" /passwordchg:yes /logonpasswordchg:yes | Out-Null
    }

    # Groups
    $allGroups = @($u.Primary) + $u.Secondary
    foreach ($g in $allGroups) {
        Invoke-Step "Add-LocalGroupMember -Group '$g' -Member '$name'" {
            Add-LocalGroupMember -Group $g -Member $name -ErrorAction SilentlyContinue
        }
    }

    # Schedules with robust fallback on $LASTEXITCODE
    Write-LogSec "Aplicando horario para '$name': [$($u.Times)]..."
    Invoke-Step "net.exe user '$name' /times:$($u.Times) con fallback" {
        & net.exe user $name "/times:$($u.Times)" 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0 -and $u.Times -ne "ALL") {
            $fallback = if ($u.Times -like "L-*") {
                $u.Times -replace '^L-S,','M-Sa,' -replace '^L-V,','M-F,'
            } else {
                $u.Times -replace '^M-Sa,','L-S,' -replace '^M-F,','L-V,'
            }
            & net.exe user $name "/times:$fallback" 2>$null | Out-Null
        }
    }

    # Admin vs Supervisor vs Standard
    if ($u.AdminLevel -eq "Full") {
        Write-LogSec "Privilegio TOTAL: Asignando Administradores a '$name'..."
        Invoke-Step "Add-LocalGroupMember -Group Administradores -Member '$name'" {
            $adminGrp = Get-LocalGroup -SID $AdminGroupSid -ErrorAction SilentlyContinue
            if ($adminGrp) { Add-LocalGroupMember -Group $adminGrp.Name -Member $name -ErrorAction SilentlyContinue }
        }
    } elseif ($u.AdminLevel -eq "Supervisor") {
        Write-LogSec "Privilegio SUPERVISOR: Asignando monitoreo y eventos a '$name'..."
        Invoke-Step "Asignar supervision a '$name'" {
            foreach ($sid in @($EventLogSid, $PerfLogSid, $PrintOpSid)) {
                $builtinGrp = Get-LocalGroup -SID $sid -ErrorAction SilentlyContinue
                if ($builtinGrp) { Add-LocalGroupMember -Group $builtinGrp.Name -Member $name -ErrorAction SilentlyContinue }
            }
        }
    } else {
        Invoke-Step "Remover privilegios administrativos a '$name'" {
            $adminGrp = Get-LocalGroup -SID $AdminGroupSid -ErrorAction SilentlyContinue
            if ($adminGrp) { Remove-LocalGroupMember -Group $adminGrp.Name -Member $name -ErrorAction SilentlyContinue }
        }
    }
}

Write-LogStep "Fase 3/4: Politica de bloqueo desde .env (intentos=$LockoutAttempts, duracion=${LockoutMinutes}m)..."
Invoke-Step "net.exe accounts /lockoutthreshold:$LockoutAttempts /lockoutduration:$LockoutMinutes /lockoutwindow:$LockoutMinutes" {
    & net.exe accounts "/lockoutthreshold:$LockoutAttempts" "/lockoutduration:$LockoutMinutes" "/lockoutwindow:$LockoutMinutes" | Out-Null
}

Write-LogStep "Fase 4/4: Resumen y estado final..."
Write-LogSuccess "Aprovisionamiento y endurecimiento completado con exito."
