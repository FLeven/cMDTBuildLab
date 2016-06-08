enum Ensure
{
    Absent
    Present
}

[DscResource()]
class cMDTBuildApplication
{

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Key)]
    [string]$ShortName

    [DscProperty(Mandatory)]
    [string]$Version

    [DscProperty(Mandatory)]
    [string]$Publisher

    [DscProperty(Mandatory)]
    [string]$Language
    
    [DscProperty(Mandatory)]
    [string]$CommandLine
    
    [DscProperty(Mandatory)]
    [string]$WorkingDirectory
    
    [DscProperty(Mandatory)]
    [string]$ApplicationSourcePath
    
    [DscProperty(Mandatory)]
    [string]$TempLocation

    [DscProperty(Mandatory)]
    [string]$DestinationFolder
    
    [DscProperty(Mandatory)]
    [string]$Enabled

    [DscProperty(Mandatory)]
    [string]$PSDriveName

    [DscProperty(Mandatory)]
    [string]$PSDrivePath

    [void] Set()
    {

        [string]$separator = ""
        If ($this.ApplicationSourcePath -like "*/*")
        { $separator = "/" }
        Else
        { $separator = "\" }

        $filename = "$($this.ApplicationSourcePath.Split($separator)[-1])_$($this.Version).zip"
        $foldername = $filename.Replace(".$($filename.Split(".")[-1])","")

        [bool]$download = $True
        If (($separator -eq "/") -Or ($this.ApplicationSourcePath.Substring(0,2) -eq "\\"))
        { $targetdownload = "$($this.TempLocation)\$($filename)" }
        Else
        { $targetdownload = "$($this.ApplicationSourcePath)_$($this.Version).zip" ; $download = $False }
        
        $extractfolder = "$($this.TempLocation)\$($foldername)"
        $referencefile = "$($this.PSDrivePath)\Applications\$($this.DestinationFolder)\$($this.ApplicationSourcePath.Split($separator)[-1]).version"

        if ($this.ensure -eq [Ensure]::Present)
        {

            $present = Invoke-TestPath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath
            if ($present)
            {

                If ($download)
                {
                    Invoke-WebDownload -Source "$($this.ApplicationSourcePath)_$($this.Version).zip" -Target $targetdownload -Verbose
                    $present = Invoke-TestPath -Path $targetdownload
                    If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }
                }
                Invoke-ExpandArchive -Source $targetdownload -Target "$($this.PSDrivePath)\Applications\$($this.name)"
                If ($download)
                { Invoke-RemovePath -Path $targetdownload }
            }
            else
            {

                If ($download)
                {
                    Invoke-WebDownload -Source "$($this.ApplicationSourcePath)_$($this.Version).zip" -Target $targetdownload -Verbose
                    $present = Invoke-TestPath -Path $targetdownload
                    If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }
                }

                Invoke-ExpandArchive -Source $targetdownload -Target $extractfolder
                $present = Invoke-TestPath -Path $extractfolder
                If (-not($present)) { Write-Error "Cannot find path '$extractfolder' because it does not exist." ; Return }

                If ($download) { Invoke-RemovePath -Path $targetdownload }

                $this.ImportApplication($extractfolder)

                Invoke-RemovePath -Path $extractfolder
                New-ReferenceFile -Path $referencefile -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath
            }

            Set-Content -Path $referencefile -Value "$($this.Version)"
        }
        else
        {   
            
            Invoke-RemovePath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
        }
    }

    [bool] Test()
    {

        [string]$separator = ""
        If ($this.ApplicationSourcePath -like "*/*")
        { $separator = "/" }
        Else
        { $separator = "\" }

        $present = Invoke-TestPath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath 

        if (($present) -and ($this.ensure -eq [Ensure]::Present))
        {

            $match = Compare-Version -Source "$($this.PSDrivePath)\Applications\$($this.DestinationFolder)\$($this.ApplicationSourcePath.Split($separator)[-1]).version" -Target $this.Version
            if (-not ($match))
            {
                Write-Verbose "$($this.Name) version has been updated on the pull server"
                $present = $false
            }
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

    [cMDTBuildApplication] Get()
    {
        return $this
    }

    [void] ImportApplication($Source)
    {

        Import-MicrosoftDeploymentToolkitModule

        New-PSDrive -Name $this.PSDriveName -PSProvider "MDTProvider" -Root $this.PSDrivePath -Verbose:$false

        Import-MDTApplication -Path $this.Path -Enable $this.Enabled -Name $this.Name -ShortName $this.ShortName -Version $this.Version `
                              -Publisher $this.Publisher -Language $this.Language -CommandLine $this.CommandLine -WorkingDirectory $this.WorkingDirectory `
                              -ApplicationSourcePath $Source -DestinationFolder $this.DestinationFolder -Verbose

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
    [Ensure] $Ensure

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

        if ($this.ensure -eq [Ensure]::Present)
        {
            $this.CreateDirectory()
        }
        else
        {
            if (($this.PSDrivePath) -and ($this.PSDriveName))
            {
                Invoke-RemovePath -Path "$($this.path)\$($this.Name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
            }
            Else
            {
                Invoke-RemovePath -Path "$($this.path)\$($this.Name)" -Verbose
            }
        }
    }

    [bool] Test()
    {

        if (($this.PSDrivePath) -and ($this.PSDriveName))
        {
            $present = Invoke-TestPath -Path "$($this.path)\$($this.Name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
        }
        Else
        {
            $present = Invoke-TestPath -Path "$($this.path)\$($this.Name)" -Verbose
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

    [cMDTBuildDirectory] Get()
    {
        return $this
    }

    [void] CreateDirectory()
    {

        if (($this.PSDrivePath) -and ($this.PSDriveName))
        {
            Import-MicrosoftDeploymentToolkitModule

            New-PSDrive -Name $this.PSDriveName -PSProvider "MDTProvider" -Root $this.PSDrivePath -Verbose:$false | `
            New-Item -ItemType Directory -Path "$($this.path)\$($this.Name)" -Verbose
        }
        else
        {
            New-Item -ItemType Directory -Path "$($this.path)\$($this.Name)" -Verbose
        }

    }
}

[DscResource()]
class cMDTBuildOperatingSystem
{

    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Mandatory)]
    [string]$Version

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Key)]
    [string]$SourcePath

    [DscProperty(Mandatory)]
    [string]$TempLocation

    [DscProperty(Mandatory)]
    [string]$PSDriveName

    [DscProperty(Mandatory)]
    [string]$PSDrivePath

    [void] Set()
    {

        [bool]$Hash = $False
        If (-not ($this.version))
        { $Hash = $True }

        [string]$separator = ""
        If ($this.SourcePath -like "*/*")
        { $separator = "/" }
        Else
        { $separator = "\" }

        $filename = $null
        If ($Hash)
        { $filename = "$($this.SourcePath.Split($separator)[-1]).wim" }
        Else
        { $filename = "$($this.SourcePath.Split($separator)[-1])_$($this.Version).wim" }
        
        $foldername = $filename.Replace(".$($filename.Split(".")[-1])","")

        [bool]$download = $True
        If (($separator -eq "/") -Or ($this.SourcePath.Substring(0,2) -eq "\\"))
        {
            $targetdownload = "$($this.TempLocation)\$($this.SourcePath.Split($separator)[-1]).wim"
            $targetdownloadref = "$($this.TempLocation)\$($this.SourcePath.Split($separator)[-1]).version"
        }
        Else
        {
            If ($Hash)
            {
                $targetdownload = "$($this.SourcePath).wim"
                $targetdownloadref = "$($this.SourcePath).version"
            }
            Else
            {
                $targetdownload = "$($this.SourcePath)_$($this.Version).wim"
                $targetdownloadref = "$($this.SourcePath)_$($this.Version).version"
            }
            $download = $False
        }

        $referencefile = "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).version"
        $extractfolder = "$($this.TempLocation)\$($foldername)"

        if ($this.ensure -eq [Ensure]::Present)
        {

            $present = Invoke-TestPath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim"

            if ($present)
            {
                
                If ($Hash)
                {
                    If ($download)
                    {

                        Invoke-WebDownload -Source "$($this.SourcePath).wim" -Target $targetdownload -Verbose
                        $present = Invoke-TestPath -Path $targetdownload
                        If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }

                        Invoke-WebDownload -Source "$($this.SourcePath).version" -Target $targetdownloadref
                        $present = Invoke-TestPath -Path $targetdownloadref
                        If (-not($present)) { Write-Error "Cannot find path '$targetdownloadref' because it does not exist." ; Return }

                    }
                    Else
                    {

                        $present = Invoke-TestPath -Path $targetdownload
                        If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }

                    }
                }
                Else
                {
                    If ($download)
                    {

                        Invoke-WebDownload -Source "$($this.SourcePath)_$($this.Version).wim" -Target $targetdownload -Verbose
                        $present = Invoke-TestPath -Path $targetdownload
                        If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }

                    }
                }

                Invoke-RemovePath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim" -Verbose
                $present = Invoke-TestPath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim"
                If ($present) { Write-Error "Could not remove path '$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim'." ; Return }

                $oldname = $null
                $newname = $null
                If (-not ($Hash))
                {
                    $oldname = $targetdownload
                    $newname = $targetdownload.Replace("_$($this.Version)","")
                }

                If ($download)
                {
                    Copy-Item $targetdownload -Destination "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim" -Force -Verbose
                }
                Else
                {
                    If (-not ($Hash)) { Rename-Item -Path $oldname -NewName $newname -ErrorAction SilentlyContinue -Verbose:$False }
                    If ($Hash)
                    {
                        Copy-Item $targetdownload -Destination "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim" -Force -Verbose
                    }
                    Else
                    {
                        Copy-Item $newname -Destination "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim" -Force -Verbose
                    }
                    If (-not ($Hash)) { Rename-Item -Path $newname -NewName $oldname -ErrorAction SilentlyContinue -Verbose:$False }
                }

                If ($Hash)
                {
                    $this.version = Get-Content -Path $targetdownloadref
                }

                Set-Content -Path $referencefile -Value "$($this.Version)" -Verbose:$false
            }
            else
            {
                
                $oldname = $null
                $newname = $null
                If (-not ($Hash))
                {
                    $oldname = $targetdownload
                    $newname = $targetdownload.Replace("_$($this.Version)","")
                }

                If ($download)
                {
                    If ($Hash)
                    {

                        Invoke-WebDownload -Source "$($this.SourcePath).wim" -Target $targetdownload -Verbose
                        $present = Invoke-TestPath -Path $targetdownload
                        If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }

                        Invoke-WebDownload -Source "$($this.SourcePath).version" -Target $targetdownloadref
                        $present = Invoke-TestPath -Path $targetdownloadref
                        If (-not($present)) { Write-Error "Cannot find path '$targetdownloadref' because it does not exist." ; Return }

                    }
                    Else
                    {
                        Invoke-WebDownload -Source "$($this.SourcePath)_$($this.Version).wim" -Target $targetdownload -Verbose
                        $present = Invoke-TestPath -Path $targetdownload
                        If (-not($present)) { Write-Error "Cannot find path '$targetdownload' because it does not exist." ; Return }

                    }
                    $this.ImportOperatingSystem($targetdownload)
                }
                Else
                {
                    If (-not ($Hash)) { Rename-Item -Path $oldname -NewName $newname -ErrorAction SilentlyContinue -Verbose:$False }
                    If ($Hash)
                    {
                        $this.ImportOperatingSystem($targetdownload)
                    }
                    Else
                    {
                        $this.ImportOperatingSystem($newname)
                    }
                    If (-not ($Hash)) { Rename-Item -Path $newname -NewName $oldname -ErrorAction SilentlyContinue -Verbose:$False }
                }

                New-ReferenceFile -Path $referencefile -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath

                If ($Hash)
                {
                    $this.version = Get-Content -Path $targetdownloadref
                }

                Set-Content -Path $referencefile -Value "$($this.Version)"
            }
        }
        else
        {

            Invoke-RemovePath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
            $present = Invoke-TestPath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)"
            If ($present) { Write-Error "Cannot find path '$($this.PSDrivePath)\Operating Systems\$($this.Name)' because it does not exist." }

        }

    }

    [bool] Test()
    {

        [string]$separator = ""
        If ($this.SourcePath -like "*/*")
        { $separator = "/" }
        Else
        { $separator = "\" }

        If (-not ($this.version))
        {
            [bool]$download = $True
            If (($separator -eq "/") -Or ($this.SourcePath.Substring(0,2) -eq "\\"))
            { $targetdownloadref = "$($this.TempLocation)\$($this.SourcePath.Split($separator)[-1]).version" }
            Else
            { $targetdownloadref = "$($this.SourcePath).version" ; $download = $False }

            If ($download)
            {
                Invoke-WebDownload -Source "$($this.SourcePath).version" -Target $targetdownloadref
                $present = Invoke-TestPath -Path $targetdownloadref
                If (-not($present)) { Write-Error "Cannot find path '$targetdownloadref' because it does not exist." ; Exit }
            }
            $this.version = Get-Content -Path $targetdownloadref
        }

        $present = Invoke-TestPath -Path "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).wim"

        if (($present) -and ($this.ensure -eq [Ensure]::Present))
        {

            $match = Compare-Version -Source "$($this.PSDrivePath)\Operating Systems\$($this.Name)\$($this.SourcePath.Split($separator)[-1]).version" -Target $this.Version

            if (-not ($match))
            {
                Write-Verbose "$($this.Name) version has been updated on the pull server"
                $present = $false
            }
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

    [cMDTBuildOperatingSystem] Get()
    {
        return $this
    }

    [void] ImportOperatingSystem($OperatingSystem)
    {

        Import-MicrosoftDeploymentToolkitModule

        New-PSDrive -Name $this.PSDriveName -PSProvider "MDTProvider" -Root $this.PSDrivePath -Verbose:$false

        Try
        {
            
            $ErrorActionPreference = "Stop"
            Import-MDTOperatingSystem -Path $this.Path -SourceFile $OperatingSystem -DestinationFolder $this.Name -Verbose
            $ErrorActionPreference = "Continue"
        }
            Catch [Microsoft.Management.Infrastructure.CimException]
            {
                If ($_.FullyQualifiedErrorId -notlike "*ItemAlreadyExists*")
                {
                    throw $_
                }
            }
            Finally
            {
                
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
class cMDTBuildTaskSequence
{

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Key)]
    [string]$Name

    [DscProperty()]
    [string]$OperatingSystemPath

    [DscProperty()]
    [string]$WIMFileName

    [DscProperty(Mandatory)]
    [string]$ID

    [DscProperty(Mandatory)]
    [string]$PSDriveName

    [DscProperty(Mandatory)]
    [string]$PSDrivePath

    [void] Set()
    {

        if ($this.ensure -eq [Ensure]::Present)
        {
            $this.ImportTaskSequence()
        }
        else
        {
            Invoke-RemovePath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath -Verbose
        }
    }

    [bool] Test()
    {

        $present = Invoke-TestPath -Path "$($this.path)\$($this.name)" -PSDriveName $this.PSDriveName -PSDrivePath $this.PSDrivePath 
        
        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $present
        }
        else
        {
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

        $OperatingSystemFile = ""

        If ($this.OperatingSystemPath)
        {
            $OperatingSystemFile = $this.OperatingSystemPath
        }

        If ($this.WIMFileName)
        {
            $Directory = $this.Name.Replace(" x64","")
            $Directory = $Directory.Replace(" x32","")
            $OperatingSystemFiles = (Get-ChildItem -Path "$($this.PSDriveName):\Operating Systems\$($Directory)")
            ForEach ($OSFile in $OperatingSystemFiles)
            {
                If ($OSFile.Name -like "*$($this.WIMFileName)*")
                {
                    $OperatingSystemFile = "$($this.PSDriveName):\Operating Systems\$($Directory)\$($OSFile.Name)"
                }
            }
        }

        Import-MDTTaskSequence -path $this.Path -Name $this.Name -Template "Client.xml" -Comments "" -ID $this.ID -Version "1.0" -OperatingSystemPath $OperatingSystemFile -FullName "Windows User" -OrgName "Addlevel" -HomePage "about:blank" -Verbose
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
