# Offline regression for the user-facing PowerShell entry.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$engine = (Get-Process -Id $PID).Path
$work = Join-Path ([IO.Path]::GetTempPath()) ('boilerplate-entry-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
function Assert([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
try {
    $sources = @('setup.ps1', 'build.ps1', 'setup-host.ps1', 'scripts/entry-options.ps1')
    foreach ($source in $sources) {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $source), [ref]$tokens, [ref]$errors) | Out-Null
        Assert ($errors.Count -eq 0) "PowerShell parse failed: $source"
    }
    $dest = Join-Path $work 'demo path'
    $init = & $engine -NoProfile -File (Join-Path $root 'setup.ps1') -DryRun -Init DemoProject -Output $dest -Run -Package
    Assert ($LASTEXITCODE -eq 0) 'init dry-run failed'
    Assert (($init -join "`n") -match 'Would create DemoProject') 'missing init plan'
    Assert (-not (Test-Path $dest)) 'dry-run created destination'
    $build = & $engine -NoProfile -File (Join-Path $root 'build.ps1') -DryRun -Run -NoTests -Jobs 3
    Assert ($LASTEXITCODE -eq 0) 'build dry-run failed'
    Assert (($build -join "`n") -match 'RUN_APPLICATION=ON') 'run option not forwarded'
    Assert (($build -join "`n") -match 'RUN_TESTS=OFF') 'no-tests option not forwarded'
    Assert (($build -join "`n") -match 'JOBS=3') 'jobs not forwarded'
    $package = & $engine -NoProfile -File (Join-Path $root 'build.ps1') -DryRun -Package -PackageFormat ZIP
    Assert ($LASTEXITCODE -eq 0) 'package dry-run failed'
    Assert (($package -join "`n") -match 'PACKAGE_ARTIFACTS=ON') 'package option not forwarded'
    Assert (($package -join "`n") -match 'PACKAGE_FORMAT=ZIP') 'package format not forwarded'
    $arch = & $engine -NoProfile -File (Join-Path $root 'build.ps1') -DryRun -PackageFormat ARCH
    Assert ($LASTEXITCODE -eq 0) 'ARCH dry-run failed'
    Assert (($arch -join "`n") -match 'PACKAGE_FORMAT=ARCH') 'ARCH format not forwarded'
    Write-Host 'One-command PowerShell bootstrap checks passed.'
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}
exit 0
