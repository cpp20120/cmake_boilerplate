[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('build', 'test', 'dev', 'shell', 'run', 'clean')]
    [string]$Action,
    [string]$Image = 'my-project',
    [string]$Preset = 'app-release',
    [string]$Docker,
    [string]$BaseImage,
    [string]$Shell = 'bash',
    [switch]$Pull,
    [switch]$NoCache,
    [switch]$NoBuild,
    [string[]]$AppArgs = @(),
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
# Handle native exit codes explicitly, including cleanup of all image tags.
$PSNativeCommandUseErrorActionPreference = $false
if ($Help -or -not $Action) {
    Write-Output 'Usage: ./tools/container.ps1 build|test|dev|shell|run|clean [-Image NAME] [-Preset NAME]'
    Write-Output '       [-Docker PATH] [-BaseImage NAME] [-Pull] [-NoCache] [-NoBuild] [-Shell COMMAND] [-AppArgs ARRAY]'
    exit 0
}
if ($AppArgs.Count -gt 0 -and $Action -ne 'run') {
    throw 'Application arguments require the run action'
}
$root = Split-Path -Parent $PSScriptRoot
if (-not $Docker) {
    foreach ($candidate in @('docker', 'podman')) {
        $command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { $Docker = $command.Source; break }
    }
}
if (-not $Docker) { throw 'Docker or Podman is required' }
function Invoke-Engine([string[]]$Arguments) {
    & $Docker @Arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
function Build-Image([string]$Target, [string]$Tag) {
    $arguments = @('build', '--target', $Target, '--build-arg', "CMAKE_PRESET=$Preset")
    if ($BaseImage) { $arguments += @('--build-arg', "DEBIAN_IMAGE=$BaseImage") }
    if ($Pull) { $arguments += '--pull' }
    if ($NoCache) { $arguments += '--no-cache' }
    Invoke-Engine ($arguments + @('-t', $Tag, $root))
}
Push-Location $root
try {
    switch ($Action) {
        build { Build-Image runtime $Image }
        test { Build-Image test "${Image}:test" }
        dev { Build-Image dev "${Image}:dev" }
        shell {
            if (-not $NoBuild) { Build-Image dev "${Image}:dev" }
            Invoke-Engine @('run', '--rm', '-it', '-v', "${root}:/workspace", '-w', '/workspace', "${Image}:dev", $Shell)
        }
        run {
            if (-not $NoBuild) { Build-Image runtime $Image }
            Invoke-Engine (@('run', '--rm', $Image) + $AppArgs)
        }
        clean {
            $result = 0
            foreach ($tag in @($Image, "${Image}:dev", "${Image}:test")) {
                & $Docker image rm -f $tag
                if ($LASTEXITCODE -ne 0) { $result = $LASTEXITCODE }
            }
            exit $result
        }
    }
} finally {
    Pop-Location
}
exit 0
