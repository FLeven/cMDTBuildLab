enum Ensure
{
    Absent
    Present
}

[DscResource()]
class cMDTBuildApplication
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Key)]
    [string]$Path

	[DscProperty(Mandatory)]
    [string]$Enabled
    
	[DscProperty(Mandatory)]
    [string]$CommandLine
    
    [DscProperty(Mandatory)]
    [string]$ApplicationSourcePath
    
    [DscProperty(Mandatory)]
    [string]$PSDriveName

    [DscProperty(Mandatory)]
    [string]$PSDrivePath

    [void] Set()
    {
        if ($this.ensure -eq [Ensure]::Present) {
            $present = Invoke-TestPath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath
            if ( !$present ) {
                $this.ImportApplication()
            }
        }
        else {   
            Invoke-RemovePath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
        }
    }

    [bool] Test()
    {
        $present = Invoke-TestPath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath 

        if ($this.Ensure -eq [Ensure]::Present) {
            return $present
        }
        else {
            return -not $present
        }
    }

    [cMDTBuildApplication] Get()
    {
        return $this
    }

    [void] ImportApplication()
    {
        Import-MicrosoftDeploymentToolkitModule
        New-PSDrive -Name $this.PSDriveName -PSProvider "MDTProvider" -Root $this.PSDrivePath -Verbose:$false
        Import-MDTApplication -Path $this.Path -Enable $this.Enabled -Name $this.Name -ShortName $this.Name `
                              -CommandLine $this.CommandLine -WorkingDirectory ".\Applications\$($this.Name)" `
                              -ApplicationSourcePath $this.ApplicationSourcePath -DestinationFolder $this.Name -Verbose
    }
}

[DscResource()]
class cMDTBuildBootstrapIni
{

    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [string]$Path

    [DscProperty()]
    [string]$Content

    [void] Set()
    {

        if ($this.Ensure -eq [Ensure]::Present)
        {
            $this.SetContent()
        }
        else
        {
            $this.SetDefaultContent()
        }
    }

    [bool] Test()
    {
        $present = $this.TestFileContent()
        
        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $present
        }
        else
        {
            return -not $present
        }
    }

    [cMDTBuildBootstrapIni] Get()
    {
        return $this
    }

    [bool] TestFileContent()
    {
        $present = $false
        $existingConfiguration = Get-Content -Path $this.Path -Raw #-Encoding UTF8

        if ($existingConfiguration -eq $this.Content.Replace("`n","`r`n"))
        {
            $present = $true   
        }

        return $present
    }

    [void] SetContent()
    {
        Set-Content -Path $this.Path -Value $this.Content.Replace("`n","`r`n") -NoNewline -Force #-Encoding UTF8 
    }
    
    [void] SetDefaultContent()
    {
            $defaultContent = @"
[Settings]
Priority=Default

[Default]

"@
        Set-Content -Path $this.Path -Value $defaultContent -NoNewline -Force #-Encoding UTF8 
    }
}

[DscResource()]
class cMDTBuildCustomize
{

    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Mandatory)]
    [string]$Version

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Key)]
    [string]$Path
    
    [DscProperty(Mandatory)]
    [string]$SourcePath

    [DscProperty(Mandatory)]
    [string]$TempLocation

    [bool]$Protected

    [DscProperty(NotConfigurable)]
    [string]$Directory

    [void] Set()
    {

        [string]$separator = ""
        If ($this.SourcePath -like "*/*")
        { $separator = "/" }
        Else
        { $separator = "\" }

        $filename = "$($this.SourcePath.Split($separator)[-1])_$($this.Version).zip"
        $foldername = $filename.Replace(".$($filename.Split(".")[-1])","")

        [bool]$download = $True
        If (($separator -eq "/") -Or ($this.SourcePath.Substring(0,2) -eq "\\"))
        { $targetdownload = "$($this.TempLocation)\$($filename)" }
        Else
        { $targetdownload = "$($this.SourcePath)_$($this.Version).zip" ; $download = $False }

        $extractfolder = "$($this.path)\$($this.name)"
        $referencefile = "$($this.path)\$($this.name)\$($this.SourcePath.Split($separator)[-1]).version"

        if ($this.ensure -eq [Ensure]::Present)
        {

            $present = Invoke-TestPath -Path "$($this.path)\$($this.name)"

            if ($present)
            {

                If ($download)
                {
                    Invoke-WebDownload -Source "$($this.SourcePath)_$($this.Version).zip" -Target $targetdownload -Verbose
                    $present = Invoke-TestPath -Path $targetdownload
                    If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }
                }
                if (-not $this.Protected)
                {
                    $present = Invoke-TestPath -Path $referencefile
                    If ($present) { Invoke-RemovePath -Path $referencefile }
                }
                Invoke-ExpandArchive -Source $targetdownload -Target $extractfolder -Verbose
                If ($download) { Invoke-RemovePath -Path $targetdownload }
                if ($this.Protected) { New-ReferenceFile -Path $referencefile }
            }
            else
            {
                If ($download)
                {
                    Invoke-WebDownload -Source "$($this.SourcePath)_$($this.Version).zip" -Target $targetdownload -Verbose
                    $present = Invoke-TestPath -Path $targetdownload
                    If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }
                }
                Invoke-ExpandArchive -Source $targetdownload -Target $extractfolder -Verbose
                If ($download) { Invoke-RemovePath -Path $targetdownload }
                New-ReferenceFile -Path $referencefile 
            }

            Set-Content -Path $referencefile -Value "$($this.Version)"
        }
        else
        {

            Invoke-RemovePath -Path "$($this.path)\$($this.name)" -Verbose
        }
    }

    [bool] Test()
    {

        [string]$separator = ""
        If ($this.SourcePath -like "*/*")
        { $separator = "/" }
        Else
        { $separator = "\" }

        $present = Invoke-TestPath -Path "$($this.path)\$($this.name)"

        $this.Protected

        if (($present) -and ($this.ensure -eq [Ensure]::Present))
        {
            If (Test-Path -Path "$($this.path)\$($this.name)\$($this.SourcePath.Split($separator)[-1]).version" -ErrorAction Ignore)
            {

                $match = Compare-Version -Source "$($this.path)\$($this.name)\$($this.SourcePath.Split($separator)[-1]).version" -Target $this.Version

                if (-not ($match))
                {

                    Write-Verbose "$($this.Name) version has been updated on the pull server"
                    $present = $false
                }
            }
            else
            {
                $present = $false
            }
        }

        if (($present) -and ($this.Protected) -and ($this.ensure -eq [Ensure]::Absent))
        {

            Write-Verbose "Folder protection override mode defined"
            Write-Verbose "$($this.Name) folder will not be removed"
            return $true
        }
        
        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $present
        }
        else
        {
            return -not $present
        }
    }

    [cMDTBuildCustomize] Get()
    {
        return $this
    }
}

[DscResource()]
class cMDTBuildCustomSettingsIni
{

    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [string]$Path

    [DscProperty()]
    [string]$Content

    [void] Set()
    {

        if ($this.Ensure -eq [Ensure]::Present)
        {
            $this.SetContent()
        }
        else
        {
            $this.SetDefaultContent()
        }
    }

    [bool] Test()
    {
        $present = $this.TestFileContent()
        
        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $present
        }
        else
        {
            return -not $present
        }
    }

    [cMDTBuildCustomSettingsIni] Get()
    {
        return $this
    }

    [bool] TestFileContent()
    {
        $present = $false 
        $existingConfiguration = Get-Content -Path $this.Path -Raw #-Encoding UTF8

        if ($existingConfiguration -eq $this.Content.Replace("`n","`r`n"))
        {
            $present = $true   
        }

        return $present
    }

    [void] SetContent()
    {
        Set-Content -Path $this.Path -Value $this.Content.Replace("`n","`r`n") -NoNewline -Force #-Encoding UTF8
    }
    
    [void] SetDefaultContent()
    {
            $defaultContent = @"
[Settings]
Priority=Default
Properties=MyCustomProperty

[Default]
OSInstall=Y
SkipCapture=YES
SkipAdminPassword=NO
SkipProductKey=YES

"@
        Set-Content -Path $this.Path -Value $defaultContent -NoNewline -Force #-Encoding UTF8
    }
}

[DscResource()]
class cMDTBuildDirectory
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Key)]
    [string]$Name

    [DscProperty()]
    [string]$PSDriveName

    [DscProperty()]
    [string]$PSDrivePath

    [void] Set()
    {
        if ($this.ensure -eq [Ensure]::Present) {
            $this.CreateDirectory()
        }
        else
        {
            if (($this.PSDrivePath) -and ($this.PSDriveName)) {
                Invoke-RemovePath -Path "$($this.path)\$($this.Name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
            }
            else {
                Invoke-RemovePath -Path "$($this.path)\$($this.Name)" -Verbose
            }
        }
    }

    [bool] Test()
    {
        if (($this.PSDrivePath) -and ($this.PSDriveName)) {
            $present = Invoke-TestPath -Path "$($this.path)\$($this.Name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
        }
        else {
            $present = Invoke-TestPath -Path "$($this.path)\$($this.Name)" -Verbose
        }
        
        if ($this.Ensure -eq [Ensure]::Present) {
            return $present
        }
        else {
            return -not $present
        }
    }

    [cMDTBuildDirectory] Get()
    {
        return $this
    }

    [void] CreateDirectory()
    {
        if (($this.PSDrivePath) -and ($this.PSDriveName)) {
            Import-MicrosoftDeploymentToolkitModule
            New-PSDrive -Name $this.PSDriveName -PSProvider "MDTProvider" -Root $this.PSDrivePath -Verbose:$false | `
	            New-Item -ItemType Directory -Path "$($this.path)\$($this.Name)" -Verbose
        }
        else {
            New-Item -ItemType Directory -Path "$($this.path)\$($this.Name)" -Verbose
        }
    }
}

[DscResource()]
class cMDTBuildOperatingSystem
{

    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Key)]
    [string]$SourcePath

    [DscProperty(Mandatory)]
    [string]$PSDriveName

    [DscProperty(Mandatory)]
    [string]$PSDrivePath

    [void] Set()
    {
        if ($this.ensure -eq [Ensure]::Present)
        {
            if ( !$this.Test() ) {
				$this.ImportOperatingSystem("$($this.SourcePath)")
            }
        }
        else
        {
            Invoke-RemovePath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
            If ( $this.Test() ) { Write-Error "Cannot remove '$($this.PSDrivePath)\Operating Systems\$($this.Name)'" }
        }
    }

    [bool] Test()
    {
        $present = Invoke-TestPath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)\sources\install.wim"
        return $present
    }

    [cMDTBuildOperatingSystem] Get()
    {
        return $this
    }

    [void] ImportOperatingSystem($OperatingSystem)
    {
        Import-MicrosoftDeploymentToolkitModule
        New-PSDrive -Name $this.PSDriveName -PSProvider "MDTProvider" -Root $this.PSDrivePath -Verbose:$false

        Try {
            $ErrorActionPreference = "Stop"
            Import-MDTOperatingSystem -Path $this.Path -SourcePath $OperatingSystem -DestinationFolder $this.Name -Verbose
            $ErrorActionPreference = "Continue"
        }
        Catch [Microsoft.Management.Infrastructure.CimException] {
            If ($_.FullyQualifiedErrorId -notlike "*ItemAlreadyExists*") {
                throw $_
            }
        }
        Finally {
        }
    }
}

[DscResource()]
class cMDTBuildPersistentDrive
{

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Mandatory)]
    [string]$Description

    [DscProperty(Mandatory)]
    [string]$NetworkPath

    [void] Set()
    {

        if ($this.ensure -eq [Ensure]::Present)
        {
            $this.CreateDirectory()
        }
        else
        {
            $this.RemoveDirectory()
        }
    }

    [bool] Test()
    {

        $present = $this.TestDirectoryPath()
        
        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $present
        }
        else
        {
            return -not $present
        }
    }

    [cMDTBuildPersistentDrive] Get()
    {
        return $this
    }

    [bool] TestDirectoryPath()
    {
        $present = $false

        Import-MicrosoftDeploymentToolkitModule

        if (Test-Path -Path $this.Path -PathType Container -ErrorAction Ignore)
        {
            $mdtShares = (GET-MDTPersistentDrive -ErrorAction SilentlyContinue)
            If ($mdtShares)
            {
                ForEach ($share in $mdtShares)
                {
                    If ($share.Name -eq $this.Name)
                    {
                        $present = $true
                    }
                }
            } 
        }

        return $present
    }

    [void] CreateDirectory()
    {

        Import-MicrosoftDeploymentToolkitModule

        New-PSDrive -Name $this.Name -PSProvider "MDTProvider" -Root $this.Path -Description $this.Description -NetworkPath $this.NetworkPath -Verbose:$false | `
        Add-MDTPersistentDrive -Verbose

    }

    [void] RemoveDirectory()
    {

        Import-MicrosoftDeploymentToolkitModule

        Write-Verbose -Message "Removing MDTPersistentDrive $($this.Name)"

        New-PSDrive -Name $this.Name -PSProvider "MDTProvider" -Root $this.Path -Description $this.Description -NetworkPath $this.NetworkPath -Verbose:$false | `
        Remove-MDTPersistentDrive -Verbose
    }
}

[DscResource()]
class cMDTBuildPreReqs
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure
    
    [DscProperty(Key)]
    [string]$DownloadPath

    [DscProperty(NotConfigurable)]
    [hashtable[]]
    $downloadFiles = @(
        @{
            #Version: MDT 2013 Update 2 (Build: 6.3.8330.1000)
            Name = "MDT"
            URI = "https://download.microsoft.com/download/3/0/1/3012B93D-C445-44A9-8BFB-F28EB937B060/MicrosoftDeploymentToolkit2013_x64.msi"
            Folder = "Microsoft Deployment Toolkit"
            File = "MicrosoftDeploymentToolkit2013_x64.msi"
        }
        @{
            #Version: Windows 10 v1607 (Build: 10.1.14393.0)
            Name = "ADK"
            URI = "http://download.microsoft.com/download/9/A/E/9AE69DD5-BA93-44E0-864E-180F5E700AB4/adk/adksetup.exe"
            Folder = "Windows Assessment and Deployment Kit"
            File = "adksetup.exe"
        }
        @{
            #Version: 5 (Build: 5.1.50428.0)
		    Name = "Silverlight_x64"
            URI = "https://download.microsoft.com/download/1/F/6/1F637DB3-8EF9-4D96-A8F1-909DFD7C5E69/50428.00/Silverlight_x64.exe"
            Folder = "Silverlight_x64"
            File = "Silverlight_x64.exe"
        }
        @{
            #Version: 5 (Build: 5.1.50428.0)
		    Name = "Silverlight_x86"
            URI = "https://download.microsoft.com/download/1/F/6/1F637DB3-8EF9-4D96-A8F1-909DFD7C5E69/50428.00/Silverlight.exe"
            Folder = "Silverlight_x86"
            File = "Silverlight.exe"
        }
        @{
            Name = "VS++Application"
            URI = "Sources\Install-MicrosoftVisualC++x86x64.wsf"
            Folder = "VC++"
            File = "Install-MicrosoftVisualC++x86x64.wsf"
        }
        @{
            Name = "VS2005SP1x86"
            URI = "http://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.exe"
            Folder = "VC++\Source\VS2005"
            File = "vcredist_x86.exe"
        }
        @{
            Name = "VS2005SP1x64"
            URI = "http://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.exe"
            Folder = "VC++\Source\VS2005"
            File = "vcredist_x64.exe"
        }
        @{
            Name = "VS2008SP1x86"
            URI = "http://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe"
            Folder = "VC++\Source\VS2008"
            File = "vcredist_x86.exe"
        }
        @{
            Name = "VS2008SP1x64"
            URI = "http://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe"
            Folder = "VC++\Source\VS2008"
            File = "vcredist_x64.exe"
        }
        @{
            Name = "VS2010SP1x86"
            URI = "http://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe"
            Folder = "VC++\Source\VS2010"
            File = "vcredist_x86.exe"
        }
        @{
            Name = "VS2010SP1x64"
            URI = "http://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe"
            Folder = "VC++\Source\VS2010"
            File = "vcredist_x64.exe"
        }
        @{
            Name = "VS2012UPD4x86"
            URI = "http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe"
            Folder = "VC++\Source\VS2012"
            File = "vcredist_x86.exe"
        }
        @{
            Name = "VS2012UPD4x64"
            URI = "http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe"
            Folder = "VC++\Source\VS2012"
            File = "vcredist_x64.exe"
        }
        @{
            Name = "VS2013x86"
            URI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe"
            Folder = "VC++\Source\VS2013"
            File = "vcredist_x86.exe"
        }
        @{
            Name = "VS2013x64"
            URI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
            Folder = "VC++\Source\VS2013"
            File = "vcredist_x64.exe"
        }
        @{
            Name = "VS2015x86"
            URI = "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x86.exe"
            Folder = "VC++\Source\VS2015"
            File = "vc_redist.x86.exe"
        }
        @{
            Name = "VS2015x64"
            URI = "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe"
            Folder = "VC++\Source\VS2015"
            File = "vc_redist.x64.exe"
        }
		@{
			Name = "WMF30x86"
			URI = "https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/Windows6.1-KB2506143-x86.msu"
			Folder = "WMF30x86"
			File = "Windows6.1-KB2506143-x86.msu"
		}
		@{
			Name = "WMF30x64"
			URI = "https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/Windows6.1-KB2506143-x64.msu"
			Folder = "WMF30x64"
			File = "Windows6.1-KB2506143-x64.msu"
		}
		@{
			Name = "WMF50x64"
			URI = "https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win8.1AndW2K12R2-KB3134758-x64.msu"
			Folder = "WMF50x64"
			File = "Win8.1AndW2K12R2-KB3134758-x64.msu"
		}
        @{
            Name = "KeyboardToggle"
            URI = "Sources\Toggle.reg"
            Folder = "KeyboardToggle"
            File = "Toggle.reg"
        }
        @{
            Name = "CleanupBeforeSysprep"
            URI = "Sources\Action-CleanupBeforeSysprep.wsf"
            Folder = "CleanupBeforeSysprep"
            File = "Action-CleanupBeforeSysprep.wsf"
        }
        @{
            Name = "RemoveWin8.1Apps"
            URI = "Sources\Remove-Windows8.1Apps.ps1"
            Folder = "Remove-Windows8.1Apps"
            File = "Remove-Windows8.1Apps.ps1"
        }
        @{
            Name = "CustomizeDefaultProfile"
            URI = "Sources\Customize-DefaultProfile.ps1"
            Folder = "Set-Startlayout"
            File = "Customize-DefaultProfile.ps1"
        }
        @{
            Name = "StartLayout"
            URI = "Sources\Default_Start_Screen_Layout.bin"
            Folder = "Set-Startlayout"
            File = "Default_Start_Screen_Layout.bin"
        }
        @{
            Name = "DesktopTheme"
            URI = "Sources\Theme01.deskthemepack"
            Folder = "Set-Startlayout"
            File = "Theme01.deskthemepack"
        }
    )
    
    [void] Set()
    {
        Write-Verbose "Starting Set MDT PreReqs..."

        if ($this.ensure -eq [Ensure]::Present)
        {
            $present = $this.TestDownloadPath()

            if ($present) {
                Write-Verbose "   Download folder present!"
            }
            else {
                New-Item -Path $this.DownloadPath -ItemType Directory -Force
            }

            #Set all files:               
            ForEach ($file in $this.downloadFiles)
            {
                if(Test-Path -Path "$($this.DownloadPath)\$($file.Folder)\$($file.File)") {
                    Write-Verbose "   $($file.Name) already present!"
                }
                else {
                    Write-Verbose "   Creating $($file.Name) folder..."
                    New-Item -Path "$($this.DownloadPath)\$($file.Folder)" -ItemType Directory -Force
					If ($file.URI -like "*/*") {
						$this.WebClientDownload($file.URI, "$($this.DownloadPath)\$($file.Folder)\$($file.File)")
					}
					else {
						$this.CopyFromSource("$($PSScriptRoot)\$($file.URI)", "$($this.DownloadPath)\$($file.Folder)\$($file.File)")
					}
                }
            }
        }
        else {
            $this.RemoveDirectory("")
        }

        Write-Verbose "MDT PreReqs set completed!"
    }

    [bool] Test()
    {
        Write-Verbose "Testing MDT PreReqs..."
        $present = $this.TestDownloadPath()

        if ($this.ensure -eq [Ensure]::Present)
        {            
            Write-Verbose "   Testing for download path.."            
            if($present) {
                Write-Verbose "   Download path found!"
			}            
            Else {
                Write-Verbose "   Download path not found!"
                return $false
			}

            ForEach ($File in $this.downloadFiles)
            {
                 Write-Verbose "   Testing for $($File.Name)..."
                 $present = (Test-Path -Path "$($this.DownloadPath)\$($File.Folder)\$($File.File)")
                 Write-Verbose "   $present"
                 if(!$Present){return $false}
            }
        }
        else {
            if ($Present) {
               $present = $false 
            }
            else {
               $present = $true 
            }
        }

        Write-Verbose "Test completed!"
        return $present
    }

    [cMDTBuildPreReqs] Get()
    {
        return $this
    }

    [bool] TestDownloadPath()
    {
        $present = $false
        if (Test-Path -Path $this.DownloadPath -ErrorAction Ignore) {
            $present = $true
        }        
        return $present
    }

    [void] WebClientDownload($Source,$Target)
    {
        $WebClient = New-Object System.Net.WebClient
        Write-Verbose "      Downloading file $($Source)"
        Write-Verbose "      Downloading to $($Target)"
        $WebClient.DownloadFile($Source, $Target)
    }

	[void] CopyFromSource($Source,$Target)
	{
        Write-Verbose "      Copying $($Target)"
		Copy-Item -Path $Source -Destination $Target
	}

    [void] ExtractFile($Source,$Target)
    {
        Write-Verbose "      Extracting file to $($Target)"
        Expand-Archive $Source -DestinationPath $Target -Force
    }

    [void] CleanTempDirectory($Object)
    {
        Remove-Item -Path $Object -Force -Recurse -Verbose:$False
    }

    [void] RemoveDirectory($referencefile = "")
    {
        Remove-Item -Path $this.DownloadPath -Force -Verbose     
    }

    [void] RemoveReferenceFile($File)
    {
        Remove-Item -Path $File -Force -Verbose:$False
    }
}

[DscResource()]
class cMDTBuildTaskSequence
{

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Mandatory)]
    [string]$OSName

    [DscProperty(Mandatory)]
    [string]$Template

    [DscProperty(Mandatory)]
    [string]$ID

    [DscProperty(Mandatory)]
    [string]$OrgName

    [DscProperty(Mandatory)]
    [string]$PSDriveName

    [DscProperty(Mandatory)]
    [string]$PSDrivePath

    [void] Set()
    {
        if ($this.ensure -eq [Ensure]::Present) {
            $this.ImportTaskSequence()
        }
        else {
            Invoke-RemovePath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
        }
    }

    [bool] Test()
    {
	    $present = Invoke-TestPath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath 
        if ($this.Ensure -eq [Ensure]::Present) {
            return $present
        }
        else {
            return -not $present
        }
    }

    [cMDTBuildTaskSequence] Get()
    {
        return $this
    }

    [void] ImportTaskSequence()
    {
        Import-MicrosoftDeploymentToolkitModule
        New-PSDrive -Name $this.PSDriveName -PSProvider "MDTProvider" -Root $this.PSDrivePath -Verbose:$false
        Import-MDTTaskSequence -path $this.Path -Name $this.Name -Template $this.Template -Comments "Build Reference Image" -ID $this.ID -Version "1.0" -OperatingSystemPath $this.OSName -FullName "Windows User" -OrgName $this.OrgName -HomePage "about:blank" -Verbose
    }
<#
	[xml] ReadTaskSequence()
	{
		$tsPath = "$($this.PSDrivePath)\Control\$($this.ID)\ts.xml"
		$xml = [xml](Get-Content $tsPath)
		return $xml
	}
#>
}

[DscResource()]
class cMDTBuildTaskSequenceCustomize
{
	# Task Sequence File
	[DscProperty(Key)]
	[string]$TSFile

	# Step name
	[DscProperty(Key)]
	[string]$Name

	# New step name
	[DscProperty()]
	[string]$NewName

	# Step type
	[DscProperty(Mandatory)]
	[string]$Type

	# Group for step
	[DscProperty(Mandatory)]
	[string]$GroupName

	# SubGroup for step
	[DscProperty()]
	[string]$SubGroup

	# Enable/Disable step
	[DscProperty()]
	[string]$Disable

	# Add this step after that step
	[DscProperty()]
	[string]$AddAfter

	# OS name for OS features
	[DscProperty()]
	[string]$OSName

	# OS features
	[DscProperty()]
	[string]$OSFeatures

    [DscProperty(Mandatory)]
    [string]$PSDriveName

    [DscProperty(Mandatory)]
    [string]$PSDrivePath

	[void] Set()
    {
		$TS = $this.LoadTaskSequence()
		$group = $TS.sequence.group | ?{$_.Name -eq $this.GroupName}
		if ($this.Type -eq "Group") {
			$step = $group.group | ?{$_.Name -eq $this.Name}
		}
		else {
			$step = $group.step | ?{$_.Name -eq $this.Name}
		}

		if (!$this.AddAfter) {
			if ($step) {
				if ($this.Disable -ne "") {
					$step.disable = $this.Disable
				}
				elseif ($this.NewName -ne "") {
					$step.Name = $this.NewName
				}
			}
			else {
				$addGroup = $group.group | ?{$_.name -eq $this.SubGroup}
				$newStep = $TS.CreateElement("step")
				$newStep.SetAttribute("name", $this.Name)
				$newStep.SetAttribute("disable", "false")
				$newStep.SetAttribute("continueOnError", "false")
				$newStep.SetAttribute("successCodeList", "0 3010")
				$newStep.SetAttribute("description", "")

				switch ($this.Type) {
					"Install Roles and Features" {
						$OSIndex = @{
							"Windows 10"      = 13
							"Windows 7"       = 4
							"Windows 8.1"     = 10
							"Windows 2012 R2" = 11
						}

						$newStep.SetAttribute("type", "BDD_InstallRoles")
						$newStep.SetAttribute("runIn", "WinPEandFullOS")
						
						$varList = $TS.CreateElement("defaultVarList")
						$varName = $TS.CreateElement("variable")
						$varName.SetAttribute("name", "OSRoleIndex") | Out-Null
						$varName.SetAttribute("property", "OSRoleIndex") | Out-Null
						$varName.AppendChild($TS.CreateTextNode($OSIndex.$($this.OSName))) | Out-Null
						$varList.AppendChild($varName) | Out-Null

						$varName = $TS.CreateElement("variable")
						$varName.SetAttribute("name", "OSRoles") | Out-Null
						$varName.SetAttribute("property", "OSRoles") | Out-Null
						$varList.AppendChild($varName) | Out-Null

						$varName = $TS.CreateElement("variable")
						$varName.SetAttribute("name", "OSRoleServices") | Out-Null
						$varName.SetAttribute("property", "OSRoleServices") | Out-Null
						$varList.AppendChild($varName) | Out-Null

						$varName = $TS.CreateElement("variable")
						$varName.SetAttribute("name", "OSFeatures") | Out-Null
						$varName.SetAttribute("property", "OSFeatures") | Out-Null
						$varName.AppendChild($TS.CreateTextNode("NetFx3,TelnetClient")) | Out-Null
						$varList.AppendChild($varName) | Out-Null

						$action = $TS.CreateElement("action")
						$action.AppendChild($TS.CreateTextNode('cscript.exe "%SCRIPTROOT%\ZTIOSRole.wsf"')) | Out-Null

						$newStep.AppendChild($varList) | Out-Null
						$newStep.AppendChild($action) | Out-Null
					}

					"Install Application" {
						# for 'Action - Cleanup Before Sysprep' (empty AddAfter)
						$newStep.SetAttribute("type", "BDD_InstallApplication")
						$newStep.SetAttribute("runIn", "WinPEandFullOS")
						
						$varList = $TS.CreateElement("defaultVarList")
						$varName = $TS.CreateElement("variable")
						$varName.SetAttribute("name", "ApplicationGUID") | Out-Null
						$varName.SetAttribute("property", "ApplicationGUID") | Out-Null
                        $AppGUID = Get-ApplicationGUID -AppName $this.Name -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath
						$varName.AppendChild($TS.CreateTextNode($AppGUID)) | Out-Null
						$varList.AppendChild($varName) | Out-Null
						
						$varName = $TS.CreateElement("variable")
						$varName.SetAttribute("name", "ApplicationSuccessCodes") | Out-Null
						$varName.SetAttribute("property", "ApplicationSuccessCodes") | Out-Null
						$varName.AppendChild($TS.CreateTextNode("0 3010")) | Out-Null
						$varList.AppendChild($varName) | Out-Null

						$action = $TS.CreateElement("action")
						$action.AppendChild($TS.CreateTextNode('cscript.exe "%SCRIPTROOT%\ZTIApplications.wsf"')) | Out-Null

						$newStep.AppendChild($varList) | Out-Null
						$newStep.AppendChild($action) | Out-Null
					}

				}
				$addGroup.AppendChild($newStep)
			}
		}
		else {
			if ($this.SubGroup) {
				$AddGroup = $group.group | ?{$_.name -eq $this.SubGroup}
				$AfterStep = $addGroup.step | ?{$_.Name -eq $this.AddAfter}
			}
			else {
				$addGroup = $group
				$AfterStep = $group.step | ?{$_.Name -eq $this.AddAfter}
			}

			switch ($this.Type) {
				"Group" {
					$newGroup = $TS.CreateElement("group")
					$newGroup.SetAttribute("name", $this.Name)
					$newGroup.SetAttribute("disable", "false")
					$newGroup.SetAttribute("continueOnError", "false")
					$newGroup.SetAttribute("expand", "true")
					$newGroup.SetAttribute("description", "")
					$AddGroup.InsertAfter($newGroup, $afterstep)
				}

				"Restart Computer" {
					$newStep = $TS.CreateElement("step")
					$newStep.SetAttribute("name", $this.Name)
					$newStep.SetAttribute("disable", "false")
					$newStep.SetAttribute("continueOnError", "false")
					$newStep.SetAttribute("successCodeList", "0 3010")
					$newStep.SetAttribute("description", "")
					$newStep.SetAttribute("type", "SMS_TaskSequence_RebootAction")
					$newStep.SetAttribute("runIn", "WinPEandFullOS")

					$varList = $TS.CreateElement("defaultVarList")
					$varName = $TS.CreateElement("variable")
					$varName.SetAttribute("name", "Message") | Out-Null
					$varName.SetAttribute("property", "Message") | Out-Null
					$varList.AppendChild($varName) | Out-Null

					$varName = $TS.CreateElement("variable")
					$varName.SetAttribute("name", "MessageTimeout") | Out-Null
					$varName.SetAttribute("property", "MessageTimeout") | Out-Null
					$varName.AppendChild($TS.CreateTextNode("60")) | Out-Null
					$varList.AppendChild($varName) | Out-Null

					$varName = $TS.CreateElement("variable")
					$varName.SetAttribute("name", "Target") | Out-Null
					$varName.SetAttribute("property", "Target") | Out-Null
					$varList.AppendChild($varName) | Out-Null

					$action = $TS.CreateElement("action")
					$action.AppendChild($TS.CreateTextNode("smsboot.exe /target:WinPE")) | Out-Null

					$newStep.AppendChild($varList) | Out-Null
					$newStep.AppendChild($action) | Out-Null

					$AddGroup.InsertAfter($newStep, $afterstep)
				}
			}
		}

        $TS.Save($this.TSFile)
	}

	[bool] Test()
    {
		$TS = $this.LoadTaskSequence()
		$present = $false

		$group = $TS.sequence.group | ?{$_.Name -eq $this.GroupName}
		if ($this.Type -eq "Group") {
			$step = $group.group | ?{$_.Name -eq $this.Name}
		}
		else {
			$step = $group.step | ?{$_.Name -eq $this.Name}
		}

		if (!$this.AddAfter) {
			if ($step) {
				if ($this.Disable -ne "") {
					$present = ($step.disable -eq $this.Disable)
				}
			}
			else {
				if ($this.NewName -ne "") {
					# For rename "Custom Tasks" group only
					$present = ( ($group.group | ?{$_.Name -eq $this.NewName}) -ne $null )
				}
				elseif ($this.SubGroup) {
					$addGroup = $group.group | ?{$_.name -eq $this.SubGroup}
					$present = ( ($addGroup.step | ?{$_.Name -eq $this.Name}) -ne $null )
				}
			}
		}
		else {
			if ($this.Type -eq "Group") {
				$present = ( ($group.group | ?{$_.Name -eq $this.Name}) -ne $null )
			}
			else {
				$present = ( ($group.step | ?{$_.Name -eq $this.Name}) -ne $null )
			}
		}

		return $present
	}

    [cMDTBuildTaskSequenceCustomize] Get()
    {
        return $this
    }

	[xml] LoadTaskSequence()
	{
		$tsPath = $this.TSFile
		$xml = [xml](Get-Content $tsPath)
		return $xml
	}

	[void] AddStep($TS, $group, $Name, $After)
	{
		$group = $TS.sequence.group | ?{$_.Name -eq $group}
		$afterStep = $group.step | ?{$_.Name -eq $After}
		$afterStep.InsertAfter($afterStep)

	}
}

[DscResource()]
class cMDTBuildUpdateBootImage
{
    [DscProperty(Key)]
    [string]$Version

    [DscProperty(Key)]
    [string]$PSDeploymentShare

    [DscProperty(Mandatory)]
    [bool]$Force

    [DscProperty(Mandatory)]
    [bool]$Compress

    [DscProperty(Mandatory)]
    [string]$DeploymentSharePath

    [DscProperty()]
    [string]$ExtraDirectory

    [DscProperty()]
    [string]$BackgroundFile

    [DscProperty()]
    [string]$LiteTouchWIMDescription
      
    [void] Set()
    {
        $this.UpdateBootImage()
    }

    [bool] Test()
    {
        Return ($this.VerifyVersion())
    }

    [cMDTBuildUpdateBootImage] Get()
    {
        return $this
    }

    [bool] VerifyVersion()
    {
        [bool]$match = $false

        if ((Get-Content -Path "$($this.DeploymentSharePath)\Boot\CurrentBootImage.version" -ErrorAction Ignore) -eq $this.Version)
        {
            $match = $true
        }
        
        return $match
    }

    [void] UpdateBootImage()
    {

        Import-MicrosoftDeploymentToolkitModule

        New-PSDrive -Name $this.PSDeploymentShare -PSProvider "MDTProvider" -Root $this.DeploymentSharePath -Verbose:$false

        If ([string]::IsNullOrEmpty($($this.ExtraDirectory)))
        {
            Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x64.ExtraDirectory -Value ""
            Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x86.ExtraDirectory -Value ""
        }
        ElseIf (Invoke-TestPath -Path "$($this.DeploymentSharePath)\$($this.ExtraDirectory)")
        {

            Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x64.ExtraDirectory -Value "$($this.DeploymentSharePath)\$($this.ExtraDirectory)"                        
            Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x86.ExtraDirectory -Value "$($this.DeploymentSharePath)\$($this.ExtraDirectory)"                       
        }

        If ([string]::IsNullOrEmpty($($this.BackgroundFile)))
        {
            Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x64.BackgroundFile -Value ""
            Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x86.BackgroundFile -Value ""
        }

        ElseIf(Invoke-TestPath -Path "$($this.DeploymentSharePath)\$($this.BackgroundFile)")
        {
             Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x64.BackgroundFile -Value "$($this.DeploymentSharePath)\$($this.BackgroundFile)"
             Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x86.BackgroundFile -Value "$($this.DeploymentSharePath)\$($this.BackgroundFile)"
        }

        If($this.LiteTouchWIMDescription) { Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x64.LiteTouchWIMDescription -Value "$($this.LiteTouchWIMDescription) x64 $($this.Version)" }
        Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x64.GenerateLiteTouchISO -Value $false

        If($this.LiteTouchWIMDescription) { Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x86.LiteTouchWIMDescription -Value "$($this.LiteTouchWIMDescription) x86 $($this.Version)" }
        Set-ItemProperty "$($this.PSDeploymentShare):" -Name Boot.x86.GenerateLiteTouchISO -Value $false
        

        #The Update-MDTDeploymentShare command crashes WMI when run from inside DSC. This section is a work around.
        $aPSDeploymentShare = $this.PSDeploymentShare
        $aDeploymentSharePath = $this.DeploymentSharePath
        $aForce = $this.Force
        $aCompress = $this.Compress
        $jobArgs = @($aPSDeploymentShare,$aDeploymentSharePath,$aForce,$aCompress)

        $job = Start-Job -Name UpdateMDTDeploymentShare -Scriptblock {
            Import-Module "$env:ProgramFiles\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1" -ErrorAction Stop -Verbose:$false
            New-PSDrive -Name $args[0] -PSProvider "MDTProvider" -Root $args[1] -Verbose:$false
            Update-MDTDeploymentShare -Path "$($args[0]):" -Force:$args[2] -Compress:$args[3]
        } -ArgumentList $jobArgs

        $job | Wait-Job -Timeout 900 
        $timedOutJobs = Get-Job -Name UpdateMDTDeploymentShare | Where-Object {$_.State -eq 'Running'} | Stop-Job -PassThru

        If ($timedOutJobs)
        {
            Write-Error "Update-MDTDeploymentShare job exceeded timeout limit of 900 seconds and was aborted"
        }
        Else
        {
            Set-Content -Path "$($this.DeploymentSharePath)\Boot\CurrentBootImage.version" -Value "$($this.Version)"
        }
    }
    
    
}

Function Compare-Version
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Source,
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Target
    )

    [bool]$match = $false

    if ((Get-Content -Path $Source) -eq $Target)
    {
        $match = $true
    }

    return $match
}

Function Import-MicrosoftDeploymentToolkitModule
{
    If (-Not(Get-Module MicrosoftDeploymentToolkit))
    {
        Import-Module "$env:ProgramFiles\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1" -ErrorAction Stop -Global -Verbose:$False
    }
}

Function Invoke-ExpandArchive
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Source,
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Target
    )

    [bool]$Verbosity
    If($PSBoundParameters.Verbose)
    { $Verbosity = $True }
    Else
    { $Verbosity = $False }

    Write-Verbose "Expanding archive $($Source) to $($Target)"
    Expand-Archive $Source -DestinationPath $Target -Force -Verbose:$Verbosity
}

Function Invoke-RemovePath
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter()]
        [string]$PSDriveName,
        [Parameter()]
        [string]$PSDrivePath
    )

    [bool]$Verbosity
    If($PSBoundParameters.Verbose)
    { $Verbosity = $True }
    Else
    { $Verbosity = $False }

    if (($PSDrivePath) -and ($PSDriveName))
    {

        Import-MicrosoftDeploymentToolkitModule
        New-PSDrive -Name $PSDriveName -PSProvider "MDTProvider" -Root $PSDrivePath -Verbose:$False | `
        Remove-Item -Path $Path -Force -Verbose:$Verbosity
    }
    else
    {

        Remove-Item -Path $Path -Force -Verbose:$Verbosity
    }
}

Function Invoke-TestPath
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter()]
        [string]$PSDriveName,
        [Parameter()]
        [string]$PSDrivePath
    )

    [bool]$present = $false

    if (($PSDrivePath) -and ($PSDriveName))
    {
        Import-MicrosoftDeploymentToolkitModule
        if (New-PSDrive -Name $PSDriveName -PSProvider "MDTProvider" -Root $PSDrivePath -Verbose:$false | `
            Test-Path -Path $Path -ErrorAction Ignore)
        {
            $present = $true
        }        
    }
    else
    {
        if (Test-Path -Path $Path -ErrorAction Ignore)
        {
            $present = $true
        }
    }

    return $present
}

Function Invoke-WebDownload
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Source,
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Target
    )

    [bool]$Verbosity
    If($PSBoundParameters.Verbose)
    { $Verbosity = $True }
    Else
    { $Verbosity = $False }

    If ($Source -like "*/*")
    {
        If (Get-Service BITS | Where-Object {$_.status -eq "running"})
        {

            If ($Verbosity) { Write-Verbose "Downloading file $($Source) via Background Intelligent Transfer Service" }
            Import-Module BitsTransfer -Verbose:$false
            Start-BitsTransfer -Source $Source -Destination $Target -Verbose:$Verbosity
            Remove-Module BitsTransfer -Verbose:$false
        }
        else
        {

            If ($Verbosity) { Write-Verbose "Downloading file $($Source) via System.Net.WebClient" }
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile($Source, $Target)
        }
    }
    Else
    {
        If (Get-Service BITS | Where-Object {$_.status -eq "running"})
        {
            If ($Verbosity) { Write-Verbose "Downloading file $($Source) via Background Intelligent Transfer Service" }
            Import-Module BitsTransfer -Verbose:$false
            Start-BitsTransfer -Source $Source -Destination $Target -Verbose:$Verbosity
        }
        Else
        {
            Copy-Item $Source -Destination $Target -Force -Verbose:$Verbosity
        }
    }
}

Function New-ReferenceFile
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter()]
        [string]$PSDriveName,
        [Parameter()]
        [string]$PSDrivePath
    )
    if (($PSDrivePath) -and ($PSDriveName))
    {

        Import-MicrosoftDeploymentToolkitModule
        New-PSDrive -Name $PSDriveName -PSProvider "MDTProvider" -Root $PSDrivePath -Verbose:$false | `
        New-Item -Type File -Path $Path -Force -Verbose:$False     
    }
    else
    {

        New-Item -Type File -Path $Path -Force -Verbose:$False  
    }
}

Function Get-ApplicationGUID
{
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$True)]
        [string]$AppName,
        [Parameter(Mandatory=$True)]
        [string]$PSDriveName,
        [Parameter(Mandatory=$True)]
        [string]$PSDrivePath
	)

	Import-MicrosoftDeploymentToolkitModule
    New-PSDrive -Name $PSDriveName -PSProvider "MDTProvider" -Root $PSDrivePath -Verbose:$false | Out-Null
	$app = Get-ChildItem -Path "$($PSDriveName):\Applications" -Recurse | ?{ $_.Name -eq  $AppName }

	return $app.GUID
}
