function Get-AzurePowershellModule
{
    [cmdletbinding()]
    Param(
        [switch]$ShowVersion,
        [switch]$Install,
        [string]$Path=$null
    )
    BEGIN
    {
        If ($ShowVersion.IsPresent)
        {
            $Modules = Get-Module -ListAvailable
            $InstalledVersion = ($Modules | Where-Object {$_.Name -eq "Azure"}).Version.ToString()
            Write-Output "Installed: $InstalledVersion"
        }
        
    }
    PROCESS {
        Try
        {
            $WebSite = Invoke-WebRequest -Uri "https://github.com/Azure/azure-sdk-tools/releases/latest" -Method Get -TimeoutSec 30
        }
        Catch
        {
            Throw "Failed to get Web Content for Azure Powershell Module: $($_.Exception.Message)"
        }

        if ($ShowVersion.IsPresent)
        {
            $LatestVersion = ($WebSite.Links | Where-Object {$_.href -eq $WebSite.BaseResponse.ResponseUri.AbsolutePath}).innerText
            Write-Verbose "LatestVersion = $LatestVersion"
            Write-Output "Latest: $LatestVersion"
        }
        
        $DownloadURL = ($WebSite.Links | Where-Object {$_.InnerHTML -eq "Windows Standalone"}).href
        Write-Verbose "DownloadURL = $DownloadURL"

        If ($Path -ne $null)
        {
            if ((Test-Path $Path) -eq $false)
            {
                $OutFilePathRoot = (Get-Item $Path).Directory
            }
        }
        if ($OutFilePathRoot -eq $null)
        {
            $OutFilePathRoot = $env:TEMP
        }
        $OutFilePath = "$($OutFilePathRoot)\$($DownloadURL.Split("/")[-1])"
        Write-Verbose "OutFilePath = $($OutFilePath)"

        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutFilePath -Method Get -TimeoutSec 60

        $LogPath = $OutFilePath.Split(".")
        $LogPath[-1] = "log"
        $LogPath = $LogPath -join "."
        Write-Verbose "LogPath = $($LogPath)"

        If ($Install.IsPresent)
        {
            Start-Process $OutFilePath -ArgumentList "/quiet /norestart /log $($LogPath)" -Wait -PassThru
        }
        else
        {
            Write-Output "Azure Powershell Module downloaded to: $($OutFilePath)"
        }
    }
    END
    {
        If ($Install.IsPresent)
        {
            Remove-Item -Path $OutFilePath -Force -Verbose
        }
    }
}

#Get-AzurePowershellModule -Install -Verbose