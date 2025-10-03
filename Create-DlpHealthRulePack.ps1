<#

.SYNOPSIS
Add Healthcare specific sensitive information types to a Microsoft 365 tenant.

.DESCRIPTION
Initial author: Ronnie van Buuren
Last update: Andries den Haan
Company: Wortell
Copyright (c) 2025. All rights reserved.

#>

# Create keyword dictionaries
$dictionarySourceFiles = Get-ChildItem ".\Dictionaries" -File -Include *.txt

$dictionarySourceFiles | ForEach-Object {
    $fileName = $_.Name
    $filePath = $_.FullName
    $dictionaryName = $fileName -replace '.txt', ''
    $description = "Healthcare specific keywords from file: $fileName"

    # Read the file content and encode it to Unicode
    $encodedKeywords = Get-Content $filePath | ForEach-Object { [System.Text.Encoding]::Unicode.GetBytes($_ + "`r`n") }

    # Create the keyword dictionary
    New-DlpKeywordDictionary -Name $dictionaryName -Description $description -FileData $encodedKeywords
}

# Get dictionary names and identities
Get-DlpKeywordDictionary | Select-Object name, identity

# Manually update the id's for dictionary references 'Keywords_cure_2' and 'regex_dutch_zipcode' in the rulepack file
# Ensure that the guid in the rulepack for the dictionary references is updated to the new guid throughouth the entire rulepack

# Create/import DLP rule package
New-DlpSensitiveInformationTypeRulePackage -FileData ([System.IO.File]::ReadAllBytes(".\Rulepack\HealthCare.xml"))

# Update rulepackage
Set-DlpSensitiveInformationTypeRulePackage -FileData ([System.IO.File]::ReadAllBytes(".\Rulepack\HealthCare.xml"))