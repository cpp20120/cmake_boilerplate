$excludedDirs = "build\", "vcpkg_installed\" 
$files = Get-ChildItem -Recurse -Include *.cpp, *.h, *.hpp | Where-Object {
    $filePath = $_.FullName
    -not ($excludedDirs | Where-Object { $filePath -match [regex]::Escape($_) })
}

$files | ForEach-Object -Parallel {
    clang-format -i $_.FullName
    Write-Host "Formatted: $($_.FullName)"
} -ThrottleLimit $(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors