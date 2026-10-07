# Native Windows PowerShell 5.1+ / PowerShell 7. No Python/pip/venv bootstrap.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$mode = ''
$toolsDir = Join-Path $PSScriptRoot 'out/host-tools'
$userDirectory = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$vcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { Join-Path $userDirectory 'vcpkg' }
$setupArgs = @($args)
for ($i = 0; $i -lt $setupArgs.Count; $i++) {
    $argument = $setupArgs[$i]
    switch ($argument) {
        { $_ -in '--install', '--check', '--dry-run', '--check-harness' } {
            if ($mode) { throw 'Choose exactly one mode.' }
            $mode = $argument
        }
        { $_ -in '--tools-dir', '--vcpkg-root' } {
            if ($i + 1 -ge $setupArgs.Count -or -not $setupArgs[$i + 1] -or $setupArgs[$i + 1] -like '--*') {
                throw "Missing value for $argument"
            }
            $i++
            if ($argument -eq '--tools-dir') { $toolsDir = $setupArgs[$i] } else { $vcpkgRoot = $setupArgs[$i] }
        }
        { $_ -in '--help', '-h' } {
            Write-Host 'Usage: .\setup-host.ps1 --install|--check|--dry-run|--check-harness [--tools-dir PATH] [--vcpkg-root PATH]'
            Write-Host 'Python is checked only by --check-harness and is never installed by setup.'
            exit 0
        }
        default { throw "Unknown argument: $argument" }
    }
}
if (-not $mode) { throw 'Choose --install, --check, --dry-run or --check-harness. See --help.' }
if ($mode -eq '--check-harness') {
    $pythonCommand = Get-Command python3, python -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notlike '*\WindowsApps\*' } | Select-Object -First 1
    if ($pythonCommand) {
        & $pythonCommand.Source --version
        if ($LASTEXITCODE -ne 0) { throw 'Python check failed.' }
    } elseif (Get-Command py -CommandType Application -ErrorAction SilentlyContinue) {
        & py -3 --version
        if ($LASTEXITCODE -ne 0) { throw 'Python 3 is not installed for the optional harness.' }
    } else { throw 'Optional harness needs Python 3. Install it separately; normal setup/build does not require it.' }
    exit 0
}
$isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
if (-not $isWindowsHost -and $mode -ne '--dry-run') { throw 'Use setup-host.sh on Linux/macOS.' }
$toolsDir = [IO.Path]::GetFullPath($toolsDir)
$vcpkgRoot = [IO.Path]::GetFullPath($vcpkgRoot)
$overlayRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'vcpkg'))
if ($vcpkgRoot.TrimEnd('\', '/') -eq $overlayRoot.TrimEnd('\', '/')) { throw 'vcpkg/ holds overlays; choose ~/vcpkg or external/vcpkg.' }
if ((Test-Path $vcpkgRoot) -and -not (Test-Path (Join-Path $vcpkgRoot 'scripts/buildsystems/vcpkg.cmake'))) {
    throw "$vcpkgRoot exists but is not a vcpkg checkout."
}
$programFilesPath = if ($env:ProgramFiles) { $env:ProgramFiles } else { 'C:\Program Files' }
$installerBase = if (${env:ProgramFiles(x86)}) { ${env:ProgramFiles(x86)} } else { 'C:\Program Files (x86)' }
function Find-VisualStudio([switch]$AnyWorkload) {
    if (-not $isWindowsHost) { return '' }
    $finder = Join-Path $installerBase 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path $finder)) { return '' }
    $arguments = @('-latest', '-products', '*', '-property', 'installationPath')
    if (-not $AnyWorkload) { $arguments += @('-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64') }
    $result = & $finder @arguments
    if ($LASTEXITCODE -ne 0) { throw 'vswhere failed.' }
    return ($result -join '').Trim()
}
function Refresh-ToolPath {
    $paths = @($vcpkgRoot)
    if ($isWindowsHost) {
        foreach ($scope in 'Machine', 'User') {
            $storedPath = [Environment]::GetEnvironmentVariable('Path', $scope)
            if ($storedPath) { $paths += [Environment]::ExpandEnvironmentVariables($storedPath).Split(';') }
        }
        foreach ($relative in 'LLVM/bin', 'Git/cmd', 'CMake/bin', 'Cppcheck', 'doxygen/bin', 'NSIS') {
            $paths += Join-Path $programFilesPath $relative
        }
        $paths += @(Get-ChildItem (Join-Path $programFilesPath 'Graphviz*/bin') -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        $paths += @(Get-ChildItem "$env:SystemDrive/VulkanSDK/*/Bin" -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object { $_.FullName })
    }
    $script:activationPaths = @($paths | Where-Object { $_ } | Select-Object -Unique)
    $env:PATH = ($activationPaths -join [IO.Path]::PathSeparator) + [IO.Path]::PathSeparator + $env:PATH
}
function Invoke-Tool([string]$Executable, [string[]]$Arguments) {
    Write-Host ('+ ' + $Executable + ' ' + (($Arguments | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ' '))
    if ($mode -ne '--dry-run') {
        & $Executable @Arguments
        if ($LASTEXITCODE -ne 0) { throw "$Executable failed with exit code $LASTEXITCODE" }
    }
}
function Find-Tool([string]$Name) {
    if ($Name -eq 'clang++') { $names = @('clang++', 'clang-cl') }
    elseif ($Name -eq 'ld.lld') { $names = @('ld.lld', 'lld-link') }
    else { $names = @($Name) }
    return Get-Command $names -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
}
$tools = @(Get-Content (Join-Path $PSScriptRoot 'scripts/host-tools.txt') |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    ConvertFrom-Csv -Delimiter '|' -Header Label, Command, Apt, Dnf, Pacman, Brew, Winget)
Refresh-ToolPath
function Test-HostTools {
    $missing = $false
    foreach ($tool in $tools) {
        $found = Find-Tool $tool.Command
        if ($found) { Write-Host ('OK        {0,-20} {1}' -f $tool.Label, $found.Source) }
        elseif ($tool.Winget -eq '-') { Write-Host "N/A       $($tool.Label)" }
        else { Write-Host "MISSING   $($tool.Label)"; $missing = $true }
    }
    if (Find-Tool 'cmake') {
        $versionOutput = & cmake --version
        if ($LASTEXITCODE -ne 0 -or ($versionOutput -join ' ') -notmatch 'version (\d+\.\d+\.\d+)') {
            Write-Host 'MISSING   Cannot determine CMake version'; $missing = $true
        } elseif ([version]$Matches[1] -lt [version]'3.26.0') {
            Write-Host 'MISSING   CMake >= 3.26 (upgrade with winget)'; $missing = $true
        }
    }
    if (Test-Path (Join-Path $vcpkgRoot 'vcpkg.exe')) { Write-Host "OK        vcpkg: $vcpkgRoot" }
    else { Write-Host "MISSING   vcpkg: $vcpkgRoot"; $missing = $true }
    if (Find-VisualStudio) { Write-Host 'OK        Visual Studio C++ workload' }
    else { Write-Host 'MISSING   Visual Studio C++ workload'; $missing = $true }
    Write-Host 'SEPARATE  Python harness, cmake-format, gcovr, IWYU runner, Emscripten (not installed by setup)'
    foreach ($sdk in 'nvcc', 'dxc') {
        if (Find-Tool $sdk) { Write-Host "OK        $sdk" } else { Write-Host "SDK       $sdk (install separately if needed)" }
    }
    return (-not $missing)
}
if ($mode -eq '--check') { if (Test-HostTools) { exit 0 } else { exit 1 } }
if ($mode -eq '--install' -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'Install App Installer (winget) from Microsoft Store first.'
}
$packages = @($tools | Where-Object { $_.Winget -ne '-' -and -not (Find-Tool $_.Command) } |
    ForEach-Object { $_.Winget } | Select-Object -Unique)
$failed = $false
foreach ($package in $packages) {
    try {
        Invoke-Tool 'winget' @('install', '--id', $package, '--exact', '--source', 'winget', '--silent',
            '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    } catch { Write-Warning $_; $failed = $true }
}
if (-not (Find-VisualStudio)) {
    $existing = Find-VisualStudio -AnyWorkload
    if ($existing) {
        Invoke-Tool (Join-Path $installerBase 'Microsoft Visual Studio/Installer/setup.exe') @(
            'modify', '--installPath', $existing, '--passive', '--norestart',
            '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended')
    } else {
        Invoke-Tool 'winget' @('install', '--id', 'Microsoft.VisualStudio.2022.BuildTools', '--exact', '--source', 'winget',
            '--accept-source-agreements', '--accept-package-agreements', '--override',
            '--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
    }
}
Refresh-ToolPath
if (-not (Test-Path $vcpkgRoot)) { Invoke-Tool 'git' @('clone', 'https://github.com/microsoft/vcpkg.git', $vcpkgRoot) }
if (-not (Test-Path (Join-Path $vcpkgRoot 'vcpkg.exe'))) {
    Invoke-Tool (Join-Path $vcpkgRoot 'bootstrap-vcpkg.bat') @('-disableMetrics')
}
if ($mode -eq '--dry-run') { Write-Host "Would write $toolsDir/env.ps1 and audit installed tools."; exit 0 }
function Quote-Literal([string]$Value) { return "'" + $Value.Replace("'", "''") + "'" }
New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
$content = @('$env:VCPKG_ROOT = ' + (Quote-Literal $vcpkgRoot))
$content += '$env:PATH = ' + (Quote-Literal (($activationPaths -join ';') + ';')) + ' + $env:PATH'
$vs = Find-VisualStudio
if ($vs) {
    $content += '& ' + (Quote-Literal (Join-Path $vs 'Common7/Tools/Launch-VsDevShell.ps1')) + ' -Arch amd64 -HostArch amd64 -SkipAutomaticLocation'
}
$content | Set-Content -LiteralPath (Join-Path $toolsDir 'env.ps1') -Encoding UTF8
Write-Host "Activate: . '$toolsDir/env.ps1'"
if (-not (Test-HostTools)) { $failed = $true }
if ($failed) { throw 'Setup incomplete; review package errors and missing tools above.' }
