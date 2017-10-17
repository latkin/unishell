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

function Get-UniCodepoint {
    [CmdletBinding(DefaultParameterSetName = 'string')]
    param(
        [Parameter(Mandatory = $true , ParameterSetName = 'string', Position = 0, ValueFromPipeline = $true)]
        [string[]] $InputString,
        [Parameter(Mandatory = $true, ParameterSetName = 'codepoint', Position = 0, ValueFromPipeline = $true)]
        [int[]] $Codepoint,
        [string[]] $Encoding
    )

    begin {
        loadStub
        $changedFormatting = $false
        if ($encoding) {
            $displayEncodings = $encoding | % { $allEncodings.WebName -like $_ } | Select-Object -Unique
            if (-not $displayEncodings) {
                Write-Warning "$encoding does not match any available encodings"
                return
            }
            else {
                updateFormatting $displayEncodings
                $changedFormatting = $true
            }
        }
    }

    process {
        if ($psCmdlet.ParameterSetName -eq 'codepoint') {
            foreach ($c in $codepoint) {
                getChar $c
            }
        }
        elseif ($psCmdlet.ParameterSetName -eq 'string') {
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

function Get-UniBytes {
    param(
        [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'string')]
        [string[]]$InputString,
        [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'codepoint')]
        [pscustomobject[]] $Codepoint,
        [string] $Encoding = 'utf-8'
    )
    begin {
        $encodingImpl = $allEncodings |? WebName -eq $Encoding
        if(-not $encodingImpl){
            Write-Error "Encoding $encoding not available"
            return
        }
    }
    process {
        if($PSCmdlet.ParameterSetName -eq 'string'){
            foreach($s in $inputString){
                if($encodingImpl){
                    $encodingImpl.GetBytes($s)
                }
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'codepoint') {
            foreach($c in $codepoint){
                if($c.PSObject.typenames.contains('unishell.codepoint')){
                    $c.$encoding
                }
            }
        }
    }
}

function Get-UniString {
    [CmdletBinding(DefaultParameterSetName = 'bytes')]
    param(
        [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'bytes')]
        [byte[]]$Bytes,
        [Parameter(ParameterSetName = 'bytes')]
        [string] $Encoding = 'utf-8',
        [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'codepoint')]
        [pscustomobject[]] $Codepoint
    )
    begin {
        $byteBuffer = New-Object 'System.Collections.Generic.List[byte]'
        $sb = [System.Text.StringBuilder]::new()
        $encodingImpl = $allEncodings |? WebName -eq $Encoding
        if((-not $encodingImpl) -and ($psCmdlet.ParameterSetName -eq 'bytes')){
            Write-Error "Encoding $encoding not available"
            return
        }
    }
    process {
        if($PSCmdlet.ParameterSetName -eq 'bytes'){
            foreach($b in $bytes) {
                $byteBuffer.Add($b)
            }
        } elseif($PSCmdlet.ParameterSetName -eq 'codepoint'){
            foreach($c in $codepoint) {
                $null = $sb.Append($c.Value)
            }
        }
    }
    end {
        if($PSCmdlet.ParameterSetName -eq 'bytes'){
            $encodingImpl.GetString($byteBuffer.ToArray())
        } elseif($PSCmdlet.ParameterSetName -eq 'codepoint'){
            $sb.ToString()
        }
    }
}

if (Get-Command 'Register-ArgumentCompleter' -ea 0) {
    Register-ArgumentCompleter -CommandName 'Get-UniCodepoint','Get-UniBytes','Get-UniString' -ParameterName 'Encoding' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

        $quote = $null
        if ($wordToComplete -match "^(`"|')") {
            $quote = $matches[1]
            $wordToComplete = $wordToComplete -replace "^(`"|')+"
        }
        $wordToComplete = $wordToComplete -replace "(`"|')+$"

        $script:allEncodings |? WebName -like "$wordToComplete*" | % WebName | % {
            $localQuote =
                if ($quote) { $quote }
                elseif ($_ -match '\s') { "'" }
                else { $null }
            "$localQuote$_$localQuote"
        }
    }
}

New-Alias unicode Get-UniCodepoint
New-Alias unibytes Get-UniBytes
New-Alias unistring Get-UniString

Export-ModuleMember `
    -Function 'Get-UniCodepoint','Get-UniBytes','Get-UniString' `
    -Alias 'unicode','unibytes','unistring'