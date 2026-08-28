param(
    [ValidateSet("fast", "full")]
    [string]$Profile = "fast",
    [int]$Jobs = 4,
    [string]$Image = "ghcr.io/zongpc/ldp-gem5:micro26-final",
    [string]$OutputDir = "results"
)

$ErrorActionPreference = "Stop"
$container = "ldp-ae-$Profile-$PID"

docker create `
    --name $container `
    --platform linux/amd64 `
    $Image `
    --run-profile $Profile --jobs $Jobs | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not create container: $container"
}

docker start -a $container
if ($LASTEXITCODE -ne 0) {
    Write-Error "Run failed; retained container: $container"
}

if (Test-Path -LiteralPath $OutputDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = "$OutputDir-$Profile-$stamp-$PID"
    Write-Host "Existing output path detected; exporting to: $OutputDir"
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null
docker cp "${container}:/results/." "$OutputDir/"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not copy results; retained container: $container"
}

docker rm $container | Out-Null
Write-Host "Results copied to: $((Resolve-Path $OutputDir).Path)/$Profile"
