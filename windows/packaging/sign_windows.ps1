[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,

    [Parameter(Mandatory = $true)]
    [string]$ConfigurationPath
)

$certificatePath = $null

try {
    if (-not (Test-Path -LiteralPath $ConfigurationPath)) {
        throw "Signing configuration does not exist: $ConfigurationPath"
    }

    try {
        $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw |
            ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Unable to read signing configuration: $($_.Exception.Message)"
    }

    $certificateBase64 = [string]$configuration.certificateBase64
    $certificatePassword = [string]$configuration.certificatePassword

    if ([string]::IsNullOrWhiteSpace($certificateBase64) -or
        [string]::IsNullOrWhiteSpace($certificatePassword)) {
        Write-Host 'Windows code-signing configuration is not enabled; skipping signing.'
        exit 0
    }

    $tempRoot = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        [IO.Path]::GetTempPath()
    }
    else {
        $env:RUNNER_TEMP
    }
    $certificatePath = Join-Path $tempRoot "jadwal-v2-signing-$([guid]::NewGuid()).pfx"

    [IO.File]::WriteAllBytes(
        $certificatePath,
        [Convert]::FromBase64String($certificateBase64)
    )

    $signTool = Get-Command signtool.exe -ErrorAction Stop
    foreach ($target in $Path) {
        if (-not (Test-Path -LiteralPath $target)) {
            throw "Signing target does not exist: $target"
        }

        & $signTool.Source sign /fd SHA256 /td SHA256 `
            /tr 'http://timestamp.digicert.com' `
            /f $certificatePath /p $certificatePassword $target

        if ($LASTEXITCODE -ne 0) {
            throw "signtool failed for $target with exit code $LASTEXITCODE"
        }
    }
}
finally {
    if ($null -ne $certificatePath) {
        Remove-Item -LiteralPath $certificatePath -Force -ErrorAction SilentlyContinue
    }
}
