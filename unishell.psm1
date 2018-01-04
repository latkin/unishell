param(
    $DataFilesDirectory,
    $DefaultDisplayEncodings = @('utf-8', 'utf-16'),
    $AutoDownloadDataFiles
)

$scriptDir = Split-Path $psCommandPath

if (-not $dataFilesDirectory) {
    $dataFilesDirectory = $scriptDir
}

. $scriptDir/lib.ps1 -datafilesdirectory $dataFilesDirectory
if (-not $?) { exit }

<#
.SYNOPSIS
Gets Unicode codepoint information from an input string or list of integer codepoints.

.DESCRIPTION
Gets Unicode codepoint information from an input string or list of integer codepoints.
Returned items each represent a single Unicode codepoint, and carry information
about various properties and binary encodings of the codepoint.
All properties are sourced from public Unicode Consortium data files.

By default, codepoints are displayed in TABLE format and display only a few properties.
To see all available information about a codepoint, pipe output to Format-List to
view it in LIST format.

.PARAMETER InputString
Specifies the string that will be decomposed into its constituent codepoints.

.PARAMETER Codepoint
Specifies explicitly the integer codepoints that will be returned.

.PARAMETER Encoding
Specifies the subset of available encodings which will be displayed.

By default, utf-8 and utf-16 encodings are displayed. Note that all encodings
are always available on the returned items, even if they are not displayed by default.
Use "Format-List *" to force-display all encodings.

.PARAMETER NoEncoding
If specified, no encodings will be displayed in the cmdlet output.

.EXAMPLE
# display codepoints of a simple Latin string
Get-UniCodepoint 'Dude'

Dude

  Codepoint Name                          utf-8       utf-16 Value
  --------- ----                          -----       ------ -----
┌─   U+0044 LATIN CAPITAL LETTER D           44        44 00   D
├─   U+0075 LATIN SMALL LETTER U             75        75 00   u
├─   U+0064 LATIN SMALL LETTER D             64        64 00   d
└─   U+0065 LATIN SMALL LETTER E             65        65 00   e

.EXAMPLE
# display codepoints of a more interesting string
'(͡° ͜ʖ ͡°)' | Get-UniCodepoint

(͡° ͜ʖ ͡°)

  Codepoint Name                                      utf-8       utf-16 Value
  --------- ----                                      -----       ------ -----
┌┬   U+0028 LEFT PARENTHESIS                             28        28 00   (
│└   U+0361 COMBINING DOUBLE INVERTED BREVE           CD A1        61 03   ͡
├─   U+00B0 DEGREE SIGN                               C2 B0        B0 00   °
├┬   U+0020 SPACE                                        20        20 00
│└   U+035C COMBINING DOUBLE BREVE BELOW              CD 9C        5C 03   ͜
├─   U+0296 LATIN LETTER INVERTED GLOTTAL STOP        CA 96        96 02   ʖ
├┬   U+0020 SPACE                                        20        20 00
│└   U+0361 COMBINING DOUBLE INVERTED BREVE           CD A1        61 03   ͡
├─   U+00B0 DEGREE SIGN                               C2 B0        B0 00   °
└─   U+0029 RIGHT PARENTHESIS                            29        29 00   )

.EXAMPLE
# display codepoints based on explicit integer codepoint values
0x1f480..0x1f485 | Get-UniCodepoint

Codepoint Name                           utf-8       utf-16 Value
--------- ----                           -----       ------ -----
  U+1F480 SKULL                    F0 9F 92 80  3D D8 80 DC  💀  
  U+1F481 INFORMATION DESK PERSON  F0 9F 92 81  3D D8 81 DC  💁  
  U+1F482 GUARDSMAN                F0 9F 92 82  3D D8 82 DC  💂  
  U+1F483 DANCER                   F0 9F 92 83  3D D8 83 DC  💃  
  U+1F484 LIPSTICK                 F0 9F 92 84  3D D8 84 DC  💄  
  U+1F485 NAIL POLISH              F0 9F 92 85  3D D8 85 DC  💅  

.EXAMPLE
# display other encodings
'señor' | Get-UniCodepoint -Encoding iso-8859-1,utf-16BE,utf-8

señor

  Codepoint Name                              iso-8859-1     utf-16BE        utf-8 Value
  --------- ----                              ----------     --------        ----- -----
┌─   U+0073 LATIN SMALL LETTER S                      73        00 73           73   s  
├─   U+0065 LATIN SMALL LETTER E                      65        00 65           65   e  
├─   U+00F1 LATIN SMALL LETTER N WITH TILDE           F1        00 F1        C3 B1   ñ  
├─   U+006F LATIN SMALL LETTER O                      6F        00 6F           6F   o  
└─   U+0072 LATIN SMALL LETTER R                      72        00 72           72   r  

.EXAMPLE
# display no encodings
'señor' | Get-UniCodepoint -NoEncoding

señor

  Codepoint Name                            Value
  --------- ----                            -----
┌─   U+0073 LATIN SMALL LETTER S              s
├─   U+0065 LATIN SMALL LETTER E              e
├─   U+00F1 LATIN SMALL LETTER N WITH TILDE   ñ
├─   U+006F LATIN SMALL LETTER O              o
└─   U+0072 LATIN SMALL LETTER R              r

.EXAMPLE
# view full details of a codepoint by viewing in list format
0x0414 | Get-UniCodepoint | Format-List


Value                     : Д
Codepoint                 : U+0414
Name                      : CYRILLIC CAPITAL LETTER DE
Block                     : Cyrillic
Plane                     : 0 - Basic Multilingual Plane
UnicodeVersion            : 1.1
Script                    : Cyrillic
LineBreakClass            : AL - Alphabetic
Category                  : Lu - Letter, Uppercase
CanonicalCombiningClasses : 0 - Spacing, split, enclosing, reordrant, and Tibetan subjoined
BidiCategory              : L - Left-to-Right
DecompositionMapping      : 
DecimalDigitValue         : 
DigitValue                : 
NumericValue              : 
Mirrored                  : False
UppercaseMapping          : 
LowercaseMapping          : U+0434
TitlecaseMapping          : 
utf-8                     : D0 94
utf-16                    : 14 04
#>
function Get-UniCodepoint {
    [CmdletBinding(DefaultParameterSetName = 'string-encoding')]
    param(
        [Parameter(Mandatory = $true , ParameterSetName = 'string-encoding', Position = 0, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true , ParameterSetName = 'string-noencoding', Position = 0, ValueFromPipeline = $true)]
        [string[]] $InputString,
        [Parameter(Mandatory = $true, ParameterSetName = 'codepoint-encoding', Position = 0, ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'codepoint-noencoding', Position = 0, ValueFromPipeline = $true)]
        [int[]] $Codepoint,
        [Parameter(ParameterSetName = 'string-encoding')]
        [Parameter(ParameterSetName = 'codepoint-encoding')]
        [string[]] $Encoding,
        [Parameter(Mandatory = $true, ParameterSetName = 'string-noencoding')]
        [Parameter(Mandatory = $true, ParameterSetName = 'codepoint-noencoding')]
        [switch] $NoEncoding
    )

    begin {
        loadStub
        $changedFormatting = $false
        if ($encoding) {
            $displayEncodings = resolveEncodings $encoding -ErrorAction Stop | ForEach-Object WebName
            updateFormatting $displayEncodings
            $changedFormatting = $true
        }

        if ($noEncoding -or $($null -ne $encoding -and $encoding.Length -eq 0)) {
            $displayEncodings = @()
            updateFormatting $displayEncodings
            $changedFormatting = $true
        }
    }

    process {
        if ($psCmdlet.ParameterSetName -match 'codepoint') {
            foreach ($c in $codepoint) {
                getChar $c
            }
        }
        elseif ($psCmdlet.ParameterSetName -match 'string') {
            foreach ($s in $inputString) {
                expandString $s
            }
        }
    }

    end {
        if ($changedFormatting) {
            updateFormatting $script:defaultDisplayEncodings
        }
    }
}

<#
.SYNOPSIS
Gets the bytes associated with a binary encoding of the specified Unicode
string or codepoints.

.DESCRIPTION
Gets the bytes associated with a binary encoding of the specified Unicode
string or codepoints.

UTF-8 encoding is used by default, but any available encoding is supported.

.PARAMETER InputString
Specifies the string whose encoded bytes will be returned.

.PARAMETER Codepoint
Specifies a sequence of integer Unicode codepoints whose encoded bytes will be returned.

This parameter can be populated via raw integers or by piping output from Get-UniCodepoint.

.PARAMETER Encoding
Specifies the encoding to use when converting the input string or codepoints to bytes.

UTF-8 is used by default.

.EXAMPLE
# get the encoded bytes of a simple Latin string
Get-UniByte 'Sweet'

83
119
101
101
116

.EXAMPLE
# get the UTF-16 bytes of the Mandarin word 筷子
'筷子' | Get-UniByte -Encoding utf-16

119
123
80
91

.EXAMPLE
# get the bytes of an integer codepoint
0x1F937 | Get-UniByte -Encoding utf-32

55
249
1
0
#>
function Get-UniByte {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'string')]
        [string[]]$InputString,
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'codepoint')]
        [int[]] $Codepoint,
        [string] $Encoding = 'utf-8'
    )

    begin {
        $encodingImpl = resolveEncodings $Encoding -ErrorAction Stop
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'string') {
            foreach ($s in $inputString) {
                $encodingImpl.GetBytes($s)
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'codepoint') {
            foreach ($c in $codepoint) {
                $value = getValue $c
                if ($value -eq $null) { return }

                $encodingImpl.GetBytes($value)
            }
        }
    }
}

<#
.SYNOPSIS
Gets the string generated by decoding the input bytes according to the specified
encoding, or by combining the specified codepoints.

.DESCRIPTION
Gets the string generated by decoding the input bytes according to the specified
encoding, or by combining the specified codepoints.

When specifying bytes, UTF-8 encoding is used by default.

.PARAMETER Bytes
Specifies the bytes that will be decoded to generate the resulting string.

.PARAMETER Encoding
Specifies the encoding that will be used to decode the input bytes.

UTF-8 encoding is used by default.

.PARAMETER Codepoint
Specifies the integer codepoints that will be combined to generate the resulting string.

This parameter can be populated via raw integers or by piping output from Get-UniCodepoint.

.EXAMPLE
# decode a simple Latin word based on its UTF-8 bytes
83, 119, 101, 101, 116 | Get-UniString

Sweet

.EXAMPLE
# decode a Mandarin word based on its UTF-16 bytes
119, 123, 80, 91 | Get-UniString -Encoding utf-16

筷子

.EXAMPLE
# combine codepoints to form a string
Get-UniString -Codepoint 0x6d,0x65,0x68,0x20,0x1f937
0x6d,0x65,0x68,0x20,0x1f937 | Get-UniString -Codepoint {$_}

meh 🤷

.EXAMPLE
# discover conspiracies!
'畂桳栠摩琠敨映捡獴' | Get-UniByte -Encoding utf-16 | Get-UniString -Encoding utf-8

Bush hid the facts
#>
function Get-UniString {
    [CmdletBinding(DefaultParameterSetName = 'bytes')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'bytes')]
        [byte[]]$Bytes,
        [Parameter(ParameterSetName = 'bytes')]
        [string] $Encoding = 'utf-8',
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'codepoint')]
        [int[]] $Codepoint
    )

    begin {
        $byteBuffer = New-Object 'System.Collections.Generic.List[byte]'
        $sb = [System.Text.StringBuilder]::new()
        if ($Encoding) {
            $encodingImpl = resolveEncodings $Encoding
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'bytes') {
            foreach ($b in $bytes) {
                $byteBuffer.Add($b)
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'codepoint') {
            foreach ($c in $codepoint) {
                $value = getValue $c
                if ($value -eq $null) { return }
                $null = $sb.Append($value)
            }
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'bytes') {
            $encodingImpl.GetString($byteBuffer.ToArray())
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'codepoint') {
            $sb.ToString()
        }
    }
}

# tab completion through all available encodings for 'Encoding' arg on all relevant cmdlets
if (Get-Command 'Register-ArgumentCompleter' -ea 0) {
    Register-ArgumentCompleter -CommandName 'Get-UniCodepoint', 'Get-UniByte', 'Get-UniString' -ParameterName 'Encoding' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

        # maintain quotes if user has added them
        $quote = $null
        if ($wordToComplete -match "^(`"|')") {
            $quote = $matches[1]
            $wordToComplete = $wordToComplete -replace "^(`"|')+"
        }
        $wordToComplete = $wordToComplete -replace "(`"|')+$"

        resolveEncodings "$wordToComplete*" | ForEach-Object WebName | ForEach-Object {
            $localQuote =
                if ($quote) { $quote }
                elseif ($_ -match '\s') { "'" }
                else { $null }
            "$localQuote$_$localQuote"
        }
    }
}

New-Alias unicode Get-UniCodepoint
New-Alias unibyte Get-UniByte
New-Alias unistring Get-UniString

Export-ModuleMember `
    -Function 'Get-UniCodepoint','Get-UniByte','Get-UniString' `
    -Alias 'unicode','unibyte','unistring'