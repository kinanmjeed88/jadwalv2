[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$PlatformLabel,

  [Parameter(Mandatory = $true)]
  [string]$ReleaseDir,

  [Parameter(Mandatory = $true)]
  [string]$DistDir,

  [Parameter(Mandatory = $true)]
  [string]$ReleaseArtifactName,

  [Parameter(Mandatory = $true)]
  [string]$DistributablesArtifactName,

  [Parameter(Mandatory = $true)]
  [int]$ReleaseRetentionDays,

  [Parameter(Mandatory = $true)]
  [int]$DistributablesRetentionDays,

  [Parameter(Mandatory = $true)]
  [string]$CommitSha,

  [string]$PubspecPath = 'pubspec.yaml'
)

$ErrorActionPreference = 'Stop'

function Get-FileSizeLabel {
  param([long]$Bytes)
  if ($Bytes -ge 1MB) {
    return ('{0:N1} MB' -f ($Bytes / 1MB))
  }
  if ($Bytes -ge 1KB) {
    return ('{0:N1} KB' -f ($Bytes / 1KB))
  }
  return "$Bytes B"
}

function Get-MarkdownFileTable {
  param(
    [System.IO.FileInfo[]]$Files,
    [string]$Root
  )
  $lines = @(
    '| File | Type | Size |',
    '|---|---|---:|'
  )
  foreach ($file in ($Files | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
    $extension = $file.Extension.ToLowerInvariant()
    $kind = switch ($extension) {
      '.exe' { 'Windows executable' }
      '.dll' { 'Native library' }
      '.zip' { 'ZIP archive' }
      '.dat' { 'Data file' }
      '.so' { 'AOT snapshot' }
      default { 'File' }
    }
    $lines += "| ``$relative`` | $kind | $(Get-FileSizeLabel $file.Length) |"
  }
  return ($lines -join "`n")
}

if (-not (Test-Path -LiteralPath $PubspecPath)) {
  throw "Missing pubspec: $PubspecPath"
}
$pubspec = Get-Content -LiteralPath $PubspecPath -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+(\d+))?') {
  throw 'Unable to read application version from pubspec.yaml'
}
$version = $Matches[1]
$buildNumber = if ($Matches[2]) { $Matches[2] } else { 'unspecified' }

$resolvedReleaseDir = (Resolve-Path -LiteralPath $ReleaseDir).Path
$resolvedDistDir = (Resolve-Path -LiteralPath $DistDir).Path
$shortSha = if ($CommitSha.Length -ge 7) { $CommitSha.Substring(0, 7) } else { $CommitSha }

$releaseExe = @(Get-ChildItem -LiteralPath $resolvedReleaseDir -File -Filter '*.exe')
$releaseDll = @(Get-ChildItem -LiteralPath $resolvedReleaseDir -File -Filter '*.dll')
$releaseTopLevel = @(Get-ChildItem -LiteralPath $resolvedReleaseDir -File)
$dataDir = Join-Path $resolvedReleaseDir 'data'
$dataExists = Test-Path -LiteralPath $dataDir
$dataChildren = @()
if ($dataExists) {
  $dataChildren = @(Get-ChildItem -LiteralPath $dataDir)
}
$releaseFileCount = @(Get-ChildItem -LiteralPath $resolvedReleaseDir -Recurse -File).Count

$releaseKind = 'Unknown'
$releasePurpose = 'Could not classify this artifact from its files.'
if ($releaseExe.Count -ge 1 -and $dataExists) {
  $releaseKind = 'Unpacked Flutter Windows Release bundle (run-in-place folder)'
  $releasePurpose = 'This is the raw output of `flutter build windows --release` at `build\windows\x64\runner\Release`. The workflow verifies the executable and `data` folder, runs a smoke test by launching the EXE, optionally signs that EXE, then uploads this folder as-is. It is the source copied into the ZIP and Inno Setup installer. It is not an installer and is not the end-user distribution package.'
}

$distFiles = @(Get-ChildItem -LiteralPath $resolvedDistDir -File | Where-Object {
    $_.Extension -in @('.zip', '.exe')
  })
$distZips = @($distFiles | Where-Object { $_.Extension -eq '.zip' })
$distSetups = @($distFiles | Where-Object { $_.Name -match 'Setup\.exe$' })
$distKind = 'Unknown'
$distPurpose = 'Could not classify this artifact from its files.'
if ($distZips.Count -ge 1 -and $distSetups.Count -ge 1) {
  $distKind = 'End-user distribution package (portable ZIP + Inno Setup installer)'
  $distPurpose = 'Created after the Release bundle exists. `Compress-Archive` packs the Release folder into a ZIP, and Inno Setup compiles an installer from the same folder (`SourceDir`). Only `dist\*.zip` and `dist\*.exe` are uploaded. This is the complete package intended for end users and installation.'
} elseif ($distZips.Count -ge 1) {
  $distKind = 'ZIP archive of the Release bundle'
  $distPurpose = 'Created by compressing the Flutter Release folder. No installer EXE was found in dist.'
}

$zipListing = @()
if ($distZips.Count -ge 1) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($distZips[0].FullName)
  try {
    $topLevel = @{}
    foreach ($entry in $archive.Entries) {
      $name = $entry.FullName -replace '\\', '/'
      $first = ($name -split '/')[0]
      if (-not [string]::IsNullOrWhiteSpace($first)) {
        $topLevel[$first] = $true
      }
    }
    $zipListing = @($topLevel.Keys | Sort-Object)
  } finally {
    $archive.Dispose()
  }
}

$exeNames = ($releaseExe | ForEach-Object { $_.Name }) -join ', '
$dllNames = ($releaseDll | ForEach-Object { $_.Name }) -join ', '
$dataNames = ($dataChildren | ForEach-Object { $_.Name }) -join ', '
$zipEntries = if ($zipListing.Count -gt 0) {
  ($zipListing | ForEach-Object { "- ``$_``" }) -join "`n"
} else {
  '_none_'
}

$summaryPath = $env:GITHUB_STEP_SUMMARY
if ([string]::IsNullOrWhiteSpace($summaryPath)) {
  throw 'GITHUB_STEP_SUMMARY is not set'
}

$markdown = @"
# Jadwal artifacts — $PlatformLabel

**Version:** $version  
**Build:** $buildNumber  
**Build type:** Release  
**Generated by:** GitHub Actions  
**Commit:** ``$shortSha`` (``$CommitSha``)  
**Platform:** $PlatformLabel  

This run uploads **two** Windows artifacts. They are not interchangeable: one is the raw build folder used for verification and packaging, the other is the end-user ZIP + installer.

---

## 1. ``$ReleaseArtifactName``

| Field | Value |
|---|---|
| Package | Release |
| Type | $releaseKind |
| Purpose | Internal/release bundle after analyze, test, build, verify, and smoke test |
| Platform | $PlatformLabel |
| Build type | Release |
| Retention | $ReleaseRetentionDays days |
| Workflow step | Archive Windows Release Bundle |
| Upload path | ``build\windows\x64\runner\Release\*`` |

$releasePurpose

**Inspected contents of ``$resolvedReleaseDir``**

- Files (recursive): $releaseFileCount
- Executables: $exeNames
- Local DLLs: $dllNames
- ``data`` directory present: $dataExists
- ``data`` children: $dataNames

### Top-level files

$(Get-MarkdownFileTable -Files $releaseTopLevel -Root $resolvedReleaseDir)

---

## 2. ``$DistributablesArtifactName``

| Field | Value |
|---|---|
| Package | Distributables |
| Type | $distKind |
| Purpose | Complete distribution package intended for end users and installation |
| Platform | $PlatformLabel |
| Build type | Release |
| Retention | $DistributablesRetentionDays days |
| Workflow step | Upload Windows ZIP and Installer |
| Upload path | ``dist\*.zip`` and ``dist\*.exe`` |

$distPurpose

### Dist files

$(Get-MarkdownFileTable -Files $distFiles -Root $resolvedDistDir)

### ZIP top-level entries

$zipEntries
"@

Add-Content -LiteralPath $summaryPath -Value $markdown -Encoding utf8
Write-Host "Wrote artifact summary for $PlatformLabel to GITHUB_STEP_SUMMARY"
