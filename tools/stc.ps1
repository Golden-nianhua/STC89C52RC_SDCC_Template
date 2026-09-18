param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Source,

    [switch]$Build,
    [switch]$Flash
)

$ErrorActionPreference = "Stop"

if (-not $Build -and -not $Flash) {
    throw "请指定 -Build、-Flash，或同时指定两者。"
}

$project = Split-Path $PSScriptRoot -Parent
$sourcePath = if ([IO.Path]::IsPathRooted($Source)) {
    $Source
} elseif ($Source -match '^Labs[\\/]') {
    Join-Path $project $Source
} else {
    Join-Path $project (Join-Path "Labs" $Source)
}
$sourcePath = [IO.Path]::GetFullPath($sourcePath)

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "找不到源码：$sourcePath"
}

$extension = [IO.Path]::GetExtension($sourcePath).ToLowerInvariant()
if ($extension -notin ".asm", ".c") {
    throw "只支持 .asm 和 .c 源码。"
}

$lab = Split-Path (Split-Path $sourcePath -Parent) -Leaf
$name = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
$target = ("{0}_{1}" -f $lab, $name).ToLowerInvariant() -replace '[^a-z0-9_]', '_'
$outputDir = Join-Path $project "build/direct"
$image = Join-Path $outputDir "$target.ihx"

$sdccRoot = if ($env:SDCC_ROOT) { $env:SDCC_ROOT } else { "D:\Code\c-env\SDCC\SDCC-4.6.0" }
$sdcc = Join-Path $sdccRoot "bin/sdcc.exe"
$assembler = Join-Path $sdccRoot "bin/sdas8051.exe"

if ($Build) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    if ($extension -eq ".asm") {
        $object = Join-Path $outputDir "$target.rel"
        & $assembler -ols $object $sourcePath
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        & $sdcc -mmcs51 --model-small --nostdlib --code-size 8192 --iram-size 256 --xram-size 256 $object -o $image
    } else {
        & $sdcc -mmcs51 --model-small --std-c11 --code-size 8192 --iram-size 256 --xram-size 256 `
            "-I$(Join-Path $project 'Include')" $sourcePath -o $image
    }
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    Write-Host "固件：$image"
}

if ($Flash) {
    if (-not (Test-Path -LiteralPath $image -PathType Leaf)) {
        throw "找不到固件：$image，请先使用 -Build。"
    }
    $uv = "D:\Code\uv\uv.exe"
    & $uv run --script (Join-Path $project "tools/stcgal_runner.py") `
        --config (Join-Path $project "Misc/stcgal.toml") flash --image $image
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
