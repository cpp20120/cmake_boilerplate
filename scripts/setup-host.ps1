& (Join-Path (Split-Path $PSScriptRoot -Parent) 'setup-host.ps1') @args
exit $LASTEXITCODE
