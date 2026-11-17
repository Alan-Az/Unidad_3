#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$UserHome = 'D:\Datos\Usuarios\alumno',
    [string]$GroupFolder = 'D:\Datos\Grupos\Sistemas',
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$paths = @(
    [pscustomobject]@{ Path = $UserHome; Size = 10GB; Description = 'Cuota de laboratorio por carpeta de inicio' },
    [pscustomobject]@{ Path = $GroupFolder; Size = 45GB; Description = 'Cuota de laboratorio por carpeta de departamento' }
)

if (-not $Apply) {
    'Vista previa solamente. Revise las rutas y vuelva a ejecutar con -Apply en un servidor de laboratorio.'
    $paths | Format-Table Path, Size, Description
    return
}
if (-not (Get-Command New-FsrmQuota -ErrorAction SilentlyContinue)) {
    throw 'FSRM no está instalado. No se aplicó ningún cambio.'
}
foreach ($item in $paths) {
    if (-not (Test-Path -LiteralPath $item.Path -PathType Container)) {
        throw "La carpeta debe existir antes de crear la cuota: $($item.Path)"
    }
    $existing = Get-FsrmQuota -Path $item.Path -ErrorAction SilentlyContinue
    if ($existing) { throw "Ya existe una cuota; revísela manualmente: $($item.Path)" }
}
foreach ($item in $paths) {
    if ($PSCmdlet.ShouldProcess($item.Path, "Crear cuota dura de $($item.Size)")) {
        New-FsrmQuota -Path $item.Path -Size $item.Size -Description $item.Description | Out-Null
    }
}
