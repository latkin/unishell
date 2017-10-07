param(
    $UnicodeDataPath,
    $CodepointDisplayFields = @('Value','Codepoint','Name','ASCII','ISO88591','UTF8','UTF16')
)

$scriptDir = Split-Path $psCommandPath

if (-not $UnicodeDataPath) {
    $UnicodeDataPath = Join-Path $scriptDir 'UnicodeData.txt'
}
if (-not (Test-Path $UnicodeDataPath)) {
    Write-Error "Cannot find Unicode data file at $unicodeDataPath"
    exit
} 

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

function plane($code) {
    if($code -lt 0) { Write-Error "Invalid codepoint" }
    elseif($code -le 0xFFFF){ 'Basic Multilingual Plane' }
    elseif($code -le 0x1FFFF) { 'Supplementary Multilingual Plane'}
    elseif($code -le 0x2FFFF) { 'Supplementary Ideographic Plane' }
    elseif($code -le 0x3FFFF) { 'Tertiary Ideographic Plane' }
    elseif($code -le 0x4FFFF) { 'Plane 5 (unassigned)' }
    elseif($code -le 0x5FFFF) { 'Plane 6 (unassigned)' }
    elseif($code -le 0x6FFFF) { 'Plane 7 (unassigned)' }
    elseif($code -le 0x7FFFF) { 'Plane 8 (unassigned)' }
    elseif($code -le 0x8FFFF) { 'Plane 9 (unassigned)' }
    elseif($code -le 0x9FFFF) { 'Plane 10 (unassigned)' }
    elseif($code -le 0xAFFFF) { 'Plane 11 (unassigned)' }
    elseif($code -le 0xBFFFF) { 'Plane 12 (unassigned)' }
    elseif($code -le 0xCFFFF) { 'Plane 13 (unassigned)' }
    elseif ($code -le 0xDFFFF) { 'Plane 14 (unassigned)' }
    elseif ($code -le 0xEFFFF) { 'Supplementary Special-purpose Plane' }
    elseif ($code -le 0xFFFFF) { 'Supplementary Private Use Area - A' }
    elseif ($code -le 0x10FFFF) { 'Supplementary Private Use Area - B'}
    else { Write-Error "Invalid codepoint" }
}

$defaultDisplayFields = @{
    codepoint = $CodepointDisplayFields
}

function updateFormatting {
    $content = $(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<Configuration><ViewDefinitions>'
        $defaultDisplayFields.Keys |%{
            "<View>"
            "<Name>$_</Name><ViewSelectedBy><TypeName>unishell.$_</TypeName></ViewSelectedBy>"
            "<TableControl><TableHeaders>"
            $defaultDisplayFields[$_] |%{ "<TableColumnHeader><Label>$_</Label></TableColumnHeader>" }
            "</TableHeaders><TableRowEntries><TableRowEntry><TableColumnItems>"
            $defaultDisplayFields[$_] |%{ "<TableColumnItem><PropertyName>$_</PropertyName></TableColumnItem>" }
            "</TableColumnItems></TableRowEntry></TableRowEntries></TableControl>"
            "</View>"
        }
        '</ViewDefinitions></Configuration>'
    )

    $path = Join-Path $scriptDir 'unishell.format.ps1xml'
    $content | Out-File $path -Encoding ascii

    Update-FormatData -AppendPath $path
    Update-FormatData
}

updateFormatting

$stubData = @{}
$charData = @{}
function loadStub {
    # bail if already initialized
    if ($script:stubData.Count -ne 0) {
        return
    }

    $lines = [System.IO.File]::ReadAllLines((Resolve-Path $script:unicodeDataPath).Path, [System.Text.Encoding]::UTF8)
    foreach ($line in $lines) {
        $i = $line.IndexOf(';')
        $codepointName = 'U+' + $line.SubString(0, $i)
        $script:stubData[$codepointName] = $line
    }
}

function addCharData($data) {
    $data.pstypenames.Add('unishell.codepoint')
    $script:charData[$data.Codepoint] = $data
}

function getChar($codepointName) {
    if (-not $script:charData.ContainsKey($codepointName)) {
        $stubString = $script:stubData[$codepointName]
        if ($stubString) {
            # format of UnicodeData.txt described at ftp://unicode.org/Public/3.0-Update/UnicodeData-3.0.0.html
            $fields = $stubString.Split(';')

            $code = [Convert]::ToInt32($fields[0], 16)

            $value = if (($code -lt 55296) -or ($code -gt 57343)) {
                [char]::convertfromutf32($code)
            }
            else {
                $null
            }

            $name = $fields[1]
            if ($fields[10]) {
                $name = "$name $($fields[10])"
            }

            addCharData ([pscustomobject]@{
                Value                     = $value
                Codepoint                 = $codepointName
                Name                      = $name
                Category                  = $generalCategoryMappings[$fields[2]]
                CanonicalCombiningClasses = $combiningClassMappings[$fields[3]]
                BidiCategory              = $bidiCategoryMappings[$fields[4]]
                DecompositionMapping      = $fields[5]
                DecimalDigitValue         = if ($fields[6]) { [int] $fields[6] } else {$null}
                DigitValue                = $fields[7]
                NumericValue              = $fields[8]
                Mirrored                  = ($fields[9] -eq 'Y')
                Plane                     = plane $code
                UppercaseMapping          = if ($fields[12]) { "U+" + $fields[12] } else { $null }
                LowercaseMapping          = if ($fields[13]) { "U+" + $fields[13] } else { $null }
                TitlecaseMapping          = if ($fields[14]) { "U+" + $fields[14] } else { $null }

                ASCII                     = [byte[]]@(if ($value) { [System.Text.Encoding]::ASCII.GetBytes($value) } else { $null })
                ISO88591                  = [byte[]]@(if ($value) { [System.Text.Encoding]::GetEncoding(28591).GetBytes($value) } else { $null })
                UTF8                      = [byte[]]@(if ($value) { [System.Text.Encoding]::UTF8.GetBytes($value) } else { $null })
                UTF16                     = [byte[]]@(if ($value) { [System.Text.Encoding]::Unicode.GetBytes($value) } else { $null })
            })

            $script:stubData.Remove($codepointName)
        }
        else {
            $code = [Convert]::ToInt32($codepointName.Substring(2), 16)
            addCharData ([pscustomobject]@{
                Value                     = $null
                Codepoint                 = $codepointName
                Name                      = 'Unknown'
                Category                  = $null
                CanonicalCombiningClasses = $null
                BidiCategory              = $null
                DecompositionMapping      = $null
                DecimalDigitValue         = $null
                DigitValue                = $null
                NumericValue              = $null
                Mirrored                  = $false
                Plane                     = plane $code
                UppercaseMapping          = $null
                LowercaseMapping          = $null
                TitlecaseMapping          = $null

                ASCII                     = $null
                ISO88591                  = $null
                UTF8                      = $null
                UTF16                     = $null
            })
        }
    }

    $script:charData[$codepointName]
}

function Expand-UniString {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string] $InputString
    )

    $codePoints = $(
        for ($i = 0; $i -lt $inputString.Length; $i++) {
            [Char]::ConvertToUtf32($inputString, $i)
            if ([Char]::IsHighSurrogate($inputString[$i])) {
                $i++
            }
        }
    )

    loadStub

    $codepoints | % {
        getChar "U+$($_.ToString('X4'))"
    }
}

Export-ModuleMember -Function 'Expand-UniString'