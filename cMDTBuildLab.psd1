@{

# Script module or binary module file associated with this manifest.
RootModule = 'cMDTBuildLab.psm1'

DscResourcesToExport = @('cMDTBuildApplication','cMDTBuildBootstrapIni','cMDTBuildCustomize','cMDTBuildCustomSettingsIni','cMDTBuildDirectory','cMDTBuildOperatingSystem','cMDTBuildPackage','cMDTBuildPersistentDrive','cMDTBuildPreReqs','cMDTBuildSelectionProfile','cMDTBuildTaskSequence','cMDTBuildTaskSequenceCustomize','cMDTBuildUpdateBootImage')

#CmdletsToExport     = @('Import-MicrosoftDeploymentToolkitModule','Invoke-ExpandArchive','Invoke-RemovePath','Invoke-TestPath')
FunctionsToExport  = @('Import-MicrosoftDeploymentToolkitModule','Invoke-ExpandArchive','Invoke-RemovePath','Invoke-TestPath')

# Version number of this module.
ModuleVersion = '0.6.0'

# ID used to uniquely identify this module
GUID = 'df45de26-88b1-4a95-98af-b798fde1424f'

# Author of this module
Author = 'Pavel Andreev'

# Company or vendor of this module
CompanyName = ''

# Copyright statement for this module
Copyright = '(c) 2016 Pavel Andreev. All rights reserved.'

# Description of the functionality provided by this module
Description = 'A DSC Module to help automize deployment Windows Reference Images on MDT Server'

# Project site link
HelpInfoURI = 'https://github.com/pvs043/cMDTBuildLab'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @({ModuleName="xSmbShare"}, {ModuleName="cNtfsAccessControl"})

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('DesiredStateConfiguration', 'DSC', 'DSCResource', 'MDT', 'Deploy')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/pvs043/cMDTBuildLab/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/pvs043/cMDTBuildLab'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '
 * Implemented oflline remove Windows 8.1/10 default applications
 * Remove .NET Framework 3.5 dependency
 * Fix bug with Configure Keyboard Toggle
 * Add Telnet client for Windows 2016
 * Add Configure Firewall Rules Application
 * Prompt password for MDTLocalAccount at configuration
'
    } # End of PSData hashtable

} # End of PrivateData hashtable

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''
}
