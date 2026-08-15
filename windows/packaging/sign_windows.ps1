[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path
)

$certificateBase64 = $env:WINDOWS_CERTIFICATE_BASE64
$certificatePassword = $env:WINDOWS_CERTIFICATE_PASSWORD

if ([string]::IsNullOrWhiteSpace($certificateBase64) -or
    [string]::IsNullOrWhiteSpace($certificatePassword)) {
    Write-Host 'Windows code-signing secrets are not configured; skipping signing.'
    exit 0
}

$certificatePath = Join-Path $env:RUNNER_TEMP 'jadwal-v2-signing.pfx'
try {
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
    Remove-Item -LiteralPath $certificatePath -Force -ErrorAction SilentlyContinue
}
