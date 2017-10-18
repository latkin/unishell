Set-StrictMode -Version 2
$errorActionPreference = 'Stop'

$scriptDir = Split-Path $psCommandPath

function test {
    param(
        [string] $name,
        [scriptblock]$sb
    )

    try {
        & $sb
    } catch {
        Write-Host -ForegroundColor Red "[$name] failed - $_"
        return
    }
    Write-Host -ForegroundColor Green "[$name] passed"
}

function ce {
    param(
        $expected,
        $actual
    )
    if(-not ($expected -eq $actual)){
        throw "Items were not equal. Expected [$expected] Actual [$actual]"
    }
}

function cm {
    param(
        $pattern,
        $actual
    )
    if(-not ($actual -match $pattern)){
        throw "Item did not match. [$actual] did not match pattern [$pattern]"
    }
}

function cnm {
    param(
        $pattern,
        $actual
    )
    if($actual -match $pattern){
        throw "Item matched unexpectedly. [$actual] matched pattern [$pattern]"
    }
}

function cae {
    param(
        [object[]] $expected,
        [object[]] $actual
    )

    if($expected.Length -ne $actual.Length){
        throw "Expected length $($expected.Length) does not match actual length $($actual.Length)"
    }
    for($i = 0; $i -lt $actual.length; $i++){
        ce $actual[$i] $expected[$i]
    }
}

Import-Module "$scriptDir/UniShell.psd1" -force

# Get-UniCodepoint core tests

test 'Get "X" codepoint' {
    $cp = Get-UniCodepoint 'X'
    ce 'X' $cp.RawValue
    ce 'X' $cp.Value
    ce 0x0058 $cp.Codepoint
    ce 'U+0058' $cp.CodepointString
    ce 'LATIN CAPITAL LETTER X' $cp.Name
    ce 'Basic Latin' $cp.Block
    ce '0 - Basic Multilingual Plane' $cp.Plane
    ce '1.1' $cp.UnicodeVersion
    ce 'Latin' $cp.Script
    ce 'AL - Alphabetic' $cp.LineBreakClass
    ce 'Lu - Letter, Uppercase' $cp.Category
    ce '0 - Spacing, split, enclosing, reordrant, and Tibetan subjoined' $cp.CanonicalCombiningClasses
    ce 'L - Left-to-Right' $cp.BidiCategory
    ce $false $cp.Mirrored
    ce 0x0078 $cp.LowercaseMapping
    cae @(0x58) $cp.'utf-8'
    cae @(0x58, 0x00) $cp.'utf-16'
    cae @(0x00, 0x58) $cp.'utf-16BE'
}

test 'Codepoint at unicodedata.txt range start' {
    $cp = Get-UniCodepoint 0x17000
    ce 0x17000 $cp.Codepoint
    ce 'Tangut Ideograph' $cp.Name
    ce '1 - Supplementary Multilingual Plane' $cp.Plane
}

test 'Codepoint at unicodedata.txt range end' {
    $cp = Get-UniCodepoint 0xFFFFD
    ce 0xFFFFD $cp.Codepoint
    ce 'Plane 15 Private Use' $cp.Name
    ce '15 - Supplementary Private Use Area-A' $cp.Plane
}

test 'Codepoint within unicodedata.txt range' {
    $cp = Get-UniCodepoint 0x21000
    ce 0x21000 $cp.Codepoint
    ce 'CJK Ideograph Extension B' $cp.Name
    ce '2 - Supplementary Ideographic Plane' $cp.Plane
}

test 'Unassigned codepoint' {
    $cp = Get-UniCodepoint 0x16E00
    ce 0x16E00 $cp.Codepoint
    ce 'Unassigned' $cp.Name
    ce 'Unassigned' $cp.Block
    ce '1 - Supplementary Multilingual Plane' $cp.Plane
    ce 'Unknown' $cp.Script
    ce 'XX - Unknown' $cp.LineBreakClass
    ce $null $cp.Category
    ce $null $cp.BidiCategory
    ce $null $cp.DecompositionMapping
    ce $null $cp.DecimalDigitValue
    ce $null $cp.DigitValue
    ce $null $cp.NumericValue
    ce $false $cp.Mirrored
    ce $null $cp.UppercaseMapping
    ce $null $cp.LowercaseMapping
    ce $null $cp.TitlecaseMapping
}

test 'Numeric codepoint' {
    $cp = Get-UniCodepoint 0x2181
    ce 0x2181 $cp.Codepoint
    ce 'ROMAN NUMERAL FIVE THOUSAND' $cp.Name
    ce "$([char]0x2181)" $cp.RawValue
    ce "$([char]0x2181)" $cp.Value
    ce 5000 $cp.NumericValue
}

test 'Digit codepoint' {
    $cp = Get-UniCodepoint 0xA8D5
    ce 0xA8D5 $cp.Codepoint
    ce 'SAURASHTRA DIGIT FIVE' $cp.Name
    ce "$([char]0xA8D5)" $cp.RawValue
    ce "$([char]0xA8D5)" $cp.Value
    ce 5 $cp.DecimalDigitValue
    ce 5 $cp.DigitValue
    ce 5 $cp.NumericValue
}

test "Isolated unpaired high surrogate" {
    $cp = Get-UniCodepoint 0xD801
    ce 0xD801 $cp.Codepoint
    ce "$([char]0xD801)" $cp.RawValue
    ce "$([char]0xD801)" $cp.Value
    ce 'High Surrogates' $cp.Block
    ce 'Non Private Use High Surrogate' $cp.Name
    ce 'SG - Surrogate' $cp.LineBreakClass
    ce 'Cs - Other, Surrogate' $cp.Category
}

test "Interpolated unpaired high surrogate" {
    $cp = Get-UniCodepoint "A$([char]0xD801)B"
    ce 3 $cp.length
    ce 0x0041 $cp[0].Codepoint
    ce 0xd801 $cp[1].Codepoint
    ce 0x0042 $cp[2].Codepoint
}

test "Isolated unpaired low surrogate" {
    $cp = Get-UniCodepoint 0xDC01
    ce 0xDC01 $cp.Codepoint
    ce "$([char]0xDC01)" $cp.RawValue
    ce 'Low Surrogates' $cp.Block
    ce 'Low Surrogate' $cp.Name
    ce 'SG - Surrogate' $cp.LineBreakClass
    ce 'Cs - Other, Surrogate' $cp.Category
}

test "Interpolated unpaired low surrogate" {
    $cp = Get-UniCodepoint "A$([char]0xDC01)B"
    ce 3 $cp.length
    ce 0x0041 $cp[0].Codepoint
    ce 0xDC01 $cp[1].Codepoint
    ce 0x0042 $cp[2].Codepoint
}

test "Jumbled isolated surrogates" {
    $hi = [char]0xD802
    $lo = [char]0xDC02
    $cp = Get-UniCodepoint "$lo$lo $hi$hi $lo$hi"
    ce 8 $cp.length
    cae @(0xdc02,0xdc02,0x0020,0xd802,0xd802,0x0020,0xdc02,0xd802) $cp.Codepoint
}
# Get-UniCodepoint formatting tests

test "Combiners for simple latin string" {
    $cp = 'abc' | Get-UniCodepoint
    ce '┌─' $cp[0]._Combiner
    ce '├─' $cp[1]._Combiner
    ce '└─' $cp[2]._Combiner
}

test "Combiners for simple latin single char" {
    $cp = 'a' | Get-UniCodepoint
    ce '──' $cp._Combiner
}

test "Combiners for combined chars at start, more chars after" {
    $cp = "a$([char]0x0301)$([char]0x0307)b" | Get-UniCodepoint
    ce '┌┬' $cp[0]._Combiner
    ce '│├' $cp[1]._Combiner
    ce '│└' $cp[2]._Combiner
}

test "Combiners for combined chars at start, no chars after" {
    $cp = "a$([char]0x0301)$([char]0x0307)" | Get-UniCodepoint
    ce '─┬' $cp[0]._Combiner
    ce ' ├' $cp[1]._Combiner
    ce ' └' $cp[2]._Combiner
}

test "Combiners for combined chars after start, more chars after" {
    $cp = "xa$([char]0x0301)$([char]0x0307)b" | Get-UniCodepoint
    ce '├┬' $cp[1]._Combiner
    ce '│├' $cp[2]._Combiner
    ce '│└' $cp[3]._Combiner
}

test "Combiners for combined chars after start, no chars after" {
    $cp = "xa$([char]0x0301)$([char]0x0307)" | Get-UniCodepoint
    ce '└┬' $cp[1]._Combiner
    ce ' ├' $cp[2]._Combiner
    ce ' └' $cp[3]._Combiner
}

test "per-codepoint display values" {
    $cp = Get-UniCodepoint 0x007f
    ce ([char]0x2421) $cp.Value
    
    $cp = Get-UniCodepoint 0x83
    ce 'NBH' $cp.Value
    
    $cp = Get-UniCodepoint 0x2066
    ce 'LRI' $cp.Value
    
    $cp = Get-UniCodepoint 0xFFFB
    ce 'IAT' $cp.Value
    
    $cp = Get-UniCodepoint 0xE0001
    ce 'LANG TAG' $cp.Value
    
    $cp = Get-UniCodepoint 0xE0020
    ce "TAG $([char]0x2420)" $cp.Value

    $cp = Get-UniCodepoint 0xE007F
    ce "TAG $([char]0x0018)" $cp.Value
}

test "c0 control display values" {
    $cp = Get-UniCodepoint 0x00
    ce ([char]0x2400) $cp.Value

    $cp = Get-UniCodepoint 0x1f
    ce ([char]0x241f) $cp.Value
}

test "tag control display values" {
    $cp = Get-UniCodepoint 0xE0021
    ce 'Tag !' $cp.Value

    $cp = Get-UniCodepoint 0xE007E
    ce 'Tag ~' $cp.Value
}

test "mongolian free variation selector display values" {
    $cp = Get-UniCodepoint 0x180B
    ce 'FVS1' $cp.Value

    $cp = Get-UniCodepoint 0x180D
    ce 'FVS3' $cp.Value
}

test "variation selector display values" {
    $cp = Get-UniCodepoint 0xFE00
    ce 'VS1' $cp.Value

    $cp = Get-UniCodepoint 0xFE0F
    ce 'VS16' $cp.Value
}

test "supplemental variation selector display values" {
    $cp = Get-UniCodepoint 0xE0100
    ce 'VS17' $cp.Value

    $cp = Get-UniCodepoint 0xE01EF
    ce 'VS256' $cp.Value
}

test "Display value used in table formatting" {
    $output = Get-UniCodepoint 0x00 | Out-String
    cm ([char]0x2400) $output
    cnm ([char]0x00) $output
}

test "Display value used in list formatting" {
    $output = Get-UniCodepoint 0x00  | fl | Out-String
    cm "Value +: $([char]0x2400)" $output
    cnm ([char]0x00) $output
}

test "Bytes formatted as space-delimited hex" {
    $output = "a$([char]0x0322)" | Get-UniCodepoint | Out-string
    cm '\s61 00\s' $output
    cm '\sCC A2\s+22 03\s' $output
}

test "Specified encodings are added to default table output" {
    $output = "a$([char]0x0322)" | Get-UniCodepoint -encoding utf-32, utf-16BE | Out-string
    cm '  61 00 00 00\s+00 61  ' $output
    cm '  22 03 00 00 +03 22  ' $output
}

test "Specified encodings are added to default list output" {
    $output = "a$([char]0x0322)" | Get-UniCodepoint -encoding utf-32, utf-16BE | fl | Out-string
    cm '\r?\nutf-32 +: 61 00 00 00\r?\n' $output
    cm '\r?\nutf-16BE +: 00 61\r?\n' $output
}

test "Not-specified encodings are not added to default list output" {
    $output = "a$([char]0x0322)" | Get-UniCodepoint -encoding utf-32 | fl | Out-string
    cnm 'utf-8' $output
    cnm 'utf-16' $output
}

test "Hidden fields are not shown in default list output" {
    $output = "abc" | Get-UniCodepoint | fl | Out-string
    cnm '_Combiner' $output
    cnm '_OriginatingString' $output
}

# Get-UniByte tests

test "Pass a string, default encoding" {
    $b = 'test' | Get-UniByte
    cae @(116, 101, 115, 116) $b
}

test "Pass a string, custom encoding" {
    $b = 'test' | Get-UniByte -E utf-16BE
    cae @(0, 116, 0, 101, 0, 115, 0, 116) $b
}

test "Pass codepoints, default encoding" {
    $b = 'test' | Get-UniCodepoint | Get-UniByte
    cae @(116, 101, 115, 116) $b
}

test "Pass codepoints, custom encoding" {
    $b = 'test' | Get-UniCodepoint | Get-UniByte -E utf-16BE
    cae @(0, 116, 0, 101, 0, 115, 0, 116) $b
}

# Get-UniString tests

test "Simple latin string, pass as bytes" {
    $s = Get-UniString -Bytes 116, 101, 115, 116
    ce 'test' $s
}

test "Simple latin string, pass a codepoints" {
    $s = 116, 101, 115, 116 | Get-UniString
    ce 'test' $s
}

test "Simple latin string, pass as bytes with custom encoding" {
    $s = 116, 0, 101, 0, 115, 0, 116, 0 | Get-UniString -enc utf-16
    ce 'test' $s
}

test "Codepoints larger than byte max" {
    $s = 109, 101, 104, 32, 129335 | Get-UniString
    ce 'meh 🤷' $s

    $s = 'meh 🤷' | Get-UniCodepoint | Get-UniString
    ce 'meh 🤷' $s
}


# module-level tests
test "module import can download data files" {
    $files = @('UnicodeData','DerivedAge','Blocks','Scripts','LineBreak')
    $files |%{  Remove-Item "$scriptDir/$_.txt" -ea 0 }

    Import-Module "$scriptDir/UniShell.psd1" -force -ArgumentList ($scriptDir, @('utf-8'), $true)

    $files |%{ 
        if(-not (Test-path "$scriptDir/$_.txt")){
            throw "Expected to find file $_.txt downloaded"
        }
    }
}
