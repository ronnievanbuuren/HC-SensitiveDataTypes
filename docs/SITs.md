# Sensitive Information Types (SIT) Details

This document describes the custom Sensitive Information Types included in `Rulepack/HealthCare.xml` and how each is detected. Values shown (proximity windows, confidence thresholds, and components) reflect the current rule pack.

Notes
- Proximity refers to the maximum distance between the primary identifier and supporting evidence.
- Confidence levels are expressed per pattern; the entity also has a `recommendedConfidence` that policies typically use.
- Some patterns use a DLP keyword dictionary created in your tenant. After creating dictionaries, ensure the rule pack references the correct dictionary identities (GUIDs) for your environment.

## Netherlands Citizen's Service (BSN) Number
- Primary identifier: `Func_netherlands_bsn` (BSN format/validation function)
- Supporting evidence: `Keywords_netherlands_bsn_edited` (BSN-related terms)
- Proximity: `50`
- Patterns and confidence:
  - `85`: BSN function + BSN-related keywords
- Recommended confidence: `85`

## Dutch Passport Number
- Primary identifier: `regex_dutch_pasport`
- Supporting evidence: `Keywords_Dutch_passport`
- Proximity: `50`
- Patterns and confidence:
  - `85`: Passport regex + passport-related keywords
- Recommended confidence: `85`

## Netherlands ZIP Code + City (dictionary)
- Primary identifier: `regex_dutch_zipcode`
- Supporting evidence: NL ZIP/city dictionary (from `Dictionaries/Keyword_netherlands_zipcode_cities.txt`)
- Proximity: `50`
- Patterns and confidence:
  - `85`: ZIP code regex + dictionary hit for a city name
- Recommended confidence: `85`
- Implementation note: The rule pack references the dictionary using a GUID. After you run `New-DlpKeywordDictionary`, update the rule pack to use your dictionary identity (or use the provided helper script if it maps identities for you).

## Email Addresses
- Primary identifier: `regex_emailaddress`
- Supporting evidence: `Keywords_emailaddress` (terms like email/e-mail variants)
- Proximity: `50`
- Patterns and confidence:
  - `60`: Email regex only
  - `85`: Email regex + email-related keywords
- Recommended confidence: `85`

## General Sensitive Keywords
- Primary identifier: `Func_eu_date` (date function to anchor context)
- Supporting evidence: `Keywords_sensitive_general` (PII-like terms)
- Proximity: `300`
- Patterns and confidence:
  - `75`: EU date + at least 3 distinct general-sensitive keywords (`minCount=3`, `uniqueResults=true`)
- Recommended confidence: `85`

## Healthcare Cure Set 1 (dictionary)
- Primary identifier: Healthcare Cure Set 1 dictionary (from `Dictionaries/termen_healthcare_cure1.txt`)
- Supporting evidence: May combine with Cure Set 2 terms and/or EU date in higher-confidence patterns
- Proximity: `500`
- Patterns and confidence (entity groups these together):
  - `60`: Cure Set 1 dictionary hit
  - `75`: Cure Set 2 keywords + Cure Set 1 dictionary hit
  - `80`: EU date + Cure Set 1 dictionary hit + Cure Set 2 keywords
- Recommended confidence: `75`

## Healthcare Cure Set 2 (keywords)
- Primary identifier: `Keywords_cure_2`
- Supporting evidence: Often paired with Cure Set 1 dictionary; EU date boosts confidence
- Proximity: `500`
- Patterns and confidence: see “Healthcare Cure Set 1” combined patterns above
- Recommended confidence: `75`

## Healthcare Care Sets
These entities use EU date anchors with one or more domain-specific keyword groups.

- Zorgplan
  - Evidence: `Keywords_zorgplan_1`, `Keywords_zorgplan_2`
  - Proximity: `300`
  - Patterns:
    - `65`: EU date + `Keywords_zorgplan_1`
    - `85`: EU date + `Keywords_zorgplan_1` + `Keywords_zorgplan_2`
  - Recommended confidence: `85`

- DVO
  - Evidence: `Keywords_zorg_DVO_1`, `Keywords_zorg_DVO_2`
  - Proximity: `300`
  - Patterns:
    - `65`: EU date + `Keywords_zorg_DVO_1`
    - `85`: EU date + `Keywords_zorg_DVO_1` + `Keywords_zorg_DVO_2`
  - Recommended confidence: `85`

- WMO (Ambulante zorg)
  - Evidence: `Keywords_ambulante_zorg`
  - Proximity: `300`
  - Patterns:
    - `65`: EU date + `Keywords_ambulante_zorg`
  - Recommended confidence: `85`

- Algemeen
  - Evidence: One or more groups such as `Keywords_zorg_algemeen_*` (e.g., `_3` shown)
  - Proximity: `300`
  - Patterns:
    - `65`: EU date + `Keywords_zorg_algemeen_*`
  - Recommended confidence: `85`

- Administratie
  - Evidence: `Keywords_zorg_administratie`
  - Proximity: `300`
  - Patterns:
    - `65`: EU date + `Keywords_zorg_administratie`
  - Recommended confidence: `85`

- Medische
  - Evidence: `Keywords_zorgmedisch_1`, `Keywords_zorgmedisch_2`
  - Proximity: `300`
  - Patterns:
    - `65`: EU date + `Keywords_zorgmedisch_1`
    - `85`: EU date + `Keywords_zorgmedisch_2` + `Keywords_zorgmedisch_1`
  - Recommended confidence: `85`

## Implementation Tips
- Dictionary identities: After creating dictionaries, retrieve identities with:
  - `Get-DlpKeywordDictionary | Select-Object Name,Identity`
  - Replace the dictionary `idRef` GUIDs in the rule pack with your identities before importing, or re-generate the XML using the helper script.
- Tuning:
  - Increase `patternsProximity` to broaden context; decrease to make matches stricter.
  - Adjust `recommendedConfidence` to control when a match counts as the SIT in policies.
  - Add/remove keywords in the `Dictionaries` or keyword groups inside the XML to refine results.

