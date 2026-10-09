$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts/entry-options.ps1') -Root $PSScriptRoot -Entry 'setup.ps1' -Arguments $args
$mode = if ($dryRun) { '--dry-run' } else { '--install' }
& (Join-Path $PSScriptRoot 'setup-host.ps1') $mode --profile $profile --tools-dir $toolsDir --defer-vcpkg @hostExtra
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($initName) {
    if ($dryRun) {
        Write-Host "Would create $initName at $initOutput (requires empty output directory), then configure, build, test and optionally launch it."
        exit 0
    }
    . (Join-Path $toolsDir 'env.ps1')
    & cmake "-DNAME=$initName" "-DOUTPUT=$initOutput" -P (Join-Path $PSScriptRoot 'scripts/Init.cmake')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($setupOnly) { exit 0 }
    & (Join-Path $initOutput 'build.ps1') @buildArgs
    exit $LASTEXITCODE
}
if (-not $setupOnly) {
    & (Join-Path $PSScriptRoot 'build.ps1') @buildArgs
    exit $LASTEXITCODE
}
exit 0
