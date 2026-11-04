#Requires -Version 7.0
param(
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$MSBuild,
    [string]$WorkDirectory = (Join-Path $PSScriptRoot '.build'),
    [switch]$OfflineGradle
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked($Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable exited with code $LASTEXITCODE" }
}

function Get-Source($Repository, $Revision, $Destination) {
    $stamp = Join-Path $Destination '.source-revision'
    if (Test-Path -LiteralPath $stamp) {
        if ((Get-Content -LiteralPath $stamp -Raw).Trim() -ne $Revision) { throw "Wrong source revision in $Destination" }
        return
    }
    if (Test-Path -LiteralPath $Destination) { throw "Incomplete extraction at $Destination. Choose a new -WorkDirectory." }

    $archive = Join-Path $cache ($Revision + '.zip')
    if (-not (Test-Path -LiteralPath $archive)) {
        $partial = "$archive.download"
        Invoke-WebRequest "https://codeload.github.com/$Repository/zip/$Revision" -OutFile $partial
        [IO.File]::Move($partial, $archive)
    }
    New-Item -ItemType Directory -Path $Destination | Out-Null
    Invoke-Checked tar.exe @('-xf', $archive, '--strip-components', '1', '-C', $Destination)
    Set-Content -LiteralPath $stamp -Value $Revision
}

function Apply-Patches($Tree, $OriginalPatch, $LocalPatch) {
    $stamp = Join-Path $Tree '.patches-applied'
    $hashes = (Get-FileHash -LiteralPath $OriginalPatch,$LocalPatch).Hash -join ' '
    if (Test-Path -LiteralPath $stamp) {
        if ((Get-Content -LiteralPath $stamp -Raw).Trim() -ne $hashes) { throw "Patches changed. Choose a new -WorkDirectory." }
        return
    }
    foreach ($patch in @($OriginalPatch, $LocalPatch)) {
        Invoke-Checked git @('-C', $Tree, 'apply', '--check', $patch)
        Invoke-Checked git @('-C', $Tree, 'apply', $patch)
    }
    Set-Content -LiteralPath $stamp -Value $hashes
}

if (-not $JavaHome -or -not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe'))) {
    throw 'Supply the directory of a JDK 25 installation using -JavaHome or JAVA_HOME.'
}
if (-not $MSBuild) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $MSBuild = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'MSBuild\Current\Bin\MSBuild.exe' | Select-Object -First 1
    }
}
if (-not $MSBuild -or -not (Test-Path -LiteralPath $MSBuild)) { throw 'Supply MSBuild.exe from Visual Studio 2022 with -MSBuild.' }
$MSBuild = (Resolve-Path -LiteralPath $MSBuild).Path
$env:JAVA_HOME = (Resolve-Path -LiteralPath $JavaHome).Path

$work = (New-Item -ItemType Directory -Path $WorkDirectory -Force).FullName
$cache = (New-Item -ItemType Directory -Path (Join-Path $work 'downloads') -Force).FullName
$port = Join-Path $work 'port'
$sdk = Join-Path $port 'hlsdk'
$skycraft = Join-Path $port 'skycraft'
Get-Source 'SawyerTheNerd/Minecraft-X-HalfLife' 'fecf40cfbbdc22b30e7a4f31d8d221923d546532' $port
Get-Source 'ValveSoftware/halflife' 'b1b5cf5892918535619b2937bb927e46cb097ba1' $sdk
Get-Source 'chasmlol/SkyCraft' 'bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32' $skycraft
Apply-Patches $sdk (Join-Path $port 'patches/hlsdk.patch') (Join-Path $PSScriptRoot 'patches/hlsdk-fix.patch')
Apply-Patches $skycraft (Join-Path $port 'patches/skycraft.patch') (Join-Path $PSScriptRoot 'patches/skycraft-fix.patch')

$projects = Join-Path $sdk 'projects/vs2019'
Push-Location -LiteralPath $projects
try {
    foreach ($project in 'hldll', 'hl_cdll') {
        Invoke-Checked $MSBuild @("$project.vcxproj", '-p:Configuration=Release', '-p:Platform=Win32', '-p:PlatformToolset=v143', '-p:PostBuildEventUseInBuild=false', '-m', '-v:minimal', '-nologo')
    }
} finally {
    Pop-Location
}

$fabric = Join-Path $skycraft 'fabric'
$gradle = @('-p', $fabric, 'build')
if ($OfflineGradle) { $gradle += '--offline' }
Invoke-Checked (Join-Path $fabric 'gradlew.bat') $gradle

$dist = Join-Path $work 'dist'
foreach ($folder in 'mchl/dlls', 'mchl/cl_dlls', 'minecraft/mods') {
    New-Item -ItemType Directory -Path (Join-Path $dist $folder) -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $projects 'Release/hldll/hl.dll') -Destination (Join-Path $dist 'mchl/dlls/hl.dll')
Copy-Item -LiteralPath (Join-Path $projects 'Release/hl_cdll/client.dll') -Destination (Join-Path $dist 'mchl/cl_dlls/client.dll')
Copy-Item -LiteralPath (Join-Path $port 'mod/liblist.gam') -Destination (Join-Path $dist 'mchl/liblist.gam')
Copy-Item -LiteralPath (Join-Path $fabric 'build/libs/skycraft-0.1.2.jar') -Destination (Join-Path $dist 'minecraft/mods/skycraft-mchl-0.1.2.jar')
Write-Output "Build complete: $dist"
