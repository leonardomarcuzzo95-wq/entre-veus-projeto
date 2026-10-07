param(
    [Parameter(Mandatory=$true)][string]$Archive,
    [Parameter(Mandatory=$true)][string]$Destination,
    [switch]$StripRoot,
    [string[]]$Only = @()
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$destinationPath = [IO.Path]::GetFullPath($Destination)
$prefix = $destinationPath.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
$zip = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($Archive))
try {
    $entries = @()
    foreach ($entry in $zip.Entries) {
        $relative = $entry.FullName
        if ($StripRoot) { $relative = $relative -replace '^[^/]+/', '' }
        if (-not $relative -or $relative.EndsWith('/')) { continue }
        if ($Only.Count -gt 0 -and $relative -notin $Only) { continue }
        $target = [IO.Path]::GetFullPath((Join-Path $destinationPath $relative))
        if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe path: $relative" }
        if (($entry.ExternalAttributes -shr 16 -band 0xF000) -eq 0xA000) { throw "Symbolic link: $relative" }
        if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite: $target" }
        $entries += [pscustomobject]@{Entry=$entry;Target=$target}
    }
    foreach ($item in $entries) {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Target)) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($item.Entry,$item.Target,$false)
    }
    Write-Output "Extracted $($entries.Count) files into $destinationPath"
} finally { $zip.Dispose() }
