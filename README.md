# HC-SensitiveDataTypes

Custom Microsoft 365/Purview Sensitive Information Types (SITs) tailored for the Dutch healthcare sector. These definitions can be used across Microsoft Purview Data Loss Prevention (DLP), Microsoft Defender for Cloud Apps, and AIP/MIP Scanner scenarios.

## What's Included

- Custom - Netherlands Citizen's Service (BSN) Number
- Custom - Dutch passport number
- Custom - Netherlands ZIP code + city (keyword dictionary)
- Custom - Email addresses
- Custom - General sensitive keywords
- Custom - Healthcare cure set 1 (keyword dictionary)
- Custom - Healthcare cure set 2 (keywords)
- Custom - Healthcare care sets, including Zorgplan, DVO, WMO, Algemeen, Administratie, and Medische

See the detailed detection logic for each SIT in [docs/SITs.md](docs/SITs.md).

The repository includes two tenant keyword dictionary source files:

- `Dictionaries/Keyword_netherlands_zipcode_cities.txt`
- `Dictionaries/termen_healthcare_cure1.txt`

The rule package also contains embedded keyword groups and regex/function-based SIT definitions.

## Repository Structure

- `Rulepack/HealthCare.xml` - Template SIT rule package XML with placeholder dictionary GUIDs
- `Rulepack/Import-HCSensitiveDataTypes.xml` - Generated tenant-specific import XML, ignored by Git
- `Dictionaries/Keyword_netherlands_zipcode_cities.txt` - NL ZIP + city keywords
- `Dictionaries/termen_healthcare_cure1.txt` - Healthcare cure keywords, set 1
- `Set-DlpHealthRulePack.ps1` - Helper script for dictionary upload, GUID injection, and rule package import/update
- `docs/SITs.md` - SIT detection details

## Prerequisites

- Microsoft 365 permissions: Compliance Administrator or equivalent
- PowerShell 7 or Windows PowerShell
- Exchange Online Management module
- A Microsoft Purview Compliance PowerShell connection

Install and connect:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
Import-Module ExchangeOnlineManagement
Connect-IPPSSession
```

If interactive sign-in fails in PowerShell 7 with a WAM/window-handle error, use:

```powershell
Connect-IPPSSession -DisableWAM
```

## Recommended Import

Use the helper script. It creates or updates the two keyword dictionaries, injects their tenant GUIDs into a generated import XML, and imports or updates the rule package.

```powershell
cd C:\_github\HC-SensitiveDataTypes
Import-Module ExchangeOnlineManagement
Connect-IPPSSession

.\Set-DlpHealthRulePack.ps1 -EnsureDictionaries -BumpBuild -UpdateRulepack
```

Behavior:

- `-EnsureDictionaries` creates missing dictionaries and updates existing dictionaries.
- `-InjectDictionaryIds` is enabled by default and writes tenant-specific dictionary GUIDs into `Rulepack\Import-HCSensitiveDataTypes.xml`.
- `-BumpBuild` increments the generated import XML build version by 1.
- `-UpdateRulepack` calls `Set-DlpSensitiveInformationTypeRulePackage`.
- If the update fails because the rule package is missing, `-AutoImportOnMissing` is enabled by default and the script falls back to `New-DlpSensitiveInformationTypeRulePackage`.

First-time import can also be run explicitly:

```powershell
.\Set-DlpHealthRulePack.ps1 -EnsureDictionaries -BumpBuild -ImportRulepack
```

Dry run:

```powershell
.\Set-DlpHealthRulePack.ps1 -EnsureDictionaries -BumpBuild -UpdateRulepack -WhatIf
```

## Manual Import Option

The helper script is preferred, but the same operations can be performed manually.

Create or update keyword dictionaries with UTF-16LE file bytes:

```powershell
$repoRoot = 'C:\_github\HC-SensitiveDataTypes'

$cureText = (Get-Content -LiteralPath (Join-Path $repoRoot 'Dictionaries\termen_healthcare_cure1.txt') -Encoding UTF8) -join "`r`n"
$cureBytes = [System.Text.Encoding]::Unicode.GetBytes($cureText + "`r`n")
New-DlpKeywordDictionary -Name 'termen_healthcare_cure1' -Description 'Keywords from file: termen_healthcare_cure1.txt' -FileData $cureBytes

$zipText = (Get-Content -LiteralPath (Join-Path $repoRoot 'Dictionaries\Keyword_netherlands_zipcode_cities.txt') -Encoding UTF8) -join "`r`n"
$zipBytes = [System.Text.Encoding]::Unicode.GetBytes($zipText + "`r`n")
New-DlpKeywordDictionary -Name 'Keyword_netherlands_zipcode_cities' -Description 'Keywords from file: Keyword_netherlands_zipcode_cities.txt' -FileData $zipBytes
```

Then retrieve dictionary identities, replace the placeholder GUIDs in the rule package XML, and import/update with:

```powershell
$rulepackBytes = [System.IO.File]::ReadAllBytes((Join-Path $repoRoot 'Rulepack\Import-HCSensitiveDataTypes.xml'))
New-DlpSensitiveInformationTypeRulePackage -FileData $rulepackBytes

# Later updates:
Set-DlpSensitiveInformationTypeRulePackage -FileData $rulepackBytes
```

## Validated Tenant Behavior

The helper has been validated against a Microsoft Purview tenant using this flow:

1. Remove the existing healthcare rule package.
2. Remove the large `Keyword_netherlands_zipcode_cities` dictionary.
3. Run `.\Set-DlpHealthRulePack.ps1 -EnsureDictionaries -BumpBuild -UpdateRulepack`.
4. Confirm the missing dictionary is recreated.
5. Confirm the missing rule package is imported automatically after the update-not-found failure.
6. Confirm the tenant rule package contains the tenant dictionary GUIDs and no placeholder GUIDs.

The template rule package currently has version `7.0.5.0`. A run with `-BumpBuild` generates an import XML with version `7.0.6.0`.

Expected custom SIT count from the package: 13.

## Versioning

The rule package uses a four-part version: `major.minor.build.revision`.

- Breaking SIT definition changes should increment `major`.
- Backward-compatible SIT additions should increment `minor`.
- Fixes, keyword updates, and helper-driven imports typically increment `build`.
- `revision` is kept at 0 unless a specific hotfix requires it.

Use `-BumpBuild` when generating an import XML for a tenant update so Purview receives a higher package version while the committed template remains tenant-agnostic.

## Usage

After importing, the custom SITs become available in the Microsoft Purview compliance portal for use in DLP policies. Depending on your configuration, they can also be used in Microsoft Defender for Cloud Apps file policies and AIP/MIP labeling or Scanner scenarios.

## Microsoft Learn References

- Create custom Sensitive Information Types: https://learn.microsoft.com/microsoft-365/compliance/create-custom-sensitive-information-types
- New-DlpSensitiveInformationTypeRulePackage: https://learn.microsoft.com/powershell/module/exchange/new-dlpsensitiveinformationtyperulepackage
- Set-DlpSensitiveInformationTypeRulePackage: https://learn.microsoft.com/powershell/module/exchange/set-dlpsensitiveinformationtyperulepackage
- New-DlpKeywordDictionary: https://learn.microsoft.com/powershell/module/exchange/new-dlpkeyworddictionary
- Built-in sensitive information types overview: https://learn.microsoft.com/microsoft-365/compliance/sensitive-information-type-learn-about

## Contributing

Contributions are welcome. Please open an issue or pull request describing the change, motivation, and testing notes.

## Thanks

Microsoft

## Authors

- Ronnie van Buuren - Initial work - LinkedIn: https://www.linkedin.com/in/ronnievanbuuren/ - GitHub: https://github.com/ronnievanbuuren

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
