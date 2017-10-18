@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'UniShell'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = 'b5d960c9-cc36-44ab-9203-9d1105f792e7'

    # Author of this module
    Author            = 'Lincoln Atkinson'

    # Copyright statement for this module
    Copyright         = 'Lincoln Atkinson, 2017'

    # Description of the functionality provided by this module
    Description       = 'Cmdlets to aid with the visualization and exploration of Unicode strings and content'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Get-UniCodepoint', 'Get-UniByte', 'Get-UniString')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = $null

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @('unicode', 'unibytes', 'unistring')

    # List of all files packaged with this module
    FileList          = @('UniShell.psd1', 'unishell.psm1', 'lib.ps1', 'tables.ps1', 'unishell.format.template.xml')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('unicode', 'string', 'character', 'char', 'codepoint', 'encoding', 'encode', 'decoding', 'decode')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/latkin/unishell/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/latkin/unishell/'

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release'
        }
    }
}
