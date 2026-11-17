#Requires -Version 5.1
<#
.SYNOPSIS
Crea respaldos completos o incrementales y restaura archivos a una carpeta elegida.
.DESCRIPTION
Los archivos y el estado se guardan en el destino indicado. El script no instala tareas,
no monta volúmenes y no envía datos por red. Un destino secundario debe estar montado.
Para restaurar una cadena, aplique primero el archivo completo y luego cada incremental.
#>
[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$DestinationPath,
    [ValidateSet('Full', 'Incremental')][string]$Mode = 'Full',
    [string]$StatePath,
    [string]$SecondaryPath,
    [string]$RestoreArchive,
    [string]$TargetPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Write-BackupLog {
    param([string]$Path, [string]$Message)
    $line = '[{0}] {1}' -f [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'), $Message
    Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
    Write-Output $line
}

function Get-SafeChildPath {
    param([string]$Root, [string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Ruta relativa insegura: $RelativePath"
    }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
    if (-not $candidate.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "La ruta sale del destino permitido: $RelativePath"
    }
    return $candidate
}

function Get-Inventory {
    param([string]$Root)
    $inventory = @{}
    Get-ChildItem -LiteralPath $Root -File -Recurse -Force | ForEach-Object {
        $relative = $_.FullName.Substring($Root.TrimEnd('\', '/').Length).TrimStart('\', '/').Replace('\', '/')
        $inventory[$relative] = [ordered]@{
            path = $relative
            length = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
    return $inventory
}

function Restore-Archive {
    param([string]$Archive, [string]$Target, [bool]$AllowOverwrite)
    if (-not $AllowOverwrite) { throw "La restauración requiere -Force para confirmar el destino elegido." }
    if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) { throw "No existe el archivo: $Archive" }
    $checksumPath = "$Archive.sha256"
    if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) { throw 'Falta el archivo de verificación SHA-256.' }
    $expectedHash = (Get-Content -LiteralPath $checksumPath -Encoding UTF8 -TotalCount 1).Split(' ')[0]
    $actualHash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash
    if ($expectedHash -ne $actualHash) { throw 'La suma SHA-256 no coincide; no se extrajo nada.' }

    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    $targetFull = [IO.Path]::GetFullPath($Target)
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $manifestEntry = $zip.Entries | Where-Object FullName -EQ '.backup-manifest.json' | Select-Object -First 1
        if (-not $manifestEntry) { throw 'No se encontró el manifiesto del respaldo.' }
        $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8)
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }

        $restoreEntries = @()
        $seenPaths = @{}
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -eq '.backup-manifest.json') { continue }
            if ($seenPaths.ContainsKey($entry.FullName)) { throw "Ruta duplicada en el archivo: $($entry.FullName)" }
            $seenPaths[$entry.FullName] = $true
            $outputPath = Get-SafeChildPath -Root $targetFull -RelativePath $entry.FullName
            if (-not $entry.FullName.EndsWith('/') -and (Test-Path -LiteralPath $outputPath) -and -not $AllowOverwrite) {
                throw "El archivo ya existe; use -Force para permitir la escritura: $($entry.FullName)"
            }
            $restoreEntries += [pscustomobject]@{ Entry = $entry; Path = $outputPath }
        }
        $deletePaths = @()
        foreach ($relative in $manifest.deletedFiles) {
            $deletedPath = Get-SafeChildPath -Root $targetFull -RelativePath $relative
            if ((Test-Path -LiteralPath $deletedPath) -and -not $AllowOverwrite) {
                throw "El incremental debe borrar un archivo existente; use -Force: $relative"
            }
            $deletePaths += $deletedPath
        }

        foreach ($item in $restoreEntries) {
            $entry = $item.Entry
            $outputPath = $item.Path
            if ($entry.FullName.EndsWith('/')) {
                New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
                continue
            }
            $parent = Split-Path -Parent $outputPath
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            $inputStream = $entry.Open()
            try {
                $outputStream = [IO.File]::Open($outputPath, [IO.FileMode]::Create, [IO.FileAccess]::Write)
                try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
        }

        if ($manifest.mode -eq 'Incremental') {
            foreach ($deletedPath in $deletePaths) {
                if (Test-Path -LiteralPath $deletedPath -PathType Leaf) {
                    Remove-Item -LiteralPath $deletedPath -Force
                }
            }
        }        Write-BackupLog -Path (Join-Path (Split-Path -Parent $Archive) 'restore.log') -Message "Restauración $($manifest.mode) aplicada: $(Split-Path -Leaf $Archive)"
    } finally { $zip.Dispose() }
}

if ($RestoreArchive) {
    if (-not $TargetPath) { throw 'Debe indicar -TargetPath al restaurar.' }
    Restore-Archive -Archive ([IO.Path]::GetFullPath($RestoreArchive)) -Target ([IO.Path]::GetFullPath($TargetPath)) -AllowOverwrite:$Force.IsPresent
    return
}
if (-not $SourcePath -or -not $DestinationPath) {
    throw 'Indique -SourcePath y -DestinationPath, o use -RestoreArchive y -TargetPath.'
}
$sourceRoot = (Resolve-Path -LiteralPath $SourcePath).Path.TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw 'El origen debe ser una carpeta existente.' }
$destinationCandidate = [IO.Path]::GetFullPath($DestinationPath).TrimEnd('\', '/')
if (Test-Path -LiteralPath $destinationCandidate -PathType Container) {
    $destinationCandidate = (Resolve-Path -LiteralPath $destinationCandidate).Path.TrimEnd('\', '/')
}
if ($destinationCandidate -eq $sourceRoot) { throw 'El origen y el destino deben ser distintos.' }
if ($destinationCandidate.StartsWith($sourceRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'El destino no puede estar dentro del origen.'
}
if ($SecondaryPath) {
    if (-not (Test-Path -LiteralPath $SecondaryPath -PathType Container)) {
        throw 'El destino secundario debe existir y estar montado previamente.'
    }
    $secondaryRoot = (Resolve-Path -LiteralPath $SecondaryPath).Path.TrimEnd('\', '/')
    if ($secondaryRoot -eq $sourceRoot) { throw 'El destino secundario no puede ser el origen.' }
    if ($secondaryRoot.StartsWith($sourceRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'El destino secundario no puede estar dentro del origen.'
    }
    if ($secondaryRoot -eq $destinationCandidate) { throw 'El destino secundario ya es el destino principal.' }
    if ($secondaryRoot.StartsWith($destinationCandidate.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'El destino secundario no puede estar dentro del destino principal.'
    }
}
$destinationRoot = $destinationCandidate
if (-not (Test-Path -LiteralPath $destinationRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
}
$destinationRoot = [IO.Path]::GetFullPath($destinationRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $StatePath) { $StatePath = Join-Path $destinationRoot '.backup-state.json' }
$stateFull = [IO.Path]::GetFullPath($StatePath)
if ($stateFull -eq $sourceRoot -or $stateFull.StartsWith($sourceRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'El estado no puede guardarse dentro del origen.'
}
$StatePath = $stateFull
$stateParent = Split-Path -Parent ([IO.Path]::GetFullPath($StatePath))
New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
New-Item -ItemType Directory -Path $stateParent -Force | Out-Null
$logPath = Join-Path $destinationRoot 'backup.log'
$lockPath = Join-Path $destinationRoot '.backup.lock'
try { New-Item -ItemType Directory -Path $lockPath -ErrorAction Stop | Out-Null }
catch { throw 'Ya existe un proceso de respaldo activo.' }

$stage = Join-Path ([IO.Path]::GetTempPath()) ('unidad3-backup-' + [guid]::NewGuid().ToString('N'))
$tempArchive = $null
try {
    $archiveMode = $Mode
    $previous = @{}
    if ($Mode -eq 'Incremental') {
        if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
            $archiveMode = 'Full'
            Write-BackupLog -Path $logPath -Message 'No existe estado anterior; la primera ejecución incremental se guardará como completa.'
        } else {
            $oldState = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($file in $oldState.files) { $previous[$file.path] = $file }
        }
    }
    $current = Get-Inventory -Root $sourceRoot
    $changed = @()
    foreach ($key in $current.Keys) {
        if (-not $previous.ContainsKey($key) -or $current[$key].sha256 -ne $previous[$key].sha256) {
            $changed += $key
        }
    }
    $deleted = @($previous.Keys | Where-Object { -not $current.ContainsKey($_) })
    New-Item -ItemType Directory -Path $stage -Force | Out-Null

    if ($archiveMode -eq 'Full') {
        Get-ChildItem -LiteralPath $sourceRoot -Directory -Recurse -Force | ForEach-Object {
            $relativeDir = $_.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
            New-Item -ItemType Directory -Path (Join-Path $stage $relativeDir) -Force | Out-Null
        }
        $changed = @($current.Keys)
    }
    foreach ($relative in $changed) {
        $inputPath = Get-SafeChildPath -Root $sourceRoot -RelativePath $relative
        $outputPath = Get-SafeChildPath -Root $stage -RelativePath $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
        Copy-Item -LiteralPath $inputPath -Destination $outputPath
    }

    $manifest = [ordered]@{
        schemaVersion = 1
        mode = $archiveMode
        createdUtc = [DateTime]::UtcNow.ToString('o')
        source = $sourceRoot
        changedFiles = @($changed | Sort-Object)
        deletedFiles = @($deleted | Sort-Object)
    }
    $manifestPath = Join-Path $stage '.backup-manifest.json'
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $archiveName = 'unidad3_{0}_{1}_{2}.zip' -f $stamp, $archiveMode.ToLowerInvariant(), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $archivePath = Join-Path $destinationRoot $archiveName
    $tempArchive = "$archivePath.part"
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $tempArchive, [IO.Compression.CompressionLevel]::Optimal, $false)
    $hash = (Get-FileHash -LiteralPath $tempArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    Move-Item -LiteralPath $tempArchive -Destination $archivePath
    $tempArchive = $null
    $checksumPath = "$archivePath.sha256"
    $checksumTemp = "$checksumPath.part"
    [IO.File]::WriteAllText($checksumTemp, "$hash  $archiveName" + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $checksumTemp -Destination $checksumPath
    $newState = [ordered]@{
        schemaVersion = 1
        source = $sourceRoot
        lastArchive = $archiveName
        files = @($current.Values | Sort-Object path)
    }
    $stateTemp = "$StatePath.tmp"
    [IO.File]::WriteAllText($stateTemp, ($newState | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $stateTemp -Destination $StatePath -Force
    Write-BackupLog -Path $logPath -Message "Respaldo $archiveMode creado y verificado: $archiveName"

    if ($SecondaryPath) {
        try {
            Copy-Item -LiteralPath $archivePath -Destination $SecondaryPath
            Copy-Item -LiteralPath $checksumPath -Destination $SecondaryPath
            $secondaryArchive = Join-Path $SecondaryPath $archiveName
            $secondaryChecksum = "$secondaryArchive.sha256"
            $expectedHash = (Get-Content -LiteralPath $checksumPath -Encoding UTF8 -TotalCount 1).Split(' ')[0]
            $copiedHash = (Get-Content -LiteralPath $secondaryChecksum -Encoding UTF8 -TotalCount 1).Split(' ')[0]
            $actualHash = (Get-FileHash -LiteralPath $secondaryArchive -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($expectedHash -ne $actualHash -or $copiedHash -ne $actualHash) {
                throw 'La suma SHA-256 de la copia secundaria no coincide.'
            }
            Write-BackupLog -Path $logPath -Message "Copia secundaria transferida y verificada: $SecondaryPath"
        } catch {
            Write-BackupLog -Path $logPath -Message 'ERROR: el respaldo local existe, pero falló o no se verificó la copia secundaria.'
            throw
        }
    }
} finally {
    if ($tempArchive -and (Test-Path -LiteralPath $tempArchive)) { Remove-Item -LiteralPath $tempArchive -Force }
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force }
}
