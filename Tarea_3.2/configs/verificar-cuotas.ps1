#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Volume,
    [Parameter(Mandatory = $true)][string[]]$QuotaPaths
)

$ErrorActionPreference = 'Stop'
$drive = Get-Volume -DriveLetter ($Volume.TrimEnd(':').TrimEnd('\'))
if (-not $drive) { throw "No se encontró el volumen $Volume." }
"Volumen: $($drive.DriveLetter): $($drive.FileSystem)"
foreach ($path in $QuotaPaths) {
    $quota = Get-FsrmQuota -Path $path -ErrorAction SilentlyContinue
    if (-not $quota) {
        "SIN CUOTA: $path"
        continue
    }
    [pscustomobject]@{
        Path = $quota.Path
        UsageBytes = $quota.Usage
        LimitBytes = $quota.Size
        UsagePercent = if ($quota.Size -gt 0) { [math]::Round(100 * $quota.Usage / $quota.Size, 1) } else { 0 }
        SoftLimit = $quota.SoftLimit
    }
}
fsutil quota query $Volume