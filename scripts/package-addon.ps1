param(
    [string]$OutputPath = "dist/TalentMinder.zip"
)

$addonPath = Join-Path $PSScriptRoot "../addon/TalentMinder"
$resolvedOutput = Join-Path (Get-Location) $OutputPath
$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
if (Test-Path -LiteralPath $resolvedOutput) {
    Remove-Item -LiteralPath $resolvedOutput -Force
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($addonPath, $resolvedOutput, [IO.Compression.CompressionLevel]::Optimal, $true)
Write-Output "Packaged $resolvedOutput"
