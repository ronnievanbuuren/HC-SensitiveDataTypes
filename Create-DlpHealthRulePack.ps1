<#

.SYNOPSIS
Ensures keyword dictionaries, injects their GUIDs into the rule pack, and optionally imports/updates it.

.DESCRIPTION
Creates or updates DLP keyword dictionaries from the `Dictionaries` folder, fetches their identities (GUIDs),
creates an import-ready copy of the rule pack from a template (default: `Rulepack/HealthCare.xml`), injects the
tenant-specific dictionary GUIDs into the copy, optionally bumps the build version, and imports/updates the DLP
Sensitive Information Type Rule Package using Compliance PowerShell.

Initial author: Ronnie van Buuren
Copyright (c) 2025. All rights reserved.

.PARAMETER RepoRoot
Root folder of the repository. Defaults to the script directory.

.PARAMETER EnsureDictionaries
Create or update dictionaries from the `Dictionaries` folder (default: off).

.PARAMETER InjectDictionaryIds
Replace placeholder GUIDs in the rule pack with the tenant dictionary identities (default: on).

.PARAMETER RulepackTemplatePath
Path to the template rule pack XML (default: `Rulepack/HealthCare.xml`).

.PARAMETER OutputRulepackPath
Path to write the import-ready rule pack XML (default: `Rulepack/Import-HCSensitiveDataTypes.xml`).

.PARAMETER InPlace
Write changes back to the template rule pack instead of generating a separate import file (default: off).

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
  [string]$RulepackTemplatePath = 'Rulepack\HealthCare.xml',
  [string]$OutputRulepackPath = 'Rulepack\Import-HCSensitiveDataTypes.xml',
  [switch]$InPlace,
  [switch]$EnsureDictionaries = $false,
  [switch]$InjectDictionaryIds = $true,
  [switch]$BumpBuild,
  [switch]$ImportRulepack,
  [switch]$UpdateRulepack,
  [switch]$AutoImportOnMissing = $true,
  [string]$PublisherName
)

# Placeholder GUIDs committed in the template rulepack (tenant-agnostic)
$script:PlaceholderCure1 = '3a2b0400-36e2-42c0-beb0-ad3ad999ff28'
$script:PlaceholderZip   = '490f642f-d3a6-4510-940f-7bfdb343d4ad'

function Resolve-RepoPath {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$Path
  )
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  Join-Path $RepoRoot $Path
}

function Get-FileAsUnicodeBytes {
  param([Parameter(Mandatory)][string]$Path)
  # Read text (UTF-8) and re-encode as UTF-16 LE bytes, ensuring CRLF line endings.
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  $text = ($lines -join "`r`n")
  if ($lines.Count -gt 0 -and -not $text.EndsWith("`r`n")) { $text += "`r`n" }
  return [System.Text.Encoding]::Unicode.GetBytes($text)
}

function Ensure-DlpDictionary {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$FilePath
  )
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
          $bytes = Get-FileAsUnicodeBytes -Path $FilePath
          # Some environments resolve -Identity by Name rather than GUID; prefer Name here.
          Set-DlpKeywordDictionary -Identity $Name -FileData $bytes -ErrorAction Stop | Out-Null
          Write-Host "Updated dictionary: $Name ($($existing.Identity))"
        } else {
          Write-Warning "Set-DlpKeywordDictionary not available; deleting and recreating '$Name'"
          # Delete + recreate as a fallback
          if (Get-Command Remove-DlpKeywordDictionary -ErrorAction SilentlyContinue) {
            Remove-DlpKeywordDictionary -Identity $existing.Identity -Confirm:$false -ErrorAction Stop
          }
          $bytes = Get-FileAsUnicodeBytes -Path $FilePath
          New-DlpKeywordDictionary -Name $Name -Description $Description -FileData $bytes -ErrorAction Stop | Out-Null
          Write-Host "Recreated dictionary: $Name"
        }
      } catch {
        throw $_
      }
    }
  } else {
    if ($PSCmdlet.ShouldProcess("DLP Keyword Dictionary '$Name'", 'Create')) {
      $bytes = Get-FileAsUnicodeBytes -Path $FilePath
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

function New-RulepackImportFile {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory)][string]$TemplateXmlPath,
    [Parameter(Mandatory)][string]$OutputXmlPath,
    [string]$Cure1Guid,
    [string]$ZipCityGuid,
    [switch]$InjectDictionaryIds,
    [switch]$IncrementBuild,
    [string]$PublisherName
  )

  if (-not (Test-Path -LiteralPath $TemplateXmlPath)) { throw "Rulepack template not found: $TemplateXmlPath" }

  $text = Get-Content -LiteralPath $TemplateXmlPath -Raw -Encoding Unicode

  $original = $text
  $notes = @()

  if ($InjectDictionaryIds) {
    if ($Cure1Guid -and ($text -match [regex]::Escape($script:PlaceholderCure1))) {
      $patternCure1 = 'idRef="' + $script:PlaceholderCure1 + '"'
      $replaceCure1 = 'idRef="' + $Cure1Guid + '"'
      $text = $text -replace [regex]::Escape($patternCure1), $replaceCure1
      $notes += "Cure1 placeholder => $Cure1Guid"
    } elseif ($Cure1Guid) {
      $notes += 'Cure1 placeholder not found (already injected?)'
    }

    if ($ZipCityGuid -and ($text -match [regex]::Escape($script:PlaceholderZip))) {
      $patternZip = 'idRef="' + $script:PlaceholderZip + '"'
      $replaceZip = 'idRef="' + $ZipCityGuid + '"'
      $text = $text -replace [regex]::Escape($patternZip), $replaceZip
      $notes += "ZIP/City placeholder => $ZipCityGuid"
    } elseif ($ZipCityGuid) {
      $notes += 'ZIP/City placeholder not found (already injected?)'
    }
  }

  if ($IncrementBuild) {
    $beforeBuild = $text
    $text = [System.Text.RegularExpressions.Regex]::Replace(
      $text,
      '<Version\s+major="(\d+)"\s+minor="(\d+)"\s+build="(\d+)"\s+revision="(\d+)"\s*/>',
      { param($m)
        $maj=[int]$m.Groups[1].Value; $min=[int]$m.Groups[2].Value; $b=[int]$m.Groups[3].Value; $rev=[int]$m.Groups[4].Value;
        $b++;
        ('<Version major="{0}" minor="{1}" build="{2}" revision="{3}" />' -f $maj, $min, $b, $rev)
      },
      1
    )
    if ($text -ne $beforeBuild) { $notes += 'Version build incremented' }
  }

  if ($PublisherName) {
    $beforePublisher = $text
    $escapedPublisherName = [System.Security.SecurityElement]::Escape($PublisherName)
    $publisherElement = ('<PublisherName>{0}</PublisherName>' -f $escapedPublisherName)
    $text = [System.Text.RegularExpressions.Regex]::Replace(
      $text,
      '<PublisherName>.*?</PublisherName>',
      { param($m) $publisherElement }
    )
    if ($text -ne $beforePublisher) { $notes += ("PublisherName => '{0}'" -f $PublisherName) }
  }

  $shouldWrite = ($OutputXmlPath -ne $TemplateXmlPath) -or ($text -ne $original)
  if ($shouldWrite) {
    if ($PSCmdlet.ShouldProcess($OutputXmlPath, 'Write import-ready rulepack')) {
      $outDir = Split-Path -Parent $OutputXmlPath
      if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
      }
      $text | Set-Content -LiteralPath $OutputXmlPath -Encoding Unicode
    }
  } else {
    Write-Host 'No changes applied to rulepack.'
  }

  if ($notes.Count -gt 0) { Write-Host ("Rulepack changes: " + ($notes -join '; ')) }
  $OutputXmlPath
}

function Assert-RulepackReadyForImport {
  param([Parameter(Mandatory)][string]$XmlPath)
  if (-not (Test-Path -LiteralPath $XmlPath)) { throw "Rulepack file not found: $XmlPath" }
  $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding Unicode
  if ($text.Contains($script:PlaceholderCure1) -or $text.Contains($script:PlaceholderZip)) {
    throw "Rulepack still contains placeholder GUID(s). Ensure dictionaries exist and run with -InjectDictionaryIds before importing/updating."
  }
}

#
# Main
#
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$dictFolder = Join-Path $repo 'Dictionaries'
$templateXmlPath = Resolve-RepoPath -RepoRoot $repo -Path $RulepackTemplatePath
$outputXmlPath = if ($InPlace) { $templateXmlPath } else { Resolve-RepoPath -RepoRoot $repo -Path $OutputRulepackPath }

Write-Host "Repo: $repo"
Write-Host "Dictionaries: $dictFolder"
Write-Host "Rulepack template: $templateXmlPath"
Write-Host "Rulepack output:   $outputXmlPath"

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
    Ensure-DlpDictionary -Name $name -Description $desc -FilePath $f.FullName -WhatIf:$WhatIfPreference | Out-Null
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
    Write-Warning "Missing dictionary identity(s): cure1='$cure1Id' zip='$zipId'. XML injection will be skipped."
  }
}

$doInject = $InjectDictionaryIds -and $cure1Id -and $zipId
$effectiveXmlPath = New-RulepackImportFile `
  -TemplateXmlPath $templateXmlPath `
  -OutputXmlPath $outputXmlPath `
  -Cure1Guid $cure1Id `
  -ZipCityGuid $zipId `
  -InjectDictionaryIds:$doInject `
  -IncrementBuild:$BumpBuild.IsPresent `
  -PublisherName $PublisherName `
  -WhatIf:$WhatIfPreference

# Import/update rulepack if requested
if ($ImportRulepack) {
  if ($PSCmdlet.ShouldProcess('Rulepack', 'Import (New-DlpSensitiveInformationTypeRulePackage)')) {
    try {
      Assert-RulepackReadyForImport -XmlPath $effectiveXmlPath
      $bytes = [System.IO.File]::ReadAllBytes($effectiveXmlPath)
      New-DlpSensitiveInformationTypeRulePackage -FileData $bytes -ErrorAction Stop | Out-Null
      Write-Host 'Imported rulepack.'
    } catch {
      Write-Error ("Import failed: {0}" -f $_.Exception.Message)
      throw
    }
  }
}
if ($UpdateRulepack) {
  if ($PSCmdlet.ShouldProcess('Rulepack', 'Update (Set-DlpSensitiveInformationTypeRulePackage)')) {
    Assert-RulepackReadyForImport -XmlPath $effectiveXmlPath
    $bytes = [System.IO.File]::ReadAllBytes($effectiveXmlPath)
    try {
      Set-DlpSensitiveInformationTypeRulePackage -FileData $bytes -ErrorAction Stop | Out-Null
      Write-Host 'Updated rulepack.'
    } catch {
      $msg = $_.Exception.Message
      $fqid = $_.FullyQualifiedErrorId
      $isNotFound = ($fqid -like '*ManagementObjectNotFoundException*') -or ($msg -match "couldn't be found")
      if ($AutoImportOnMissing -and $isNotFound) {
        Write-Warning 'Update failed (rulepack not found). Attempting import...'
        try {
          New-DlpSensitiveInformationTypeRulePackage -FileData $bytes -ErrorAction Stop | Out-Null
          Write-Host 'Imported rulepack.'
        } catch {
          Write-Error ("Import after update failure also failed: {0}" -f $_.Exception.Message)
          throw
        }
      } else {
        Write-Error ("Update failed: {0}" -f $msg)
        throw
      }
    }
  }
}
