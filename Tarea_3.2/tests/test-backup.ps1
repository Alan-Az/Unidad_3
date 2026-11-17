$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\backup.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ("tarea32-ps-" + [guid]::NewGuid().ToString('N'))
$source = Join-Path $root 'source'
$destination = Join-Path $root 'backups'
$secondary = Join-Path $root 'secondary'
$restore = Join-Path $root 'restore'
$state = Join-Path $root 'state.json'
try {
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    New-Item -ItemType Directory -Path $secondary -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'keep.txt') -Value 'version one' -NoNewline
    Set-Content -LiteralPath (Join-Path $source 'remove.txt') -Value 'must disappear' -NoNewline

    $rejectRoot = Join-Path $root 'rejections'
    $rejectSource = Join-Path $rejectRoot 'source'
    New-Item -ItemType Directory -Path $rejectSource -Force | Out-Null
    function Assert-RejectedSecondary {
        param([string]$Name, [string]$Source, [string]$Destination, [string]$Secondary, [bool]$DestinationPreexists)
        $rejectedState = Join-Path $rejectRoot ($Name + '.state')
        $rejected = $false
        try {
            & $scriptPath -SourcePath $Source -DestinationPath $Destination -StatePath $rejectedState -Mode Full -SecondaryPath $Secondary | Out-Null
        } catch { $rejected = $true }
        if (-not $rejected) { throw "Secondary destination case was accepted: $Name" }
        if (Test-Path -LiteralPath $rejectedState) { throw "Rejected case created state: $Name" }
        if (Test-Path -LiteralPath (Join-Path $Destination 'backup.log')) { throw "Rejected case created a log: $Name" }
        if (Test-Path -LiteralPath (Join-Path $Destination '.backup.lock')) { throw "Rejected case created a lock: $Name" }
        if (Test-Path -LiteralPath (Join-Path $Destination '.backup-state.json')) { throw "Rejected case created default state: $Name" }
        $archives = Get-ChildItem -LiteralPath $Destination -Filter 'unidad3_*' -File -ErrorAction SilentlyContinue
        if ($archives) { throw "Rejected case created an archive: $Name" }
        if (-not $DestinationPreexists -and (Test-Path -LiteralPath $Destination)) { throw "Rejected case created the primary destination: $Name" }
        "PASS: secondary destination $Name rejected without backup output"
    }
    Assert-RejectedSecondary 'equal-source' $rejectSource (Join-Path $rejectRoot 'dest-equal-source') $rejectSource $false
    $insideSource = Join-Path $rejectSource 'secondary'
    New-Item -ItemType Directory -Path $insideSource -Force | Out-Null
    Assert-RejectedSecondary 'inside-source' $rejectSource (Join-Path $rejectRoot 'dest-inside-source') $insideSource $false
    $equalPrimary = Join-Path $rejectRoot 'dest-equal-primary'
    New-Item -ItemType Directory -Path $equalPrimary -Force | Out-Null
    Assert-RejectedSecondary 'equal-primary' $rejectSource $equalPrimary $equalPrimary $true
    $insidePrimary = Join-Path $rejectRoot 'dest-inside-primary'
    $insidePrimarySecondary = Join-Path $insidePrimary 'secondary'
    New-Item -ItemType Directory -Path $insidePrimarySecondary -Force | Out-Null
    Assert-RejectedSecondary 'inside-primary' $rejectSource $insidePrimary $insidePrimarySecondary $true
    $nested = Join-Path $source 'nested-backups'
    $nestedRejected = $false
    try { & $scriptPath -SourcePath $source -DestinationPath $nested } catch { $nestedRejected = $true }
    if (-not $nestedRejected -or (Test-Path -LiteralPath $nested)) { throw 'Nested backup destination was not rejected before writing.' }
    & $scriptPath -SourcePath $source -DestinationPath $destination -StatePath $state -Mode Full -SecondaryPath $secondary
    $full = Get-ChildItem -LiteralPath $destination -Filter '*_full_*.zip' | Select-Object -First 1
    if (-not $full) { throw 'Full archive was not created.' }
    if (-not (Test-Path -LiteralPath ($full.FullName + '.sha256'))) { throw 'Full checksum was not created.' }
    if (-not (Test-Path -LiteralPath (Join-Path $secondary $full.Name))) { throw 'Secondary archive copy was not created.' }
    $secondaryArchive = Join-Path $secondary $full.Name
    $expectedSecondaryHash = (Get-Content -LiteralPath ($full.FullName + '.sha256') -Encoding UTF8 -TotalCount 1).Split(' ')[0]
    $copiedSecondaryHash = (Get-Content -LiteralPath ($secondaryArchive + '.sha256') -Encoding UTF8 -TotalCount 1).Split(' ')[0]
    $actualSecondaryHash = (Get-FileHash -LiteralPath $secondaryArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expectedSecondaryHash -ne $actualSecondaryHash -or $copiedSecondaryHash -ne $actualSecondaryHash) { throw 'Secondary archive checksum does not match.' }
    if (-not (Test-Path -LiteralPath (Join-Path $secondary ($full.Name + '.sha256')))) { throw 'Secondary checksum copy was not created.' }
    $corrupt = Join-Path $root 'corrupt.zip'
    Copy-Item -LiteralPath $full.FullName -Destination $corrupt
    Copy-Item -LiteralPath ($full.FullName + '.sha256') -Destination ($corrupt + '.sha256')
    $bytes = [IO.File]::ReadAllBytes($corrupt)
    $bytes[0] = $bytes[0] -bxor 1
    [IO.File]::WriteAllBytes($corrupt, $bytes)
    $badTarget = Join-Path $root 'bad-restore'
    $corruptRejected = $false
    try { & $scriptPath -RestoreArchive $corrupt -TargetPath $badTarget -Force } catch { $corruptRejected = $true }
    if (-not $corruptRejected -or (Test-Path -LiteralPath $badTarget)) { throw 'Corrupt archive was accepted or created a restore target.' }

    Set-Content -LiteralPath (Join-Path $source 'keep.txt') -Value 'version two' -NoNewline
    Remove-Item -LiteralPath (Join-Path $source 'remove.txt')
    Set-Content -LiteralPath (Join-Path $source 'new.txt') -Value 'new file' -NoNewline
    & $scriptPath -SourcePath $source -DestinationPath $destination -StatePath $state -Mode Incremental
    $incremental = Get-ChildItem -LiteralPath $destination -Filter '*_incremental_*.zip' | Select-Object -First 1
    if (-not $incremental) { throw 'Incremental archive was not created.' }

    & $scriptPath -RestoreArchive $full.FullName -TargetPath $restore -Force
    & $scriptPath -RestoreArchive $incremental.FullName -TargetPath $restore -Force
    if ((Get-Content -LiteralPath (Join-Path $restore 'keep.txt') -Raw) -ne 'version two') { throw 'Incremental update did not restore.' }
    if (-not (Test-Path -LiteralPath (Join-Path $restore 'new.txt'))) { throw 'New file was not restored.' }
    if (Test-Path -LiteralPath (Join-Path $restore 'remove.txt')) { throw 'Deleted file remained after incremental restore.' }
    'PASS: full, incremental, checksum, and restore assertions'
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}