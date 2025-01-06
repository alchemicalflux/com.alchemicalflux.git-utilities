#-------------------------------------------------------------------------------
# File:         pre-commit.bash-file-header.ps1 
# Project:      AlchemicalFlux Utilities
# Overview:     Git hook for pre-commit processing of bash file headers.
# Copyright:    2023-2025 AlchemicalFlux. All rights reserved.
#
# Last commit by: alchemicalflux 
# Last commit at: 2025-01-05 20:31:29 
#-------------------------------------------------------------------------------

# Requires -Version 3.0
$ErrorActionPreference = "Stop"

# Add function modules as necessary
$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$functionsPath = Join-Path -Path $scriptPath -ChildPath 'functions.ps1'
. $functionsPath


# Constants
$headerStart = 
	"#-------------------------------------------------------------------------------"
$headerEnd =   
	"#-------------------------------------------------------------------------------"
$currentYear = Get-Date -Format "yyyy"
$user = & git config user.name
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$filePrefix =      "File:         "
$projectPrefix =   "Project:      "
$overviewPrefix =  "Overview:     "
$copyrightPrefix = "Copyright:    "
$userPrefix =      "Last commit by: "
$datePrefix =      "Last commit at: "

$projectPostfix =  "YourProjectName  # Replace with project name"
$overviewPostfix = "YourOverview  # Replace with overview"
$copyrightPostfix = 
	"YourName/YourCompany. All rights reserved.  # Replace with copyright"


# Gather all files to be updated and adjust as necessary
$stagedFiles = Get-BashFiles
foreach ($file in $stagedFiles) {
	
	# Full path to the file
	$filePath = Join-Path -Path (Get-Location) -ChildPath $file
	$fileName = Split-Path -Path $filePath -Leaf
	$content = Get-Content -Path $filePath -Raw
	
	# Bash files require a unique first line that must occur before any header
	$firstLine = Get-Content -Path $filePath -First 1

	# Assign values with any modifications if necessary
	$fileValue =      "$fileName "
	$copyrightValue = "$currentYear "
	$userValue =      "$user "
	$dateValue =      "$date "

	# Add the new header if it is missing
	if (-not ($content -match "$headerStart")) {
		$fileHeader =      "$filePrefix$fileValue"
		$projectHeader =   "$projectPrefix$projectPostfix"
		$overviewHeader =  "$overviewPrefix$overviewPostfix"
		$copyrightHeader = "$copyrightPrefix$copyrightValue$copyrightPostfix"
		$userHeader =      "$userPrefix$userValue"
		$dateHeader =      "$datePrefix$dateValue"

		$newHeader =
@"
$firstLine
$headerStart
# $fileHeader
# $projectHeader
# $overviewHeader
# $copyrightHeader
#
# $userHeader
# $dateHeader
$headerEnd

"@

		$content = $content.Replace($firstLine, $newHeader)
	}

	# Gather the header section by pattern
	$headerPattern = [regex]::Escape($headerStart) + "(.*?)" + 
		[regex]::Escape($headerEnd)
	$matchResults  = [regex]::Matches($content, $headerPattern, 'Singleline')

	# Check if we have a match
	if($matchResults.Count -eq 0) {
		Write-Error "No header found in file $fileName"
		exit 1
	}

	#Save off the the top header
	$originalHeader = $matchResults[0].Value
	$updatedHeader = $matchResults[0].Value

	# Update the file name to match
	$updatedHeader = $updatedHeader -replace "(?<=$filePrefix).*", $fileValue

	# Update copyright if single year is out of date
	if($updatedHeader -match "(?<=$copyrightPrefix\s*)\d{4} ") {
		# Get the year (e.g., 2023)
		$oldYear = $Matches[0].Substring($Matches[0].Length - 5, 4)
		if($oldYear -ne $currentYear) {
			$updatedHeader = $updatedHeader -replace 
				"$copyrightPrefix$oldYear ", 
				"$copyrightPrefix$oldYear-$currentYear "
		}
	}

	# Update latest copyright if double-year setup is out of date
	if($updatedHeader -match "(?<=$copyrightPrefix\s*)\d{4}-\d{4} ") {
		$yearRange = $Matches[0]
		$oldYear = $yearRange.Split('-')[0]  # Get the first year of the range
		$updatedHeader = $updatedHeader -replace "$copyrightPrefix$yearRange", 
			"$copyrightPrefix$oldYear-$currentYear "
	}

	# Update the user to match the committor
	$updatedHeader = $updatedHeader -replace "(?<=$userPrefix).*", $userValue

	# Update the commit date and time
	$updatedHeader = $updatedHeader -replace "(?<=$datePrefix).*", $dateValue

	# Replace the original header with the altered data and save
	$finalContent = $content.Replace($originalHeader, $updatedHeader)
	Set-Content -Path $filePath -Value $finalContent -NoNewLine

	# Stage the file for commit
	& git add $filePath
}