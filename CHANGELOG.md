# Changelog

All notable changes to this project are documented here.

Format: Semantic Versioning (MAJOR.MINOR.PATCH). The underlying rule pack uses a four-part version (major/minor/build/revision); we map PATCH to the `build` field and keep `revision` at 0 unless otherwise noted.

## [7.0.2] - 2025-10-03
- Bump rule pack version to `7.0.2` (build=2) in `Rulepack/HealthCare.xml`.
- Reorganized repository structure: added `Rulepack/` and `Dictionaries/` folders.
- Improved README with clear instructions, prerequisites, and Microsoft Learn references.
- Introduced versioning guidance and started this CHANGELOG.

## [7.0.1] - 2025-10-03
- Initial import of rule pack and dictionaries into this repository structure.

## [7.0.3] - 2025-10-03
- Helper script: auto-fallback to import when update fails because the rule pack is missing.
- Helper script: stricter error handling; stop on failures and show clear messages.
- Helper script: corrected WhatIf/ShouldProcess behavior and GUID injection; safe Unicode byte handling.
