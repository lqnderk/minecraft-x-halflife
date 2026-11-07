#Requires -Version 5.1
param(
    [switch]$Check,
    [switch]$Launch,
    [ValidateSet('Auto','Legacy','Official','Prism')][string]$Launcher='Auto',
    [string]$PrismPath,
    [string]$PrismDataPath
)
$ErrorActionPreference = 'Stop'
# Windows PowerShell can reconstruct PSModulePath from registry settings on startup.
$env:PSModulePath = [IO.Path]::Combine($PSHOME, 'Modules')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$installDir = Join-Path $env:LOCALAPPDATA 'Minecraft X Half-Life'
$toolsDir = Join-Path $installDir 'tools'
$fabric = 'fabric-loader-0.19.5-26.3'
$apiName = 'fabric-api-0.161.0+26.3.jar'
$officialId = 'Microsoft.4297127D64EC6_8wekyb3d8bbwe!Minecraft'

function Fetch($url, $path, $sha256) {
    Invoke-WebRequest -UseBasicParsing $url -OutFile "$path.download"
    if ($sha256 -and (Get-FileHash -LiteralPath "$path.download").Hash -ne $sha256) { throw "Bad checksum: $url" }
    Move-Item -LiteralPath "$path.download" -Destination $path -Force
}

function Extract-ToolArchive($archive, $destination) {
    [void][IO.Directory]::CreateDirectory($destination)
    $tar = [IO.Path]::Combine($env:SystemRoot, 'System32', 'tar.exe')
    & $tar -xf $archive -C $destination
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $archive (tar exited with $LASTEXITCODE)." }
}

function Find-Game {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath }
    if (-not $steam -or -not (Test-Path (Join-Path $steam 'steam.exe'))) { throw 'Install Steam and Half-Life (App 70), then retry.' }
    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $libraries += @([regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value.Replace('\\','\') })
    }
    foreach ($library in $libraries) {
        $apps = Join-Path $library 'steamapps'
        $manifest = Join-Path $apps 'appmanifest_70.acf'
        if (-not (Test-Path $manifest)) { continue }
        $folder = [regex]::Match((Get-Content $manifest -Raw), '"installdir"\s*"([^"]+)"').Groups[1].Value
        if (-not $folder) { continue }
        $game = Join-Path (Join-Path $apps 'common') $folder
        if ((Test-Path (Join-Path $game 'hl.exe')) -and (Test-Path (Join-Path $game 'valve\liblist.gam'))) {
            return @{Steam=(Join-Path $steam 'steam.exe'); Game=$game}
        }
    }
    throw 'Half-Life is missing. Install Half-Life from the Steam Library and run Install.cmd again.'
}

function Get-PrismProfile($exe) {
    if (-not $exe -or [IO.Path]::GetFileName($exe) -ine 'prismlauncher.exe' -or
        -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw 'Select an existing prismlauncher.exe.'
    }
    $exe = (Resolve-Path -LiteralPath $exe).Path
    $folder = Split-Path -LiteralPath $exe
    $root = Join-Path $env:APPDATA 'PrismLauncher'
    if ($PrismDataPath) {
        if (-not (Test-Path -LiteralPath $PrismDataPath -PathType Container)) { throw 'Prism data folder not found.' }
        $root = (Resolve-Path -LiteralPath $PrismDataPath).Path
    } elseif ((Test-Path (Join-Path $folder 'portable.txt')) -or
              (Test-Path (Join-Path $folder 'prismlauncher.cfg')) -or
              (Test-Path (Join-Path $folder 'instances') -PathType Container)) {
        $root = $folder
    }
    return @{Kind='Prism'; Exe=$exe; Root=$root}
}

function Select-PrismFile {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = 'Select Prism Launcher (prismlauncher.exe)'
        $dialog.Filter = 'Prism Launcher (prismlauncher.exe)|prismlauncher.exe'
        $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) { return $dialog.FileName }
    } finally {
        $dialog.Dispose()
    }
}

function Find-Launcher {
    if ($Launcher -in 'Auto','Prism') {
        if ($PrismPath) { return Get-PrismProfile $PrismPath }
        $activePrism = Get-Process prismlauncher -ErrorAction SilentlyContinue |
            ForEach-Object Path | Where-Object { $_ } | Select-Object -First 1
        if ($activePrism) { return Get-PrismProfile $activePrism }
    }
    $legacy = Join-Path $env:APPDATA '.tlauncher\legacy\Minecraft\LL.exe'
    $official = @((Join-Path ${env:ProgramFiles(x86)} 'Minecraft Launcher\MinecraftLauncher.exe'),
        (Join-Path $env:ProgramFiles 'Minecraft Launcher\MinecraftLauncher.exe')) |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $store = Test-Path (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe')
    if (-not $store -and $PSVersionTable.PSEdition -eq 'Desktop') {
        $store = Get-AppxPackage -Name 'Microsoft.4297127D64EC6_8wekyb3d8bbwe' -ErrorAction SilentlyContinue
    }
    $prism = @((Join-Path $env:LOCALAPPDATA 'Programs\PrismLauncher\prismlauncher.exe'),
        (Join-Path $env:ProgramFiles 'PrismLauncher\prismlauncher.exe'),
        (Get-Command prismlauncher.exe -ErrorAction SilentlyContinue).Source) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if ($Launcher -in 'Auto','Legacy' -and (Test-Path -LiteralPath $legacy)) {
        $root = Join-Path (Split-Path $legacy) 'game'
        $settings = Join-Path $env:APPDATA '.tlauncher\legacy.properties'
        if (Test-Path $settings) {
            $properties = Get-Content -LiteralPath $settings -Raw
            $configured = [regex]::Match($properties, '(?m)^minecraft\.gamedir=(.+)$').Groups[1].Value.Trim()
            if ($configured) { $root = $configured.Replace('\:',':').Replace('\\','\') }
            $separate = [regex]::Match($properties, '(?m)^minecraft\.gamedir\.separate=(.+)$').Groups[1].Value.Trim()
            if ($separate -and $separate -ne 'none') {
                throw 'Legacy uses per-version game folders. Select another launcher with -Launcher or use the manual install instructions.'
            }
        }
        return @{Kind='Legacy'; Exe=$legacy; Root=$root}
    }
    if ($Launcher -in 'Auto','Official' -and ($official -or $store)) {
        return @{Kind='Official'; Exe=$official; Root=(Join-Path $env:APPDATA '.minecraft')}
    }
    if ($Launcher -in 'Auto','Prism') {
        if ($prism) { return Get-PrismProfile $prism }
        if (-not $Check) {
            Write-Host 'Prism was not found automatically. Select prismlauncher.exe if you have it.'
            $selectedPrism = Select-PrismFile
            if ($selectedPrism) { return Get-PrismProfile $selectedPrism }
        }
    }
    throw 'Install and open a supported launcher (Legacy, official Minecraft Launcher, or Prism), then run Install.cmd again.'
}

function Find-MSBuild {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        & $vswhere -latest -products '*' -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.Windows11SDK.26100 -find 'MSBuild\Current\Bin\MSBuild.exe' |
            Select-Object -First 1
    }
}

function Prepare-Tools {
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        $git = Join-Path $toolsDir 'mingit\cmd\git.exe'
        if (-not (Test-Path $git)) {
            $release = Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest'
            $asset = $release.assets | Where-Object name -Match '^MinGit-[0-9.]+-64-bit\.zip$' | Select-Object -First 1
            if (-not $asset -or $asset.digest -notmatch '^sha256:([a-f0-9]{64})$') { throw 'MinGit download or checksum unavailable.' }
            $zip = Join-Path $toolsDir 'mingit.zip'
            Fetch $asset.browser_download_url $zip $Matches[1]
            Extract-ToolArchive $zip (Join-Path $toolsDir 'mingit')
            if (-not (Test-Path -LiteralPath $git -PathType Leaf)) { throw 'MinGit executable missing after extraction.' }
        }
        $env:Path = "$(Split-Path $git);$env:Path"
    }
    $javaRoot = Join-Path $toolsDir 'java'
    $jdk = @($env:JAVA_HOME) + @(Get-ChildItem $javaRoot -Directory -Filter 'jdk-25*' -ErrorAction SilentlyContinue | ForEach-Object FullName)
    $jdk = $jdk | Where-Object { $_ -and (Test-Path (Join-Path $_ 'bin\javac.exe')) -and
        (Test-Path (Join-Path $_ 'release')) -and (Select-String (Join-Path $_ 'release') -Pattern '^JAVA_VERSION="25[."]' -Quiet) } | Select-Object -First 1
    if (-not $jdk) {
        Write-Host 'Downloading JDK 25...'
        $asset = @(Invoke-RestMethod 'https://api.adoptium.net/v3/assets/latest/25/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse')[0].binary.package
        if ($asset.checksum -notmatch '^[a-f0-9]{64}$') { throw 'JDK checksum unavailable.' }
        $zip = Join-Path $toolsDir 'jdk25.zip'
        Fetch $asset.link $zip $asset.checksum
        Extract-ToolArchive $zip $javaRoot
        $jdk = (Get-ChildItem $javaRoot -Directory -Filter 'jdk-25*' |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\javac.exe') -PathType Leaf } |
            Select-Object -First 1).FullName
        if (-not $jdk) { throw 'JDK executable missing after extraction.' }
    }
    $msbuild = Find-MSBuild
    if (-not $msbuild) {
        Write-Host 'Installing Microsoft C++ Build Tools. Accept the Windows prompt.'
        $setup = Join-Path $toolsDir 'vs_BuildTools.exe'
        Fetch 'https://aka.ms/vs/17/release/vs_BuildTools.exe' $setup
        $signature = Get-AuthenticodeSignature -LiteralPath $setup
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
            throw 'The Microsoft Build Tools installer signature could not be verified.'
        }
        $setupArgs = '--wait --passive --norestart --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.26100'
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path $vswhere) {
            $installed = & $vswhere -latest -products Microsoft.VisualStudio.Product.BuildTools -version '[17.0,18.0)' -property installationPath |
                Select-Object -First 1
            if ($installed) { $setupArgs = ('modify --installPath "{0}" {1}' -f $installed,$setupArgs) }
        }
        $process = Start-Process -FilePath $setup -ArgumentList $setupArgs -Verb RunAs -Wait -PassThru
        if ($process.ExitCode -eq 3010) { throw 'Restart Windows and run Install.cmd again.' }
        if ($process.ExitCode -ne 0) { throw "Build Tools installation failed ($($process.ExitCode))." }
        $msbuild = Find-MSBuild
        if (-not $msbuild) { throw 'MSBuild was not found after installation.' }
    }
    return @{Java=$jdk; MSBuild=$msbuild}
}

function Read-Json($path) {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        return ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path)) -AsHashtable
    }
    Add-Type -AssemblyName System.Web.Extensions
    $json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $json.MaxJsonLength = 16777216
    return $json.DeserializeObject([IO.File]::ReadAllText($path))
}

function Write-Json($path, $value) {
    [IO.File]::WriteAllText("$path.mchl-tmp", ($value | ConvertTo-Json -Depth 90), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath "$path.mchl-tmp" -Destination $path -Force
}

function Prepare-Profile($client, $jar, $api, $jdk) {
    $version = $fabric
    $gameDir = $client.Root
    if ($client.Kind -eq 'Prism') {
        $instances = Join-Path $client.Root 'instances'
        $prismConfig = Join-Path $client.Root 'prismlauncher.cfg'
        if (Test-Path -LiteralPath $prismConfig) {
            $configured = [regex]::Match((Get-Content -LiteralPath $prismConfig -Raw), '(?m)^InstanceDir=([^\r\n]+)').Groups[1].Value.Trim('"')
            if ($configured) {
                if ([IO.Path]::IsPathRooted($configured)) { $instances = $configured }
                else { $instances = Join-Path $client.Root $configured }
            }
        }
        $instance = Join-Path $instances 'Minecraft-X-Half-Life'
        New-Item -ItemType Directory -Path $instance -Force | Out-Null
        $cfg = Join-Path $instance 'instance.cfg'
        if (-not (Test-Path $cfg)) {
            @('[General]','InstanceType=OneSix','name=Minecraft X Half-Life','OverrideJavaLocation=true',
                ('JavaPath=' + (Join-Path $jdk 'bin\javaw.exe').Replace('\','/')),
                'OverrideJavaArgs=true','JvmArgs=--enable-native-access=ALL-UNNAMED') | Set-Content -LiteralPath $cfg -Encoding UTF8
        }
        Write-Json (Join-Path $instance 'mmc-pack.json') @{formatVersion=1; components=@(
            @{uid='org.lwjgl3';version='3.4.3';dependencyOnly=$true}
            @{uid='net.minecraft';version='26.3';important=$true}
            @{uid='net.fabricmc.intermediary';version='26.3';dependencyOnly=$true}
            @{uid='net.fabricmc.fabric-loader';version='0.19.5'}
        )}
        $gameDir = Join-Path $instance '.minecraft'
        $version = 'Minecraft-X-Half-Life'
    } elseif ($client.Kind -eq 'Legacy' -and (Test-Path (Join-Path $client.Root 'versions\Fabric 26.3\Fabric 26.3.json'))) {
        $version = 'Fabric 26.3'
    } else {
        $dir = Join-Path $client.Root "versions\$fabric"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $metadata = Join-Path $dir "$fabric.json"
        if (-not (Test-Path $metadata)) {
            Fetch 'https://meta.fabricmc.net/v2/versions/loader/26.3/0.19.5/profile/json' $metadata
        }
        $profile = Read-Json $metadata
        if ($profile.id -ne $fabric -or $profile.inheritsFrom -ne '26.3') { throw 'Unexpected Fabric profile.' }
    }
    if ($client.Kind -eq 'Official') { $gameDir = Join-Path $installDir 'minecraft' }

    $mods = Join-Path $gameDir 'mods'
    New-Item -ItemType Directory -Path $mods -Force | Out-Null
    $existing = @(Get-ChildItem $mods -Filter 'skycraft-*.jar' -File)
    if ($existing.Count -gt 1) { throw "Several SkyCraft JARs found in $mods. Keep only one and retry." }
    if (Get-ChildItem $mods -Filter 'fabric-api-*.jar' -File | Where-Object Name -ne $apiName) {
        throw "A different Fabric API is already installed in $mods. Move it out or select another launcher."
    }
    $jarName = if ($existing.Count) { $existing[0].Name } else { Split-Path $jar -Leaf }
    if ($existing.Count) {
        Copy-Item -LiteralPath $existing[0].FullName -Destination (Join-Path $installDir 'previous-skycraft.jar.bak') -Force
    }
    Copy-Item -LiteralPath $jar -Destination (Join-Path $mods $jarName) -Force
    Copy-Item -LiteralPath $api -Destination (Join-Path $mods $apiName) -Force

    if ($client.Kind -eq 'Official') {
        $profilesFile = Join-Path $client.Root 'launcher_profiles.json'
        if (Test-Path (Join-Path $client.Root 'launcher_profiles_microsoft_store.json')) {
            $profilesFile = Join-Path $client.Root 'launcher_profiles_microsoft_store.json'
        }
        $profiles = if (Test-Path $profilesFile) { Read-Json $profilesFile } else { @{profiles=@{};version=3} }
        if ($null -eq $profiles.profiles) { $profiles.profiles = @{} }
        if (Test-Path $profilesFile) { Copy-Item -LiteralPath $profilesFile -Destination "$profilesFile.mchl-backup" -Force }
        $profiles.profiles['minecraft-x-halflife'] = @{
            name='Minecraft X Half-Life';type='custom';lastVersionId=$fabric;gameDir=$gameDir
            javaArgs='--enable-native-access=ALL-UNNAMED';lastUsed=[DateTime]::UtcNow.ToString('o')
        }
        Write-Json $profilesFile $profiles
        $version = 'Minecraft X Half-Life'
    }
    return $version
}

try {
    if ($Launch) {
        $saved = Read-Json (Join-Path $installDir 'launch.json')
        if (Get-Process hl -ErrorAction SilentlyContinue) { throw 'Close the running Half-Life before starting the crossover.' }
        Start-Process -FilePath $saved.Steam -ArgumentList '-applaunch 70 -game mchl -insecure -gl -windowed -novid -condebug +map t0a0'
        if ($saved.Kind -eq 'Prism') {
            $prismArgs = if ($saved.Root) { '--dir "{0}" --launch Minecraft-X-Half-Life' -f $saved.Root } else { '--launch Minecraft-X-Half-Life' }
            Start-Process -FilePath $saved.Exe -WorkingDirectory (Split-Path -LiteralPath $saved.Exe) -ArgumentList $prismArgs
        } elseif ($saved.Exe) {
            Start-Process -FilePath $saved.Exe
        } else {
            Start-Process explorer.exe "shell:AppsFolder\$officialId"
        }
        Write-Host "In $($saved.Kind), select $($saved.Version) and press Play if needed."
        exit 0
    }

    $game = Find-Game
    $client = Find-Launcher
    Write-Host "Half-Life: $($game.Game)"
    Write-Host "Minecraft launcher: $($client.Kind)"
    Write-Host "Launcher data: $($client.Root)"
    if ($Check) { exit 0 }
    if ($client.Kind -eq 'Prism' -and (Get-Process prismlauncher -ErrorAction SilentlyContinue)) {
        [void](Read-Host 'Prism Launcher was found. Close Minecraft and Prism, then press Enter to continue')
    }
    if (Get-Process hl,LL,Minecraft,MinecraftLauncher,prismlauncher,javaw -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -ne 'javaw' -or $_.MainWindowTitle -match 'Minecraft|Legacy|\u041b\u0435\u0433\u0430\u0441\u0438' }) {
        throw 'Close Half-Life, Minecraft, and your Minecraft launcher before installing.'
    }
    New-Item -ItemType Directory -Path $installDir,$toolsDir -Force | Out-Null
    $toolchain = Prepare-Tools
    $build = Join-Path $installDir 'build-0.2.0'
    Write-Host 'Building the crossover. First run can take several minutes.'
    & (Join-Path $PSScriptRoot 'Build.ps1') -JavaHome $toolchain.Java -MSBuild $toolchain.MSBuild -WorkDirectory $build
    $dist = Join-Path $build 'dist'
    $jar = Join-Path $dist 'minecraft\mods\skycraft-mchl-0.1.2.jar'
    $api = Join-Path $toolsDir $apiName
    if (-not (Test-Path $api)) {
        $apiUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-api/fabric-api/0.161.0+26.3/$apiName"
        $sha1 = (Invoke-WebRequest -UseBasicParsing "$apiUrl.sha1").Content
        if ($sha1 -is [byte[]]) { $sha1 = [Text.Encoding]::ASCII.GetString($sha1) }
        Fetch $apiUrl $api
        if ((Get-FileHash -LiteralPath $api -Algorithm SHA1).Hash -ne $sha1.Trim()) {
            Remove-Item -LiteralPath $api
            throw 'Fabric API checksum mismatch.'
        }
    }
    $deploy = Join-Path $installDir 'Deploy-Half-Life.ps1'
    $shell = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Deploy-Half-Life.ps1') -Destination $deploy -Force
    $source = Join-Path $dist 'mchl'
    & $shell -NoProfile -ExecutionPolicy Bypass -File $deploy -Source $source -Game $game.Game
    if ($LASTEXITCODE -eq 5) {
        $argsForCopy = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Source "{1}" -Game "{2}"' -f $deploy,$source,$game.Game
        $process = Start-Process $shell -ArgumentList $argsForCopy -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode) { throw "Half-Life installation failed ($($process.ExitCode))." }
    } elseif ($LASTEXITCODE) { throw "Half-Life installation failed ($LASTEXITCODE)." }
    $version = Prepare-Profile $client $jar $api $toolchain.Java
    $installedScript = Join-Path $installDir 'Install.ps1'
    Copy-Item -LiteralPath $PSCommandPath -Destination $installedScript -Force
    Write-Json (Join-Path $installDir 'launch.json') @{Steam=$game.Steam;Kind=$client.Kind;Exe=$client.Exe;Version=$version;Root=$client.Root}
    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'Minecraft X Half-Life.lnk'))
    $shortcut.TargetPath = $shell
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Launch' -f $installedScript
    $shortcut.WorkingDirectory = $installDir
    $shortcut.IconLocation = "$(Join-Path $game.Game 'hl.exe'),0"
    $shortcut.Save()
    Write-Host "Installed. Open Minecraft X Half-Life on your desktop. In $($client.Kind), select $version and press Play."
} catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    [Console]::Error.WriteLine($_.InvocationInfo.PositionMessage)
    if ($Launch) {
        [Console]::WriteLine('Press Enter to close')
        [void][Console]::ReadLine()
    }
    exit 1
}
