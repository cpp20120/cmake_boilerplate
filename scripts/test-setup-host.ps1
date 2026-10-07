# Native tests; no Pester/Python/package installs required.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$engine = (Get-Process -Id $PID).Path
$work = Join-Path ([IO.Path]::GetTempPath()) ('host-setup-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'setup-host.ps1'), [ref]$tokens, [ref]$errors) | Out-Null
    Assert ($errors.Count -eq 0) 'PowerShell parse failed'
    $output = & $engine -NoProfile -File (Join-Path $root 'setup-host.ps1') --dry-run --tools-dir (Join-Path $work "tools ' spaced") --vcpkg-root (Join-Path $work 'sdk spaced')
    Assert ($LASTEXITCODE -eq 0) 'dry-run failed'
    $plan = $output -join "`n"
    Assert ($plan -notmatch 'pip|venv|python') 'Unexpected Python install command'
    Assert ($plan -match 'bootstrap-vcpkg.bat') 'Missing bootstrap step'
    Assert (-not (Test-Path (Join-Path $work 'sdk spaced'))) 'dry-run created SDK directory'
    Assert (-not (Test-Path (Join-Path $work "tools ' spaced"))) 'dry-run wrote activation file'
    $ErrorActionPreference = 'Continue'
    & $engine -NoProfile -File (Join-Path $root 'setup-host.ps1') --dry-run --vcpkg-root (Join-Path $root 'vcpkg') *> $null
    $rejectedOverlay = $LASTEXITCODE -ne 0
    & $engine -NoProfile -File (Join-Path $root 'setup-host.ps1') --install --check *> $null
    $rejectedModes = $LASTEXITCODE -ne 0
    & $engine -NoProfile -File (Join-Path $root 'setup-host.ps1') --with-emscripten *> $null
    $rejectedOldSdk = $LASTEXITCODE -ne 0
    $ErrorActionPreference = 'Stop'
    Assert $rejectedOverlay 'Overlay directory must be protected'
    Assert $rejectedModes 'Conflicting modes must be rejected'
    Assert $rejectedOldSdk 'Removed Python-dependent SDK installation must be rejected'
    Write-Host 'Native PowerShell setup checks passed.'
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}
# Expected failures above leave LASTEXITCODE nonzero. GitHub Actions propagates
# it from its PowerShell wrapper even when every assertion passed.
exit 0
