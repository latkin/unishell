param(
    $DataFilesDirectory,
    $DefaultDisplayEncodings = @('utf-8', 'utf-16')
)

$scriptDir = Split-Path $psCommandPath

if (-not $dataFilesDirectory) {
    $dataFilesDirectory = $scriptDir
}

$unicodeDataPath = "$dataFilesDirectory/UnicodeData.txt"
$derivedAgePath =  "$dataFilesDirectory/DerivedAge.txt"
$blocksPath =  "$dataFilesDirectory/Blocks.txt"
$scriptsPath = "$dataFilesDirectory/Scripts.txt"
$lineBreakPath = "$dataFilesDirectory/LineBreak.txt"

$missingFiles = @()
if (-not (Test-Path $unicodeDataPath)) { $missingFiles += 'UnicodeData.txt' }
if (-not (Test-Path $derivedAgePath)) { $missingFiles += 'DerivedAge.txt' }
if (-not (Test-Path $blocksPath)) { $missingFiles += 'Blocks.txt' }
if (-not (Test-Path $scriptsPath )) { $missingFiles += 'Scripts.txt' }
if (-not (Test-Path $lineBreakPath)) { $missingFiles += 'LineBreak.txt' }

if ($missingFiles.Length -ne 0) {
    $errorMessage = "Required Unicode data files ($missingFiles) were not found."
    Write-Host $errorMessage -ForegroundColor Yellow
    if ((Read-Host 'Press Y to download these files now') -match 'y') {
        $missingFiles | % { 
            Invoke-WebRequest "https://www.unicode.org/Public/10.0.0/ucd/$_" -OutFile "$dataFilesDirectory/$_"
        }
    } else {
        Write-Error $errorMessage
        exit
    }
}

$allEncodings = [System.Text.Encoding]::GetEncodings().GetEncoding()
$maxDefaultDisplayEncodingLength = ($DefaultDisplayEncodings | % Length | Measure-Object -Maximum).Maximum

$generalCategoryMappings = @{
    'Lu' = 'Lu - Letter, Uppercase'
    'Ll' = 'Ll - Letter, Lowercase'
    'Lt' = 'Lt - Letter, Titlecase'
    'Mn' = 'Mn - Mark, Non-Spacing'
    'Mc' = 'Mc - Mark, Spacing Combining'
    'Me' = 'Me - Mark, Enclosing'
    'Nd' = 'Nd - Number, Decimal Digit'
    'Nl' = 'Nl - Number, Letter'
    'No' = 'No - Number, Other'
    'Zs' = 'Zs - Separator, Space'
    'Zl' = 'Zl - Separator, Line'
    'Zp' = 'Zp - Separator, Paragraph'
    'Cc' = 'Cc - Other, Control'
    'Cf' = 'Cf - Other, Format'
    'Cs' = 'Cs - Other, Surrogate'
    'Co' = 'Co - Other, Private Use'
    'Cn' = 'Cn - Other, Not Assigned'
    'Lm' = 'Lm - Letter, Modifier'
    'Lo' = 'Lo - Letter, Other'
    'Pc' = 'Pc - Punctuation, Connector'
    'Pd' = 'Pd - Punctuation, Dash'
    'Ps' = 'Ps - Punctuation, Open'
    'Pe' = 'Pe - Punctuation, Close'
    'Pi' = 'Pi - Punctuation, Initial quote'
    'Pf' = 'Pf - Punctuation, Final quote'
    'Po' = 'Po - Punctuation, Other'
    'Sm' = 'Sm - Symbol, Math'
    'Sc' = 'Sc - Symbol, Currency'
    'Sk' = 'Sk - Symbol, Modifier'
    'So' = 'So - Symbol, Other'
}

$combiningClassMappings = @{
    '0'   = '0 - Spacing, split, enclosing, reordrant, and Tibetan subjoined'
    '1'   = '1 - Overlays and interior'
    '7'   = '7 - Nuktas'
    '8'   = '8 - Hiragana/Katakana voicing marks'
    '9'   = '9 - Viramas'
    '10'  = '10 - Start of fixed position classes'
    '199' = '199 - End of fixed position classes'
    '200' = '200 - Below left attached'
    '202' = '202 - Below attached'
    '204' = '204 - Below right attached'
    '208' = '208 - Left attached (reordrant around single base character)'
    '210' = '210 - Right attached'
    '212' = '212 - Above left attached'
    '214' = '214 - Above attached'
    '216' = '216 - Above right attached'
    '218' = '218 - Below left'
    '220' = '220 - Below'
    '222' = '222 - Below right'
    '224' = '224 - Left (reordrant around single base character)'
    '226' = '226 - Right'
    '228' = '228 - Above left'
    '230' = '230 - Above'
    '232' = '232 - Above right'
    '233' = '233 - Double below'
    '234' = '234 - Double above'
    '240' = '240 - Below (iota subscript)'
}

$bidiCategoryMappings = @{
    'L'   = 'L - Left-to-Right'
    'LRE' = 'LRE - Left-to-Right Embedding'
    'LRO' = 'LRO - Left-to-Right Override'
    'R'   = 'R - Right-to-Left'
    'AL'  = 'AL - Right-to-Left Arabic'
    'RLE' = 'RLE - Right-to-Left Embedding'
    'RLO' = 'RLO - Right-to-Left Override'
    'PDF' = 'PDF - Pop Directional Format'
    'EN'  = 'EN - European Number'
    'ES'  = 'ES - European Number Separator'
    'ET'  = 'ET - European Number Terminator'
    'AN'  = 'AN - Arabic Number'
    'CS'  = 'CS - Common Number Separator'
    'NSM' = 'NSM - Non-Spacing Mark'
    'BN'  = 'BN - Boundary Neutral'
    'B'   = 'B - Paragraph Separator'
    'S'   = 'S - Segment Separator'
    'WS'  = 'WS - Whitespace'
    'ON'  = 'ON - Other Neutrals'
}

$lineBreakMappings = @{
    'BK'  = 'BK - Mandatory Break'
    'CR'  = 'CR - Carriage Return'
    'LF'  = 'LF - Line Feed'
    'CM'  = 'CM - Combining Mark'
    'NL'  = 'NL - Next Line'
    'SG'  = 'SG - Surrogate'
    'WJ'  = 'WJ - Word Joiner'
    'ZW'  = 'ZW - Zero Width Space'
    'GL'  = 'GL - Non-breaking ("Glue")'
    'SP'  = 'SP - Space'
    'ZWJ' = 'ZWJ - Zero Width Joiner'
    'B2'  = 'Break Opportunity Before and After'
    'BA'  = 'BA - Break After'
    'BB'  = 'BB - Break Before'
    'HY'  = 'HY - Hyphen'
    'CB'  = 'CB - Contingent Break Opportunity'
    'CL'  = 'CL - Close Punctuation'
    'CP'  = 'CP - Close Parenthesis'
    'EX'  = 'EX - Exclamation/Interrogation'
    'IN'  = 'IN - Inseparable'
    'NS'  = 'NS - Nonstarter'
    'OP'  = 'OP - Open Punctuation'
    'QU'  = 'QU - Quotation'
    'IS'  = 'IS - Infix Numeric Separator'
    'NU'  = 'NU - Numeric'
    'PO'  = 'PO - Postfix Numeric'
    'PR'  = 'PR - Prefix Numeric'
    'SY'  = 'SY - Symbols Allowing Break After'
    'AI'  = 'AI - Ambiguous (Alphabetic or Ideographic)'
    'AL'  = 'AL - Alphabetic'
    'CJ'  = 'CJ - Conditional Japanese Starter'
    'EB'  = 'EB - Emoji Base'
    'EM'  = 'EM - Emoji modifier'
    'H2'  = 'H2 - Hangul LV Syllable'
    'H3'  = 'H3 - Hangul LVT Syllable'
    'HL'  = 'HL - Hebrew Letter'
    'ID'  = 'ID - Ideographic'
    'JL'  = 'JL - Hangul L Jamo'
    'JV'  = 'JV - Hangul V Jamo'
    'JT'  = 'JT - Hangul T Jamo'
    'RI'  = 'RI - Regional Indicator'
    'SA'  = 'SA - Complex Context Dependent (South East Asian)'
    'XX'  = 'XX - Unknown'
}

function plane($code) {
    if($code -lt 0) { Write-Error "Invalid codepoint" }
    elseif($code -le 0xFFFF){ '0 - Basic Multilingual Plane' }
    elseif($code -le 0x1FFFF) { '1 - Supplementary Multilingual Plane'}
    elseif($code -le 0x2FFFF) { '2 - Supplementary Ideographic Plane' }
    elseif($code -le 0x3FFFF) { '3 - Tertiary Ideographic Plane' }
    elseif($code -le 0x4FFFF) { '4 - Unassigned' }
    elseif($code -le 0x5FFFF) { '5 - Unassigned' }
    elseif($code -le 0x6FFFF) { '6 - Unassigned' }
    elseif($code -le 0x7FFFF) { '7 - Unassigned' }
    elseif($code -le 0x8FFFF) { '8 - Unassigned' }
    elseif($code -le 0x9FFFF) { '9 - Unassigned' }
    elseif($code -le 0xAFFFF) { '10 - Unassigned' }
    elseif($code -le 0xBFFFF) { '11 - Unassigned' }
    elseif($code -le 0xCFFFF) { '12 - Unassigned' }
    elseif($code -le 0xDFFFF) { '13 - Unassigned' }
    elseif($code -le 0xEFFFF) { '14 - Supplementary Special-purpose Plane' }
    elseif($code -le 0xFFFFF) { '15 - Supplementary Private Use Area-A' }
    elseif($code -le 0x10FFFF) { '16 - Supplementary Private Use Area-B'}
    else { Write-Error "Invalid codepoint" }
}

function updateFormatting {
    $formatFilepath = "$script:scriptDir/unishell.format.ps1xml"

    Get-Content "$script:scriptDir/unishell.format.template.xml" | % {
        switch -regex ($_) {
            '##DEFAULT_ENCODING_HEADERS##' {
                $defaultDisplayEncodings | % {
                    "<TableColumnHeader>"
                    "<Label>$_</Label>"
                    "<Alignment>Right</Alignment>"
                    "</TableColumnHeader>"
                }
                break
            }
            '##DEFAULT_ENCODING_ITEMS##' {
                $defaultDisplayEncodings | % {
                    "<TableColumnItem>"
                    "<Alignment>Right</Alignment>"
                    "<ScriptBlock>((`$_.Encodings.'$_' |%{ `$_.ToString('X2') }) -join ' ').PadLeft(12)</ScriptBlock>"
                    "</TableColumnItem>"
                }
                break
            }
            '##ENCODINGS_LIST_ITEMS##' {
                $allEncodings | % {
                    "<ListItem>"
                    "<Label>$($_.webname)</Label>"
                    "<ScriptBlock>(`$_.'$($_.webname)' |%{ `$_.ToString('X2') }) -join ' '</ScriptBlock>"
                    "</ListItem>"
                }
                break
            }
            default { $_ }
        }
    } | Out-File $formatFilepath -Encoding ascii

    Update-FormatData -AppendPath $formatFilepath
    Update-FormatData
}

updateFormatting

$stubData = @{}
$charData = @{}
$rangeBlock = $null
$ageBlock = $null
$blocksBlock = $null
$scriptsBlock = $null
$lineBreakBlock = $null

function genRangedLookup($path, $fieldRegex, $fieldValueFunc, $defaultValue) {
    $lines = [System.IO.File]::ReadAllLines((Resolve-Path $path).Path, [System.Text.Encoding]::UTF8)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('[scriptblock] { param($code)')
    $clause = 'if'
    foreach ($line in $lines) {
        if ($line -cmatch "^(?<start>[A-F0-9]{4,6})(\.\.(?<end>[A-F0-9]{4,6}))?$fieldRegex") {
            $start = $matches['start']
            $end = $matches['end']
            if ($start -and $end) {
                $null = $sb.AppendLine("$clause((`$code -ge 0x$start) -and (`$code -le 0x$end)){ $(& $fieldValueFunc) }")
            }
            else {
                $null = $sb.AppendLine("$clause(`$code -eq 0x$start) { $(& $fieldValueFunc) }")
            }
            $clause = 'elseif'
        }
    }

    $null = $sb.AppendLine("else { $defaultValue } }")
    Invoke-Expression $sb.ToString()
}

function loadStub {
    # bail if already initialized
    if ($script:stubData.Count -ne 0) {
        return
    }

    # initial parsing of UnicodeData.txt file
    #  (contains core properties)
    $lines = [System.IO.File]::ReadAllLines((Resolve-Path $script:unicodeDataPath).Path, [System.Text.Encoding]::UTF8)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('[scriptblock] { param($code)')
    $clause = 'if'
    foreach ($line in $lines) {
        $fields = $line.Split(';')
        $f0 = $fields[0]
        $codepointName = 'U+' + $f0

        if ($fields[1] -cmatch '^\<(?<rangeName>[a-zA-Z0-9 ]+?), (?<marker>First|Last)>$') {
            $fields[1] = $matches['rangeName']
            if ($matches['marker'] -eq 'First') {
                $null = $sb.Append("$clause((`$code -ge 0x$f0) -and ")
                $clause = 'elseif'
            }
            else {
                $null = $sb.AppendLine("(`$code -le 0x$f0)){ '$codepointName' }")
            }
        }
        $script:stubData[$codepointName] = $fields
    }

    $null = $sb.AppendLine("else { `$null } }")
    $script:rangeBlock = Invoke-Expression $sb.ToString()

    # initial parsing of DerivedAge.txt file
    #  (contains info pertaining to the Unicode version in which a codepoint was initially introduced)
    $script:ageBlock = genRangedLookup $script:derivedAgePath  ' *; (?<ver>[\d\.]+)' { "'$($matches['ver'])'" } "'Unassigned'"

    # initial parsing of Blocks.txt file
    #  (contains info about what named block a codepoint resides in)
    $script:blocksBlock = genRangedLookup $script:blocksPath  '; (?<block>[a-zA-Z0-9 \-]+)' { "'$($matches['block'])'" } "'Unassigned'"

    # initial parsing of Scripts.txt file
    #  (contains info about what script a codepoint is expressed in)
    $script:scriptsBlock = genRangedLookup $script:scriptsPath  ' *?; (?<script>[A-Za-z0-9_]+?) #' { "'$($matches['script'])'" } "'Unknown'"

    # initial parsing of LineBreak.txt file
    #  (contains info about line break behavior)
    $script:lineBreakBlock = genRangedLookup $script:lineBreakPath  ';(?<class>[A-Z]{2,3}) ' { "`$lineBreakMappings['$($matches['class'])']" } "`$lineBreakMappings['XX']"
}

function addCharData($data) {
    $data.pstypenames.Add('unishell.codepoint')
    $script:charData[$data.Codepoint] = $data
}

function getRange($code) {
    & $script:rangeBlock $code
}

function getAge($code) {
    & $script:ageBlock $code
}

function getBlock($code) {
    & $script:blocksBlock $code
}

function getScript($code) {
    & $script:scriptsBlock $code
}

function getLineBreak($code) {
    & $script:lineBreakBlock $code
}

function getEncodings($str) {
    $props = @{}
    foreach ($enc in $allEncodings) {
        $name = $enc.WebName
        if (-not $props.ContainsKey($name)) {
            $bytes = if ($str -eq $null) { ,@() } else { $enc.GetBytes($str) }
            $props.Add($name, [byte[]]$bytes)
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    foreach ($defaultEnc in $DefaultDisplayEncodings) {
        $null = $sb.Append($defaultEnc.PadRight($maxDefaultDisplayEncodingLength))
        $null = $sb.Append(' : ')
        $null = $sb.AppendLine((($props[$defaultEnc] | % { $_.ToString('X2') }) -join ' '))
    }
    if ($DefaultDisplayEncodings.Count -lt $allEncodings.Count) {
        $null = $sb.AppendLine('...')
    }
    $null = $sb.Remove($sb.Length - 1, 1)
    $toString = $sb.ToString()

    $result = [pscustomobject]$props
    $result.pstypenames.Add('unishell.encodings')
    $result | Add-Member -MemberType ScriptMethod -Name 'ToString' -Force -Value {
        $toString
    }.GetNewClosure()
    $result
}

function getChar($codepointName) {
    if (-not $script:charData.ContainsKey($codepointName)) {
        $code = [Convert]::ToInt32($codepointName.Substring(2), 16)
        if (($code -lt 0) -or ($code -gt 0x10ffff)) {
            Write-Error "$codepointName is not a valid codepoint"
            return
        }
        $value = if (($code -lt 55296) -or ($code -gt 57343)) {
            [char]::convertfromutf32($code)
        }
        else {
            $null
        }
        $fields = $script:stubData[$codepointName]

        if ($fields) {
            # format of UnicodeData.txt described at ftp://unicode.org/Public/3.0-Update/UnicodeData-3.0.0.html
            $name = $fields[1]
            if ($fields[10] -and ($fields[1] -like '<*>')) {
                $name = "$name $($fields[10])"
            }

            addCharData ([pscustomobject]@{
                    Value                     = $value
                    Codepoint                 = $codepointName.ToUpper()
                    Name                      = $name
                    Block                     = (getBlock $code)
                    Plane                     = plane $code
                    UnicodeVersion            = (getAge $code)
                    Script                    = (getScript $code)
                    LineBreakClass            = (getLineBreak $code)
                    Category                  = $generalCategoryMappings[$fields[2]]
                    CanonicalCombiningClasses = $combiningClassMappings[$fields[3]]
                    BidiCategory              = $bidiCategoryMappings[$fields[4]]
                    DecompositionMapping      = $fields[5]
                    DecimalDigitValue         = if ($fields[6]) { [int] $fields[6] } else {$null}
                    DigitValue                = $fields[7]
                    NumericValue              = $fields[8]
                    Mirrored                  = ($fields[9] -eq 'Y')
                    UppercaseMapping          = if ($fields[12]) { "U+" + $fields[12] } else { $null }
                    LowercaseMapping          = if ($fields[13]) { "U+" + $fields[13] } else { $null }
                    TitlecaseMapping          = if ($fields[14]) { "U+" + $fields[14] } else { $null }
                    Encodings                 = (getEncodings $value)
                })
        }
        else {
            $rangeCodepointName = getRange $code
            if ($rangeCodepointName) {
                $script:stubData[$codepointName] = $script:stubData[$rangeCodepointName]
                return (getChar $codepointName)
            }

            addCharData ([pscustomobject]@{
                    Value                     = $value
                    Codepoint                 = $codepointName.ToUpper()
                    Name                      = 'Unassigned'
                    Block                     = (getBlock $code)
                    Plane                     = (plane $code)
                    UnicodeVersion            = $null
                    Script                    = (getScript $code)
                    LineBreakClass            = (getLineBreak $code)
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
                    Encodings                 = (getEncodings $value)
                })
        }
    }

    $script:charData[$codepointName]
}

function expandString($inputString) {
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
        $codepointName = 'U+' + [Char]::ConvertToUtf32($inputString, $i).ToString('X4')
        $baseChar = (getChar $codepointName).PSObject.Copy()
        $isHS = [Char]::IsHighSurrogate($inputString[$i])

        $baseCurrent = $i -eq $elemStart
        $baseBefore = $i -gt 0
        $baseAfter = $idx -lt ($textElemPositions.Length - 1)

        $pointBefore = $i -gt $elemStart
        $pointAfter = ($i -lt ($elemEnd - 1)) -or (($i -eq ($elemEnd - 1)) -and !$isHS)

        $indicatorA = 
            if($baseCurrent -and $baseBefore -and $baseAfter){ ([char]0x251C) }
            elseif($baseCurrent -and $baseBefore -and !$baseAfter){ [char]0x2514 }
            elseif($baseCurrent -and !$baseBefore -and $baseAfter){ ([char]0x250C) }
            elseif($baseCurrent -and !$baseBefore -and !$baseAfter){ ([char]0x2500) }
            elseif(!$baseCurrent -and $baseBefore -and $baseAfter){ ([char]0x2502) }
            elseif(!$baseCurrent -and $baseBefore -and !$baseAfter){ " " }
            else { Write-Error "Unexpected $i $elemStart $elemEnd $idx $baseCurrent $baseBefore $baseAfter" }

        $indicatorB =
            if($pointBefore -and $pointAfter) { ([char]0x251C) }
            elseif($pointBefore -and !$pointAfter) { ([char]0x2514) }
            elseif(!$pointBefore -and $pointAfter) { ([char]0x252C) }
            else { ([char]0x2500) }

        $baseChar `
            | Add-Member -NotePropertyName '_Combiner' -NotePropertyValue "$indicatorA$indicatorB " -PassThru `
            | Add-Member -NotePropertyName '_OriginatingString' -NotePropertyValue $inputString -PassThru

        if ([Char]::IsHighSurrogate($inputString[$i])) {
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

function Get-UniCodepoint {
    [CmdletBinding(DefaultParameterSetName = 'string')]
    param(
        [Parameter(Mandatory = $true , ParameterSetName = 'string', Position = 0, ValueFromPipeline = $true)]
        [string[]] $InputString,
        [Parameter(Mandatory = $true, ParameterSetName = 'codepoint', Position = 0, ValueFromPipeline = $true)]
        [int[]] $Codepoint
    )

    begin {
        loadStub
    }

    process {
        if ($psCmdlet.ParameterSetName -eq 'codepoint') {
            foreach($c in $codepoint) {
                getChar "U+$($c.ToString('X4'))"
            }
        }
        elseif ($psCmdlet.ParameterSetName -eq 'string') {
            foreach ($s in $inputString) {
                expandString $s
            }
        }
    }
}

Export-ModuleMember -Function 'Get-UniCodepoint'