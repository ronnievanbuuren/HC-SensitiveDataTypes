<#

.SYNOPSIS
Ensures keyword dictionaries, injects their GUIDs into the rule pack, and optionally imports/updates it.

.DESCRIPTION
Creates or updates DLP keyword dictionaries from the `Dictionaries` folder, fetches their identities (GUIDs),
replaces placeholder GUIDs inside `Rulepack/HealthCare.xml`, optionally bumps the build version, and imports/updates
the DLP Sensitive Information Type Rule Package using Compliance PowerShell.

Initial author: Ronnie van Buuren
Maintained by: Wortell
Copyright (c) 2025. All rights reserved.

.PARAMETER RepoRoot
Root folder of the repository. Defaults to the script directory.

.PARAMETER EnsureDictionaries
Create or update dictionaries from the `Dictionaries` folder (default: on).

.PARAMETER InjectDictionaryIds
Replace placeholder GUIDs in the rule pack with the tenant dictionary identities (default: on).

.PARAMETER BumpBuild
Increment the rule pack Version `build` attribute by 1 (default: off).

.PARAMETER ImportRulepack
Call New-DlpSensitiveInformationTypeRulePackage after injection (default: off).

.PARAMETER UpdateRulepack
Call Set-DlpSensitiveInformationTypeRulePackage after injection (default: off).

.PARAMETER WhatIf
Preview actions without writing changes to files or calling import/update cmdlets.

.NOTES
Requires: Connected Microsoft Purview Compliance PowerShell session (Connect-IPPSSession)

.EXAMPLE
./Create-DlpHealthRulePack.ps1 -BumpBuild -InjectDictionaryIds -EnsureDictionaries -UpdateRulepack

#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [string]$RepoRoot = (Split-Path -Parent $PSCommandPath),
  [switch]$EnsureDictionaries = $true,
  [switch]$InjectDictionaryIds = $true,
  [switch]$BumpBuild,
  [switch]$ImportRulepack,
  [switch]$UpdateRulepack,
  [switch]$WhatIf
)

function Get-FileBytesUtf8AsUnicode {
  param([Parameter(Mandatory)][string]$Path)
  # DLP cmdlets expect Byte[] of the file content; return raw bytes.
  return (Get-Content -LiteralPath $Path -Encoding Byte -ReadCount 0)
}

function Ensure-DlpDictionary {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$FilePath
  )
  $bytes = Get-FileBytesUtf8AsUnicode -Path $FilePath
  try {
    $existing = Get-DlpKeywordDictionary -ErrorAction Stop | Where-Object { $_.Name -eq $Name }
  } catch {
    Write-Error "Get-DlpKeywordDictionary failed. Ensure you are connected: Connect-IPPSSession"
    return $null
  }

  if ($existing) {
    if ($PSCmdlet.ShouldProcess("DLP Keyword Dictionary '$Name'", 'Update')) {
      try {
        if (Get-Command Set-DlpKeywordDictionary -ErrorAction SilentlyContinue) {
          Set-DlpKeywordDictionary -Identity $existing.Identity -FileData $bytes -ErrorAction Stop | Out-Null
          Write-Host "Updated dictionary: $Name ($($existing.Identity))"
        } else {
          Write-Warning "Set-DlpKeywordDictionary not available; deleting and recreating '$Name'"
          # Delete + recreate as a fallback
          if (Get-Command Remove-DlpKeywordDictionary -ErrorAction SilentlyContinue) {
            Remove-DlpKeywordDictionary -Identity $existing.Identity -Confirm:$false -ErrorAction Stop
          }
          New-DlpKeywordDictionary -Name $Name -Description $Description -FileData $bytes -ErrorAction Stop | Out-Null
          Write-Host "Recreated dictionary: $Name"
        }
      } catch {
        throw $_
      }
    }
  } else {
    if ($PSCmdlet.ShouldProcess("DLP Keyword Dictionary '$Name'", 'Create')) {
      New-DlpKeywordDictionary -Name $Name -Description $Description -FileData $bytes -ErrorAction Stop | Out-Null
      Write-Host "Created dictionary: $Name"
    }
  }

  # Return fresh identity
  try {
    (Get-DlpKeywordDictionary -ErrorAction Stop | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
  } catch {
    $null
  }
}

function Inject-DictionaryIdsIntoRulepack {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$XmlPath,
    [Parameter(Mandatory)][string]$Cure1Guid,
    [Parameter(Mandatory)][string]$ZipCityGuid,
    [switch]$IncrementBuild
  )

  if (-not (Test-Path -LiteralPath $XmlPath)) { throw "Rulepack not found: $XmlPath" }

  $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding Unicode

  # Placeholders currently used in this repo
  $placeholderCure1 = '3a2b0400-36e2-42c0-beb0-ad3ad999ff28'
  $placeholderZip   = '490f642f-d3a6-4510-940f-7bfdb343d4ad'

  $original = $text
  $replacements = @()

  if ($Cure1Guid -and ($text -match [regex]::Escape($placeholderCure1))) {
    $text = $text -replace [regex]::Escape("idRef=\"$placeholderCure1\""), "idRef=\"$Cure1Guid\""
    $replacements += "Cure1 placeholder => $Cure1Guid"
  }

  if ($ZipCityGuid -and ($text -match [regex]::Escape($placeholderZip))) {
    $text = $text -replace [regex]::Escape("idRef=\"$placeholderZip\""), "idRef=\"$ZipCityGuid\""
    $replacements += "ZIP/City placeholder => $ZipCityGuid"
  }

  if ($IncrementBuild) {
    $text = [System.Text.RegularExpressions.Regex]::Replace(
      $text,
      '<Version\s+major="(\d+)"\s+minor="(\d+)"\s+build="(\d+)"\s+revision="(\d+)"\s*/>',
      { param($m)
        $maj=[int]$m.Groups[1].Value; $min=[int]$m.Groups[2].Value; $b=[int]$m.Groups[3].Value; $rev=[int]$m.Groups[4].Value;
        $b++;
        "<Version major=\"$maj\" minor=\"$min\" build=\"$b\" revision=\"$rev\" />"
      },
      1
    )
  }

  if ($text -ne $original) {
    if ($PSCmdlet.ShouldProcess($XmlPath, 'Write updated rulepack')) {
      $text | Set-Content -LiteralPath $XmlPath -Encoding Unicode
      if ($replacements.Count -gt 0) { Write-Host ("Replacements: " + ($replacements -join '; ')) }
      if ($IncrementBuild) { Write-Host "Version build incremented." }
    }
  } else {
    Write-Host "No changes applied to rulepack (placeholders not found or already injected)."
  }
}

#
# Main
#
$repo = Resolve-Path -LiteralPath $RepoRoot
$dictFolder = Join-Path $repo 'Dictionaries'
$xmlPath    = Join-Path $repo 'Rulepack\HealthCare.xml'

Write-Host "Repo: $repo"
Write-Host "Dictionaries: $dictFolder"
Write-Host "Rulepack: $xmlPath"

$cure1Name = 'termen_healthcare_cure1'
$zipName   = 'Keyword_netherlands_zipcode_cities'

$cure1Id = $null
$zipId   = $null

if ($EnsureDictionaries) {
  if (-not (Test-Path -LiteralPath $dictFolder)) { throw "Dictionaries folder not found: $dictFolder" }
  $files = Get-ChildItem -LiteralPath $dictFolder -File -Filter *.txt
  foreach ($f in $files) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $desc = "Keywords from file: $($f.Name)"
    Ensure-DlpDictionary -Name $name -Description $desc -FilePath $f.FullName -WhatIf:$WhatIf.IsPresent | Out-Null
  }
  # Retrieve identities for the two known names
  try {
    $cure1Id = (Get-DlpKeywordDictionary | Where-Object Name -eq $cure1Name | Select-Object -First 1).Identity
    $zipId   = (Get-DlpKeywordDictionary | Where-Object Name -eq $zipName   | Select-Object -First 1).Identity
  } catch {
    Write-Warning "Could not retrieve dictionary identities. Are you connected with Connect-IPPSSession?"
  }
}

if ($InjectDictionaryIds) {
  if (-not $cure1Id -or -not $zipId) {
    try {
      # Try to get identities even if not creating dictionaries this run
      if (-not $cure1Id) { $cure1Id = (Get-DlpKeywordDictionary | Where-Object Name -eq $cure1Name | Select-Object -First 1).Identity }
      if (-not $zipId)   { $zipId   = (Get-DlpKeywordDictionary | Where-Object Name -eq $zipName   | Select-Object -First 1).Identity }
    } catch {}
  }
  if (-not $cure1Id -or -not $zipId) {
    Write-Warning "Missing dictionary identity(s): cure1='$cure1Id' zip='$zipId'. Skipping XML injection."
  } else {
    Inject-DictionaryIdsIntoRulepack -XmlPath $xmlPath -Cure1Guid $cure1Id -ZipCityGuid $zipId -IncrementBuild:$BumpBuild.IsPresent -WhatIf:$WhatIf.IsPresent
  }
}

# Import/update rulepack if requested
if ($ImportRulepack) {
  if ($PSCmdlet.ShouldProcess('Rulepack', 'Import (New-DlpSensitiveInformationTypeRulePackage)')) {
    $bytes = [System.IO.File]::ReadAllBytes($xmlPath)
    New-DlpSensitiveInformationTypeRulePackage -FileData $bytes
    Write-Host 'Imported rulepack.'
  }
}
if ($UpdateRulepack) {
  if ($PSCmdlet.ShouldProcess('Rulepack', 'Update (Set-DlpSensitiveInformationTypeRulePackage)')) {
    $bytes = [System.IO.File]::ReadAllBytes($xmlPath)
    Set-DlpSensitiveInformationTypeRulePackage -FileData $bytes
    Write-Host 'Updated rulepack.'
  }
}

