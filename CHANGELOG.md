# Changelog

All notable changes to this project are documented here.

Format: Semantic Versioning (MAJOR.MINOR.PATCH). The underlying rule pack uses a four-part version (major/minor/build/revision); we map PATCH to the `build` field and keep `revision` at 0 unless otherwise noted.

## [7.0.6] - 2026-07-09
- **Critical fix: tenant keyword dictionaries were created empty.** The helper
  sent BOM-less UTF-16 bytes to `New/Set-DlpKeywordDictionary -FileData`; the
  service reads those as raw bytes and truncates at the first NUL, so the
  dictionary ended up containing a single junk term ("a") and the
  dictionary-based SITs (healthcare cure set, ZIP+city) never matched real
  content. `-FileData` requires UTF-8 bytes.
- `Dictionaries/*.txt` re-encoded from UTF-16 to UTF-8 (matching the helper's
  `-Encoding UTF8` read) and `Get-FileAsUnicodeBytes` now returns UTF-8 bytes.
- **Action for existing deployments**: run
  `./Set-DlpHealthRulePack.ps1 -EnsureDictionaries` once to repair the two
  dictionaries in the tenant (verify with
  `(Get-DlpKeywordDictionary -Name termen_healthcare_cure1).KeywordDictionary.Length`,
  which should be tens of thousands of characters, not 2).

## [7.0.5] - 2026-04-25
- Current committed template rule pack version is `7.0.5.0`.
- Helper script renamed to `Set-DlpHealthRulePack.ps1`.
- Helper script keeps `Rulepack/HealthCare.xml` tenant-agnostic and writes tenant-specific output to `Rulepack/Import-HCSensitiveDataTypes.xml`.
- Helper script creates or updates the two tenant keyword dictionaries, injects their live GUIDs, and can update or import the rule package.
- Tenant validation confirmed the `-UpdateRulepack` path auto-imports successfully when the healthcare rule package is missing.
- Tenant validation confirmed `-BumpBuild` generates version `7.0.6.0` import XML from the `7.0.5.0` template.

## [7.0.3] - 2025-10-03
- Helper script: auto-fallback to import when update fails because the rule pack is missing.
- Helper script: stricter error handling; stop on failures and show clear messages.
- Helper script: corrected WhatIf/ShouldProcess behavior and GUID injection; safe Unicode byte handling.

## [7.0.2] - 2025-10-03
- Bump rule pack version to `7.0.2` (build=2) in `Rulepack/HealthCare.xml`.
- Reorganized repository structure: added `Rulepack/` and `Dictionaries/` folders.
- Improved README with clear instructions, prerequisites, and Microsoft Learn references.
- Introduced versioning guidance and started this CHANGELOG.

## [7.0.1] - 2025-10-03
- Initial import of rule pack and dictionaries into this repository structure.
