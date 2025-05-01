#!/usr/bin/env pwsh

$excludeDirs = @(
    "build", "cmake-build-*", "out", "bin", 
    "install", "vcpkg_installed", "**/Debug", "**/Release"
)


if (Get-Command fd -ErrorAction SilentlyContinue) {
    $excludeArgs = $excludeDirs | ForEach-Object { "--exclude", $_ }
    $files = fd --type f -e cmake -e txt @excludeArgs | 
    Where-Object { $_ -match 'CMakeLists\.txt$|\.cmake$' } |
    ForEach-Object { Get-Item $_ }
}
else {
    $excludeRegex = ($excludeDirs | ForEach-Object { 
            [regex]::Escape($_) -replace '\\\*', '.*' 
        }) -join '|'
    
    $files = Get-ChildItem -File -Recurse -Include 'CMakeLists.txt', '*.cmake' |
    Where-Object { $_.FullName -replace '[\\/]', '/' -notmatch "[\\/]($excludeRegex)[\\/]" }
}

if ($files.Count -gt 0) {
    cmake-format --version > $null

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    $jobs = $files | ForEach-Object {
        $file = $_.FullName
        Start-ThreadJob -ScriptBlock {
            cmake-format --check=false -i $using:file 2>$null
        }
    }
    
    $completed = 0
    $total = $files.Count
    while ($jobs.State -contains 'Running') {
        $newCompleted = ($jobs | Where-Object State -eq 'Completed').Count
        if ($newCompleted -ne $completed) {
            $completed = $newCompleted
            Write-Progress -Activity "Formatting CMake files" `
                -Status "$completed/$total" `
                -PercentComplete ($completed / $total * 100)
        }
        Start-Sleep -Milliseconds 200
    }
    
    $jobs | Remove-Job -Force
    Write-Progress -Completed -Activity "Done"
    
    $sw.Stop()
    Write-Host "✅ Formatted $($files.Count) files in $($sw.Elapsed.TotalSeconds.ToString('0.0')) sec" -ForegroundColor Green
}
else {
    Write-Host "No CMake files found matching criteria" -ForegroundColor Yellow
}