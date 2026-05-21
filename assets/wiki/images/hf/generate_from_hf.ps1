param(
    [string]$ModelUrl = "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell",
    [string]$PromptFile = "./prompts.json",
    [int]$Retries = 3
)

$ErrorActionPreference = 'Stop'

if (-not $env:HF_TOKEN) {
    Write-Error "HF_TOKEN is not set in this terminal session."
    exit 1
}

$promptPath = Join-Path $PSScriptRoot $PromptFile
if (!(Test-Path $promptPath)) {
    Write-Error "Prompt file not found: $promptPath"
    exit 1
}

$headers = @{ Authorization = "Bearer $env:HF_TOKEN"; 'Content-Type' = 'application/json' }
$entries = Get-Content $promptPath -Raw | ConvertFrom-Json
$ok = 0
$failed = @()

function Test-ImageSignature {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $false }
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
    $outputRel = [string]$entry.output
    $prompt = [string]$entry.prompt
    $outPath = Join-Path $PSScriptRoot $outputRel
    $outDir = Split-Path $outPath
    if (!(Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $body = @{ inputs = $prompt } | ConvertTo-Json -Compress
    $done = $false

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            Invoke-WebRequest -Uri $ModelUrl -Method Post -Headers $headers -Body $body -OutFile $outPath -ErrorAction Stop
            $file = Get-Item $outPath -ErrorAction Stop
            if ($file.Length -gt 0 -and (Test-ImageSignature -Path $outPath)) {
                $ok++
                Write-Host ("OK  {0} ({1} bytes)" -f $outputRel, $file.Length)
                $done = $true
                break
            }

            $preview = ""
            try {
                $preview = Get-Content -Path $outPath -TotalCount 1 -ErrorAction SilentlyContinue
            } catch {
            }
            if (Test-Path $outPath) { Remove-Item $outPath -Force -ErrorAction SilentlyContinue }

            if ($attempt -eq $Retries) {
                Write-Warning ("FAIL {0}: response was not a valid image. Preview: {1}" -f $outputRel, $preview)
            }
        }
        catch {
            if ($attempt -eq $Retries) {
                Write-Warning ("FAIL {0}: {1}" -f $outputRel, $_.Exception.Message)
            }
        }
    }

    if (-not $done) {
        $failed += $outputRel
    }
}

Write-Host "Generated: $ok / $($entries.Count)"
if ($failed.Count -gt 0) {
    Write-Host "Failed outputs:"
    $failed | ForEach-Object { Write-Host (" - {0}" -f $_) }
    exit 2
}

Write-Host "All images generated successfully."
exit 0
