$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$addonDirectory = Join-Path $repositoryRoot "TalentDex"
$outputDirectory = Join-Path $repositoryRoot "dist"
$archivePath = Join-Path $outputDirectory "TalentDex-0.1.0.zip"

if (-not (Test-Path -LiteralPath (Join-Path $addonDirectory "TalentDex.toc"))) {
    throw "TalentDex.toc was not found in the addon directory."
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

Compress-Archive -LiteralPath $addonDirectory -DestinationPath $archivePath -CompressionLevel Optimal
Write-Host "Created $archivePath"
