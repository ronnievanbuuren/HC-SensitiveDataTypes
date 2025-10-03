# HC-SensitiveDataTypes

Custom Microsoft 365/Purview Sensitive Information Types (SITs) tailored for the Dutch healthcare sector. These definitions can be used across Microsoft Purview Data Loss Prevention (DLP), Microsoft Defender for Cloud Apps (formerly MCAS), and AIP/MIP Scanner scenarios.

## What’s Included
- Custom – Netherlands Citizen's Service (BSN) Number
- Custom – Dutch passport number
- Custom – Netherlands ZIP code + city (keyword dictionary)
- Custom – Email addresses
- Custom – General sensitive keywords
- Custom – Healthcare cure set 1 (keywords)
- Custom – Healthcare cure set 2 (keywords)
- Custom – Healthcare care sets (e.g., Zorgplan, DVO, WMO, Algemeen, Administratie, Medische)

See detailed detection logic for each SIT in [docs/SITs.md](docs/SITs.md).

Note: Dictionaries currently included in this repo are focused on the NL ZIP/City list and Healthcare Cure Set 1. The rule package (`HealthCare.xml`) references these and additional SIT definitions.

## Repository Structure
- `Rulepack/HealthCare.xml` – Main SIT rule package XML
- `Dictionaries/Keyword_netherlands_zipcode_cities.txt` – NL ZIP + city keywords
- `Dictionaries/termen_healthcare_cure1.txt` – Healthcare “cure” keywords (set 1)
- `Create-DlpHealthRulePack.ps1` – Helper script for generating/importing the rule pack

## Why These SITs
Microsoft 365 includes many built‑in SITs, but localized SITs for the Dutch market are limited (BSN being the primary example). This project extends the built‑in coverage so you can accelerate DLP deployments without building everything from scratch.

## Prerequisites
- Permissions: Compliance Administrator or equivalent in Microsoft 365
- PowerShell with the Exchange Online Management module (for Compliance PowerShell)
- Ability to connect to Microsoft Purview Compliance PowerShell (`Connect-IPPSSession`)

## Installation and Import

1) Clone or download this repository locally.

2) Connect to Microsoft Purview Compliance PowerShell:

```powershell
Import-Module ExchangeOnlineManagement
Connect-IPPSSession
```

3) Define your local path to the repo root and create the keyword dictionaries:

```powershell
$repoRoot = 'C:\_github\HC-SensitiveDataTypes'   # adjust if different

# Healthcare Cure Set 1 dictionary
$cure1Bytes = Get-Content -Path (Join-Path $repoRoot 'Dictionaries\termen_healthcare_cure1.txt') -Encoding Byte -ReadCount 0
New-DlpKeywordDictionary -Name 'termen_healthcare_cure1' -Description 'Healthcare cure terms (set 1)' -FileData $cure1Bytes

# Netherlands ZIP + City dictionary
$zipBytes = Get-Content -Path (Join-Path $repoRoot 'Dictionaries\Keyword_netherlands_zipcode_cities.txt') -Encoding Byte -ReadCount 0
New-DlpKeywordDictionary -Name 'Keyword_netherlands_zipcode_cities' -Description 'NL zip code + city keywords' -FileData $zipBytes

# Optional: verify dictionaries
Get-DlpKeywordDictionary | Select-Object Name,Identity | Format-Table
```

4) Import the rule package (initial upload):

```powershell
$rulepackBytes = Get-Content -Path (Join-Path $repoRoot 'Rulepack\HealthCare.xml') -Encoding Byte -ReadCount 0
New-DlpSensitiveInformationTypeRulePackage -FileData ([Byte[]]$rulepackBytes)
```

5) Update the rule package (subsequent changes):

```powershell
$rulepackBytes = Get-Content -Path (Join-Path $repoRoot 'Rulepack\HealthCare.xml') -Encoding Byte -ReadCount 0
Set-DlpSensitiveInformationTypeRulePackage -FileData ([Byte[]]$rulepackBytes)
```

## Helper Script (One-Command Setup)
Use the included helper to create/update dictionaries, inject their GUIDs into the rule pack, and optionally bump the version and import/update the package.

Dry run (no changes):
```powershell
cd C:\_github\HC-SensitiveDataTypes
./Create-DlpHealthRulePack.ps1 -WhatIf
```

Typical update (ensure dictionaries, inject IDs, bump build, update rule pack):
```powershell
Import-Module ExchangeOnlineManagement
Connect-IPPSSession

cd C:\_github\HC-SensitiveDataTypes
./Create-DlpHealthRulePack.ps1 -EnsureDictionaries -InjectDictionaryIds -BumpBuild -UpdateRulepack
```

First-time import (instead of update):
```powershell
./Create-DlpHealthRulePack.ps1 -EnsureDictionaries -InjectDictionaryIds -BumpBuild -ImportRulepack
```

Notes:
- The script replaces placeholder GUIDs in `Rulepack/HealthCare.xml` for:
  - Cure Set 1 dictionary: `termen_healthcare_cure1`
  - NL ZIP + City dictionary: `Keyword_netherlands_zipcode_cities`
- Use `-WhatIf` anytime to preview actions without changes.

## Usage
- After importing, the custom SITs become available in the Microsoft Purview compliance portal to use in DLP policies.
- You can also reference these SITs in Microsoft Defender for Cloud Apps (file policies) and AIP/MIP labeling/Scanner scenarios depending on your configuration.

## Versioning
This project follows Semantic Versioning: `MAJOR.MINOR.PATCH`.

- MAJOR: Breaking changes to SIT definitions (e.g., removing or renaming SITs)
- MINOR: Backward‑compatible additions (new SITs, new keywords, new evidence)
- PATCH: Fixes and small tweaks (regex tuning, typo fixes, minor keyword updates)

Recommended practice:
- Update the version metadata inside `Rulepack/HealthCare.xml` when making changes.
- Keep a CHANGELOG (e.g., `CHANGELOG.md`) to summarize what changed per version.
- Tag releases in Git (e.g., `v1.2.0`) to align with the rule pack version.

See `CHANGELOG.md` for the release history.

## Microsoft Learn References
- Create custom Sensitive Information Types (SITs): https://learn.microsoft.com/microsoft-365/compliance/create-custom-sensitive-information-types
- New-DlpSensitiveInformationTypeRulePackage: https://learn.microsoft.com/powershell/module/exchange/new-dlpsensitiveinformationtyperulepackage
- Set-DlpSensitiveInformationTypeRulePackage: https://learn.microsoft.com/powershell/module/exchange/set-dlpsensitiveinformationtyperulepackage
- New-DlpKeywordDictionary: https://learn.microsoft.com/powershell/module/exchange/new-dlpkeyworddictionary
- Built‑in sensitive information types overview: https://learn.microsoft.com/microsoft-365/compliance/sensitive-information-type-learn-about

## Contributing
Contributions are welcome. Please open an issue or pull request describing the change, motivation, and testing notes.

## Thanks
Microsoft

## Authors
- Ronnie van Buuren – Initial work – LinkedIn: https://www.linkedin.com/in/ronnievanbuuren/ – GitHub: https://github.com/ronnievanbuuren

## License
This project is licensed under the MIT License – see the `LICENSE` file for details.
