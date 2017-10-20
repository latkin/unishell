param(
    $dataFilesDirectory
)

$scriptDir = Split-Path $psCommandPath
. $scriptDir/tables.ps1

# source data files
$unicodeDataPath = "$dataFilesDirectory/UnicodeData.txt"
$derivedAgePath = "$dataFilesDirectory/DerivedAge.txt"
$blocksPath = "$dataFilesDirectory/Blocks.txt"
$scriptsPath = "$dataFilesDirectory/Scripts.txt"
$lineBreakPath = "$dataFilesDirectory/LineBreak.txt"

$missingFiles = @()
if (-not (Test-Path $unicodeDataPath)) { $missingFiles += 'UnicodeData.txt' }
if (-not (Test-Path $derivedAgePath)) { $missingFiles += 'DerivedAge.txt' }
if (-not (Test-Path $blocksPath)) { $missingFiles += 'Blocks.txt' }
if (-not (Test-Path $scriptsPath )) { $missingFiles += 'Scripts.txt' }
if (-not (Test-Path $lineBreakPath)) { $missingFiles += 'LineBreak.txt' }

if ($missingFiles.Length -ne 0) {
    $errorMessage = "Required Unicode data files ($($missingFiles -join ', ')) were not found."
    Write-Host $errorMessage -ForegroundColor Yellow
    if ($AutoDownloadDataFiles -or ((Read-Host 'Press Y to download these files now') -match 'y')) {
        $missingFiles | % { 
            Invoke-WebRequest "https://www.unicode.org/Public/10.0.0/ucd/$_" -OutFile "$dataFilesDirectory/$_"
        }
    }
    else {
        Write-Error $errorMessage
        exit 1
    }
}

# all encodings supported by the running .NET framework
$allEncodings = [System.Text.Encoding]::GetEncodings().GetEncoding()

# rewrite format.ps1xml to dispaly different encodings by default
function updateFormatting($displayEncodings) {
    $formatFilepath = "$script:scriptDir/unishell.format.ps1xml"

    Get-Content "$script:scriptDir/unishell.format.template.xml" | % {
        switch -regex ($_) {
            '##DEFAULT_ENCODING_TABLE_HEADERS##' {
                $displayEncodings | % {
                    "<TableColumnHeader>"
                    "<Label>$_</Label>"
                    "<Alignment>Right</Alignment>"
                    "</TableColumnHeader>"
                }
                break
            }
            '##DEFAULT_ENCODING_TABLE_ITEMS##' {
                $displayEncodings | % {
                    "<TableColumnItem>"
                    "<Alignment>Right</Alignment>"
                    "<ScriptBlock>((`$_.'$_' |%{ `$_.ToString('X2') }) -join ' ').PadLeft(12)</ScriptBlock>"
                    "</TableColumnItem>"
                }
                break
            }
            '##ENCODING_LIST_ITEMS##' {
                $displayEncodings | % {
                    "<ListItem>"
                    "<Label>$_</Label>"
                    "<ScriptBlock>(`$_.'$_' |%{ `$_.ToString('X2') }) -join ' '</ScriptBlock>"
                    "</ListItem>"
                }
                break
            }
            default { $_ }
        }
    } | Out-File $formatFilepath -Encoding ascii

    # force refresh
    Update-FormatData -AppendPath $formatFilepath
    Update-FormatData
}

updateFormatting $defaultDisplayEncodings

# minimally-processed stub data for all codepoints from UnicodeData.txt, meant to be
# quick to load. Full set of properties and encodings are computed lazily as needed.
$stubData = @{}

# cache of fully-processed codepoint data
$charData = @{}

# lookup functions for range-based info

$rangeBlock = $null
function getRange($codepoint) {
    & $script:rangeBlock $codepoint
}

$ageBlock = $null
function getAge($codepoint) {
    & $script:ageBlock $codepoint
}

$blocksBlock = $null
function getBlock($codepoint) {
    & $script:blocksBlock $codepoint
}

$scriptsBlock = $null
function getScript($codepoint) {
    & $script:scriptsBlock $codepoint
}

$lineBreakBlock = $null
function getLineBreak($codepoint) {
    & $script:lineBreakBlock $codepoint
}

# generates a function body (scriptblock) that looks up a given codepoint
#  from a collection of individual codepoints or codepoint ranges, and returns a
#  value associated with that codepoint or range. This is how most of the Unicode
#  data files are organized.
function genRangedLookup($path, $fieldRegex, $fieldValueFunc, $defaultValue) {
    # parse the file and generate the range data once
    $rangeList = New-Object 'System.Collections.Generic.List[hashtable]'

    foreach ($line in [System.IO.File]::ReadLines((Resolve-Path $path).Path, [System.Text.Encoding]::UTF8)) {
        if ($line -cmatch "^(?<start>[A-F0-9]{4,6})(\.\.(?<end>[A-F0-9]{4,6}))?$fieldRegex") {
            $start = [Convert]::ToInt32($matches['start'], 16)
            $end = if ($matches['end']) { [Convert]::ToInt32($matches['end'], 16) } else { $start }
            $rangeList.Add(@{ start = $start; end = $end; value = (& $fieldValueFunc) })
        }
    }

    # close over the data in the function body, only do lookups on invocation
    {
        param($codepoint)
        foreach ($range in $rangeList) {
            if ($codepoint -ge $range.start -and $codepoint -le $range.end) {
                return $range.value
            }
        }
        return $defaultValue
    }.GetNewClosure()
}

# do the minimal amount of stub data loading such that all info
# can later be lazily computed if/when a specific codepoint is requested
function loadStub {
    # bail if already initialized
    if ($script:stubData.Count -ne 0) {
        return
    }

    # UnicodeData.txt is a weird hybrid that's mostly a list of individual codepoints,
    #  but also contains a handful of ranges (which are specified in a non-standard way).
    #  Thus the one-off parsing.
    $rangeList = New-Object 'System.Collections.Generic.List[hashtable]'
    $rangeItem = $null
    foreach ($line in ([System.IO.File]::ReadLines((Resolve-Path $script:unicodeDataPath).Path, [System.Text.Encoding]::UTF8))) {
        $fields = $line.Split(';')
        $f0 = $fields[0]
        $codepoint = [Convert]::ToInt32($f0, 16)
        
        if ($fields[1] -cmatch '^\<(?<rangeName>[a-zA-Z0-9 ]+?), (?<marker>First|Last)>$') {
            $fields[1] = $matches['rangeName']
            if ($matches['marker'] -eq 'First') {
                $rangeItem = @{start = $codepoint; end = 0}
            }
            else {
                $rangeItem['end'] = $codepoint
                $rangeList.Add($rangeItem)
            }
        }
        $script:stubData[$codepoint] = $fields
    }

    $script:rangeBlock = {
        param($codepoint)
        foreach ($range in $rangeList) {
            if ($codepoint -ge $range.start -and $codepoint -le $range.end) {
                return $range.start
            }
        }
    }.GetNewClosure()

    # initial parsing of DerivedAge.txt file
    #  (contains info pertaining to the Unicode version in which a codepoint was initially introduced)
    $script:ageBlock = genRangedLookup $script:derivedAgePath  ' *; (?<ver>[\d\.]+)' { $matches['ver'] } 'Unassigned'

    # initial parsing of Blocks.txt file
    #  (contains info about what named block a codepoint resides in)
    $script:blocksBlock = genRangedLookup $script:blocksPath  '; (?<block>[a-zA-Z0-9 \-]+)' { $matches['block'] } 'Unassigned'

    # initial parsing of Scripts.txt file
    #  (contains info about what script a codepoint is expressed in)
    $script:scriptsBlock = genRangedLookup $script:scriptsPath  ' *?; (?<script>[A-Za-z0-9_]+?) #' { $matches['script'] } 'Unknown'

    # initial parsing of LineBreak.txt file
    #  (contains info about line break behavior)
    $script:lineBreakBlock = genRangedLookup $script:lineBreakPath ';(?<class>[A-Z]{2,3}) ' { $lineBreakMappings[$matches['class']] } $lineBreakMappings['XX']
}

# cache a fully-processed codepoint object
function saveCharData($data) {
    $data.pstypenames.Add('unishell.codepoint')
    $script:charData[$data.Codepoint] = $data
}

# add noteproperties to the codepoint object for each available encoding
function addEncodings($codepointObj) {
    $props = @{}
    foreach ($enc in $allEncodings) {
        $name = $enc.WebName
        if (-not $props.ContainsKey($name)) {
            $bytes = if ($codepointObj.RawValue -eq $null) { , @() } else { $enc.GetBytes($codepointObj.RawValue) }
            $props.Add($name, [byte[]]$bytes)
        }
    }

    $codepointObj | Add-Member -NotePropertyMembers $props -Force -PassThru
}

# gets string representation of a specified codepoint,
# with support for unpaired surrogates
function getValue($codepoint) {
    if (($codepoint -lt 0) -or ($codepoint -gt 0x10ffff)) {
        Write-Error "$codepoint (0x$($codepoint.ToString('X4'))) is not a valid codepoint"
        $null
    }
    elseif (($codepoint -lt 55296) -or ($codepoint -gt 57343)) {
        [char]::ConvertFromUtf32($codepoint)
    }
    else {
        [char] $codepoint
    }
}

# gets the fully-processing codepoint object
function getChar($codepoint) {
    if (-not $script:charData.ContainsKey($codepoint)) {
        $value = getValue $codepoint
        if ($value -eq $null) { return }
        $fields = $script:stubData[$codepoint]

        if ($fields) {
            # format of UnicodeData.txt described at ftp://unicode.org/Public/3.0-Update/UnicodeData-3.0.0.html
            $name = $fields[1]
            if ($fields[10] -and ($fields[1] -like '<*>')) {
                $name = "$name $($fields[10])"
            }

            $obj = [pscustomobject]@{
                Value                     = displayValue $codepoint $value
                RawValue                  = $value
                Codepoint                 = $codepoint
                CodepointString           = "U+$($codepoint.ToString('X4'))"
                Name                      = $name
                Block                     = (getBlock $codepoint)
                Plane                     = plane $codepoint
                UnicodeVersion            = (getAge $codepoint)
                Script                    = (getScript $codepoint)
                LineBreakClass            = (getLineBreak $codepoint)
                Category                  = $generalCategoryMappings[$fields[2]]
                CanonicalCombiningClasses = $combiningClassMappings[$fields[3]]
                BidiCategory              = $bidiCategoryMappings[$fields[4]]
                DecompositionMapping      = $fields[5]
                DecimalDigitValue         = if ($fields[6]) { [int] $fields[6] } else {$null}
                DigitValue                = $fields[7]
                NumericValue              = $fields[8]
                Mirrored                  = ($fields[9] -eq 'Y')
                UppercaseMapping          = if ($fields[12]) { [Convert]::ToInt32($fields[12], 16) } else { $null }
                LowercaseMapping          = if ($fields[13]) { [Convert]::ToInt32($fields[13], 16) } else { $null }
                TitlecaseMapping          = if ($fields[14]) { [Convert]::ToInt32($fields[14], 16) } else { $null }
            }
            $obj = addEncodings $obj
            saveCharData $obj
        }
        else {
            # no info for this specific codepoint in $stubData,
            # so it maybe it's in the middle of some UnicodeData.txt range.
            # If so, getRange tells us the range's first codepoint
            $rangeStartCodepoint = getRange $codepoint
            if ($rangeStartCodepoint) {
                # add a stub entry pointing to the data of the range start codepoint
                $script:stubData[$codepoint] = $script:stubData[$rangeStartCodepoint]
                return (getChar $codepoint)
            }

            # otherwise, this codepoint must be unassigned
            $obj = [pscustomobject]@{
                Value                     = displayValue $codepoint $value
                RawValue                  = $value
                Codepoint                 = $codepoint
                CodepointString           = "U+$($codepoint.ToString('X4'))"
                Name                      = 'Unassigned'
                Block                     = (getBlock $codepoint)
                Plane                     = (plane $codepoint)
                UnicodeVersion            = $null
                Script                    = (getScript $codepoint)
                LineBreakClass            = (getLineBreak $codepoint)
                Category                  = $null
                CanonicalCombiningClasses = $null
                BidiCategory              = $null
                DecompositionMapping      = $null
                DecimalDigitValue         = $null
                DigitValue                = $null
                NumericValue              = $null
                Mirrored                  = $false
                UppercaseMapping          = $null
                LowercaseMapping          = $null
                TitlecaseMapping          = $null
            }
            $obj = addEncodings $obj
            saveCharData $obj
        }
    }

    # all paths will have populated $charData for the codepoint, just return it
    $script:charData[$codepoint]
}

# for a given input string, takes care of
# - Splitting the string into codepoints (handling surrogate pairs and unpaired surrogates)
# - Computing the fancy display combiner lines based on the string's
#     "text units" & combining character codepoints
# - Cobbling together core codepoint data and hidden display fields into 
#     final resulting object
function expandString($inputString) {
    # .NET's API for splitting a string into "text units", i.e. boundaries of
    #  surrogate pairs and/or base codepoints followed by combining codepoints.
    #  Limited... does not handle ZWJ, emoji modifiers, etc
    $textElemPositions = [System.Globalization.StringInfo]::ParseCombiningCharacters($inputString)

    $idx = 0
    $elemStart = $textElemPositions[$idx]
    $elemEnd = if ($textElemPositions.Length -gt ($idx + 1)) {
        $textElemPositions[$idx + 1] - 1
    }
    else {
        $inputString.Length - 1
    }

    for ($i = 0; $i -lt $inputString.Length; $i++) {
        $codepoint = try {
            [Char]::ConvertToUtf32($inputString, $i)
        }
        catch {
            # handle case of unpaired surrogates
            [int]$inputString[$i]
        }

        # base/core codepoint properties
        # the object we return will have hidden display fields, so create a copy
        #  instead of mutating the original
        $baseChar = (getChar $codepoint).PSObject.Copy()

        # is this a paired high surrogate?
        $isHS = ([Char]::IsHighSurrogate($inputString[$i]) -and ($i -lt $inputString.Length - 1) -and ([Char]::IsLowSurrogate($inputSTring[$i + 1])))

        # is the current codepoint a base codepoint
        $baseCurrent = $i -eq $elemStart
        # was there a base codepoint earlier in the string
        $baseBefore = $i -gt 0
        # are there any base codepoints later in the string
        $baseAfter = $idx -lt ($textElemPositions.Length - 1)

        # were there any codepoints earlier in the string
        $pointBefore = $i -gt $elemStart
        # are there any codepoints later in the string
        $pointAfter = ($i -lt ($elemEnd - 1)) -or (($i -eq ($elemEnd - 1)) -and !$isHS)

        # combiner line computations
        $combinerA = 
            if ($baseCurrent -and $baseBefore -and $baseAfter) { ([char]0x251C) }
            elseif ($baseCurrent -and $baseBefore -and !$baseAfter) { [char]0x2514 }
            elseif ($baseCurrent -and !$baseBefore -and $baseAfter) { ([char]0x250C) }
            elseif ($baseCurrent -and !$baseBefore -and !$baseAfter) { ([char]0x2500) }
            elseif (!$baseCurrent -and $baseBefore -and $baseAfter) { ([char]0x2502) }
            elseif (!$baseCurrent -and $baseBefore -and !$baseAfter) { " " }
            else { Write-Error "Unexpected $i $elemStart $elemEnd $idx $baseCurrent $baseBefore $baseAfter" }

        $combinerB =
            if ($pointBefore -and $pointAfter) { ([char]0x251C) }
            elseif ($pointBefore -and !$pointAfter) { ([char]0x2514) }
            elseif (!$pointBefore -and $pointAfter) { ([char]0x252C) }
            else { ([char]0x2500) }

        # add the hidden display fields
        $baseChar `
            | Add-Member -NotePropertyName '_Combiner' -NotePropertyValue "$combinerA$combinerB" -PassThru `
            | Add-Member -NotePropertyName '_OriginatingString' -NotePropertyValue $inputString -PassThru

        if ($isHS) {
            $i++
        }

        if ($i -eq $elemEnd) {
            $idx++
            $elemStart = $elemEnd + 1
            $elemEnd = if ($textElemPositions.Length -gt ($idx + 1)) {
                $textElemPositions[$idx + 1] - 1
            }
            else {
                $inputString.Length - 1
            }
        }
    }
}