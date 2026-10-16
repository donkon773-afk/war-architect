param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\addons\NeroAI3"),
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\dist"),
    [string]$OutputPbo = "NeroWL.pbo",
    [string]$Prefix = "NeroWL",
    [switch]$Mission
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SourceDir)) {
    throw "Source directory does not exist: $SourceDir"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$targetPboPath = Join-Path $OutputDir $OutputPbo
$sourcePath = (Get-Item -LiteralPath $SourceDir).FullName.TrimEnd('\', '/')

# Collect all files recursively, sorted alphabetically by relative path
$files = Get-ChildItem -LiteralPath $sourcePath -Recurse -File | Sort-Object {
    $_.FullName.Substring($sourcePath.Length).TrimStart('\', '/')
}

Write-Host "Building PBO from '$sourcePath' ($($files.Count) files)..."

$memoryStream = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter($memoryStream)

# Mission PBOs have plain file headers, without addon Vers/prefix properties.
if (-not $Mission) {
# 1. Vers Header (addon PBO format)
$writer.Write([byte]0)
$writer.Write([int32]0x56657273) # "sreV"
$writer.Write([int32]0)
$writer.Write([int32]0)
$writer.Write([int32]0)
$writer.Write([int32]0)

# Properties: prefix\0<Prefix>\0\0
$prefixBytes = [System.Text.Encoding]::ASCII.GetBytes("prefix`0$Prefix`0`0")
$writer.Write($prefixBytes)
}

$fileInfos = @()
$epoch = [DateTime]::SpecifyKind([DateTime]::new(1970, 1, 1), [DateTimeKind]::Utc)

# 2. File Headers
foreach ($f in $files) {
    $relPath = $f.FullName.Substring($sourcePath.Length).TrimStart('\', '/').Replace('\', '/')
    $nameBytes = [System.Text.Encoding]::ASCII.GetBytes($relPath)
    $writer.Write($nameBytes)
    $writer.Write([byte]0)

    $fileData = [System.IO.File]::ReadAllBytes($f.FullName)
    $unixTime = [int32][Math]::Floor(($f.LastWriteTimeUtc - $epoch).TotalSeconds)

    $writer.Write([int32]0)              # packingMethod (uncompressed)
    $writer.Write([int32]$fileData.Length) # originalSize
    $writer.Write([int32]0)              # reserved
    $writer.Write([int32]$unixTime)      # timestamp
    $writer.Write([int32]$fileData.Length) # dataSize

    $fileInfos += [PSCustomObject]@{
        Name = $relPath
        Bytes = $fileData
    }
}

# 3. End of file headers: 21 zero bytes
$writer.Write([byte]0)
$writer.Write((New-Object byte[] 20))

# 4. File Data
foreach ($info in $fileInfos) {
    $writer.Write($info.Bytes)
}

$writer.Flush()

# 5. Compute SHA-1 checksum of the PBO body (Bohemia PBO checksum)
$allBytes = $memoryStream.ToArray()
$sha1 = [System.Security.Cryptography.SHA1]::Create()
$bodyHash = $sha1.ComputeHash($allBytes)

# 6. Write final PBO file: PBO body + 0x00 + 20-byte SHA-1
$finalStream = New-Object System.IO.FileStream($targetPboPath, [System.IO.FileMode]::Create)
$finalWriter = New-Object System.IO.BinaryWriter($finalStream)
$finalWriter.Write($allBytes)
$finalWriter.Write([byte]0)
$finalWriter.Write($bodyHash)
$finalWriter.Flush()
$finalStream.Close()

# 7. Compute SHA-256 of the entire final PBO file
$finalBytes = [System.IO.File]::ReadAllBytes($targetPboPath)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$fileHash = -join ($sha256.ComputeHash($finalBytes) | ForEach-Object { "{0:x2}" -f $_ })

# 8. Safe key signing check (Never overwrite existing .biprivatekey)
$privateKeyPath = Join-Path $OutputDir "DCO-GPT-2.1.0.biprivatekey"
$publicKeyPath = Join-Path $OutputDir "DCO-GPT-2.1.0.bikey"
$sigPath = "$targetPboPath.DCO-GPT-2.1.0.bisign"

if (Test-Path $privateKeyPath) {
    Write-Host "Private key found: $privateKeyPath (Existing key preserved, never overwritten)"
    $dsSign = Get-Command DSSignFile -ErrorAction SilentlyContinue
    if ($dsSign) {
        & DSSignFile $privateKeyPath $targetPboPath
        Write-Host "PBO signed successfully with DSSignFile: $sigPath"
    } else {
        Write-Host "DSSignFile not found on PATH. Manual signing available with Bohemia DSSignFile."
    }
} else {
    Write-Host "Note: No private key at $privateKeyPath. PBO compiled clean for SP/MP development."
}

Write-Host "=================================================="
Write-Host "PBO build complete: $targetPboPath"
Write-Host "Total Files: $($files.Count)"
Write-Host "PBO Size: $($finalBytes.Length) bytes"
Write-Host "SHA-256: $fileHash"
Write-Host "=================================================="
