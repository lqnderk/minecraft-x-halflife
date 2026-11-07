#Requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$Source, [Parameter(Mandatory=$true)][string]$Game)
$ErrorActionPreference = 'Stop'
try {
    if (Get-Process hl -ErrorAction SilentlyContinue) { throw 'Close Half-Life before installing.' }
    if (-not (Test-Path (Join-Path $Game 'hl.exe') -PathType Leaf)) { throw 'Invalid Half-Life directory.' }
    $files = 'liblist.gam','dlls\hl.dll','cl_dlls\client.dll'
    foreach ($file in $files) {
        if (-not (Test-Path (Join-Path $Source $file) -PathType Leaf)) { throw "Missing build output $file" }
    }
    $target = Join-Path $Game 'mchl'
    $backup = Join-Path $Game ('mchl-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    foreach ($file in $files) {
        $destination = Join-Path $target $file
        if (Test-Path -LiteralPath $destination) {
            $saved = Join-Path $backup $file
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $destination -Destination $saved
        }
    }
    foreach ($file in $files) {
        $destination = Join-Path $target $file
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $Source $file) -Destination $destination -Force
    }
} catch [System.UnauthorizedAccessException] {
    exit 5
} catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    exit 1
}
