param(
    [ValidateSet("fast", "full")]
    [string]$Profile = "fast",
    [int]$Jobs = 4,
    [string]$Image = "ghcr.io/zongpc/ldp-gem5:micro26-final"
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

New-Item -ItemType Directory -Force -Path "results" | Out-Null
docker cp "${container}:/results/." "./results/"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not copy results; retained container: $container"
}

docker rm $container | Out-Null
Write-Host "Results copied to: $((Resolve-Path results).Path)/$Profile"
