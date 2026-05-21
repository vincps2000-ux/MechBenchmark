param(
    [string]$PromptFile = "./prompts.json"
)

$promptPath = Join-Path $PSScriptRoot $PromptFile
if (!(Test-Path $promptPath)) {
    Write-Error "Prompt file not found: $promptPath"
    exit 1
}

$entries = Get-Content $promptPath -Raw | ConvertFrom-Json
$missing = @()
$invalid = @()

function Test-ImageSignature {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 8) {
        $isPng = (
            $bytes[0] -eq 137 -and
            $bytes[1] -eq 80  -and
            $bytes[2] -eq 78  -and
            $bytes[3] -eq 71  -and
            $bytes[4] -eq 13  -and
            $bytes[5] -eq 10  -and
            $bytes[6] -eq 26  -and
            $bytes[7] -eq 10
        )
        if ($isPng) { return $true }
    }

    if ($bytes.Length -ge 3) {
        $isJpeg = ($bytes[0] -eq 255 -and $bytes[1] -eq 216 -and $bytes[2] -eq 255)
        if ($isJpeg) { return $true }
    }

    if ($bytes.Length -ge 12) {
        $isWebp = (
            $bytes[0] -eq 82 -and $bytes[1] -eq 73 -and $bytes[2] -eq 70 -and $bytes[3] -eq 70 -and
            $bytes[8] -eq 87 -and $bytes[9] -eq 69 -and $bytes[10] -eq 66 -and $bytes[11] -eq 80
        )
        if ($isWebp) { return $true }
    }

    return $false
}

foreach ($entry in $entries) {
    $outRel = [string]$entry.output
    $outPath = Join-Path $PSScriptRoot $outRel
    if (!(Test-Path $outPath)) {
        $missing += $outRel
        continue
    }

    if (-not (Test-ImageSignature -Path $outPath)) {
        $invalid += $outRel
    }
}

if ($missing.Count -eq 0 -and $invalid.Count -eq 0) {
    Write-Host "All Hugging Face MCP wiki images are present."
    exit 0
}

if ($missing.Count -gt 0) {
    Write-Warning "Missing generated images:"
    $missing | ForEach-Object { Write-Host " - $_" }
}

if ($invalid.Count -gt 0) {
    Write-Warning "Invalid/corrupt image files:"
    $invalid | ForEach-Object { Write-Host " - $_" }
}

exit 2
