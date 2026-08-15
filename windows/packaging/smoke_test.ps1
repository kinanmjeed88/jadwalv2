[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ExecutablePath,

  [int]$StartupWaitSeconds = 10,

  [int]$ShutdownWaitSeconds = 5
)

$resolvedExecutable = Resolve-Path -LiteralPath $ExecutablePath -ErrorAction Stop
$process = $null

try {
  $process = Start-Process -FilePath $resolvedExecutable.Path -PassThru
  Start-Sleep -Seconds $StartupWaitSeconds

  if ($process.HasExited) {
    throw "Windows application exited during smoke test with code $($process.ExitCode)"
  }
}
finally {
  if ($null -ne $process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $process.WaitForExit($ShutdownWaitSeconds * 1000)
  }
}

Write-Host "Windows smoke test passed: $($resolvedExecutable.Path)"
