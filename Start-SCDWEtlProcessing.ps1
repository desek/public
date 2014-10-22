function Start-SCDWEtlProcessing
{
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    [CmdletBinding()]
    Param(
        [String]$ComputerName,
        [PSCredential]$Credential,
        [ValidateScript({$_ -ge 4})]
        [int]$SleepTimer=120,
        [String[]]$JobTypes,
        [String]$DateFormat="HH:mm:ss",
        # TODO WRITE PROGRESS
        [switch]$WithProgress
    )
    BEGIN
    {
        # Verify Job Types
        $ValidJobTypes = @(
            "DWMaintenance",
            "MPSyncJob",
            "Extract",
            "Transform",
            "Load",
            "Process"
        )

        Throw "Valid JobTypes are: $($JobTypes -join ", ")"

        # Set Error Preference
        If ($PSBoundParameters.ContainsKey("ErrorAction"))
        {
            $ErrorActionPreference = $ErrorAction
        }
        # Set Verbose and/or Debug
        If ($PSBoundParameters.ContainsKey("Verbose"))
        {
            $PSDefaultParameterValues += @{"*:Verbose"=$true}
        }
        If ($PSBoundParameters.ContainsKey("Debug"))
        {
            $PSDefaultParameterValues += @{"*:Debug"=$true}
        }

        # Set PSDefaultParameter for ComputerName and Credential
        If ($PSBoundParameters.ContainsKey("ComputerName"))
        {
            $PSDefaultParameterValues += @{"*-SCDW*:ComputerName"=$ComputerName}
        }
        If ($PSBoundParameters.ContainsKey("Credential"))
        {
            $PSDefaultParameterValues += @{"*-SCDW*:Credential"=$Credential}
        }

        # Try to load SCSM DW module
        Try
        {
            $smDir = (Get-ItemProperty "HKLM:\Software\Microsoft\System Center\2010\Service Manager\Setup").InstallDirectory
            Import-Module "$smDir\Microsoft.EnterpriseManagement.Warehouse.Cmdlets.psd1"
        }
        Catch
        {
            Throw $_.Exception.Message
        }
    }

    PROCESS
    {
        # Get all SCSM DW Jobs
        Try
        {
            Write-Verbose "[$(Get-Date -Format $DateFormat)] Trying to get SCDW Jobs."
            $Jobs = Get-SCDWJob
        }
        Catch
        {
            Throw $_.Exception.Message
        }
        Write-Verbose "[$(Get-Date -Format $DateFormat)] Successfully got $($Jobs.Count) SCDW Job(s)."

        # Disable and Stop all SCSM DW Jobs
        Write-Verbose "[$(Get-Date -Format $DateFormat)] Trying to Disable and Stop $($Jobs.Count) SCDW Job(s)."
        $ErrorCount = 0        
        Foreach ($Job in $Jobs)
        {
            Try
            {
                Disable-SCDWJobSchedule -JobName $Job.Name
                Disable-SCDWJob -JobName $Job.Name
                Stop-SCDWJob -JobName $Job.Name
                Start-Sleep -Seconds ($SleepTimer/4)
            }
            Catch
            {
                Write-Error $_.Exception.Message
                $ErrorCount++
            }
        }
        
        Write-Verbose "[$(Get-Date -Format $DateFormat)] Disabled and Stopped $($Jobs.Count) SCDW Job(s) with $($ErrorCount) Error(s)."
        Remove-Variable ErrorCount

        Write-Verbose "[$(Get-Date -Format $DateFormat)] Sleeping for $($SleepTimer*2) second(s)."
        Start-Sleep -Seconds ($SleepTimer*2)

        # Process all SCSM DW Jobs
        $JobCurrent = 0
        $JobCount = $Jobs.Count
        $JobTypeCurrent = 0
        $JobTypeCount = $JobTypes.Count
        Foreach ($JobType in $JobTypes)
        {
            $JobTypeStart = Get-Date
            $JobTypeCurrent++
            $JobTypeJobCurrent = 0
            $JobTypeJobCount = ($Jobs | Where-Object {$_.Name -like "$($JobType)*"}).Count
            Write-Verbose "[$(Get-Date -Format $DateFormat)] $($JobType): Starting ($($JobTypeCurrent)/$($JobTypeCount))"
            Foreach ($Job in ($Jobs | Where-Object {$_.Name -like "$($JobType)*"}))
            {
                $JobTypeJobStart = Get-Date
                $JobTypeJobCurrent++
                Write-Verbose "[$(Get-Date -Format $DateFormat)] $($Job.Name): Starting ($($JobTypeJobCurrent)/$($JobTypeJobCount))"
                Enable-SCDWJob -JobName $Job.Name
                Write-Verbose "[$(Get-Date -Format $DateFormat)] Sleeping for $SleepTimer second(s)."
                Start-Sleep -Seconds $SleepTimer
                Start-SCDWJob -JobName $Job.Name
                do {
                    Write-Verbose "[$(Get-Date -Format $DateFormat)] $($Job.Name): Processing ($($JobTypeJobCurrent)/$($JobTypeJobCount))"
                    Start-Sleep -Seconds $SleepTimer
                } while ((Get-SCDWJob -JobName $Job.Name).Status -eq "Running")
                $JobTypeJobTimeSpan = New-TimeSpan -Start $JobTypeJobStart -End (Get-Date)
                Write-Verbose "[$(Get-Date -Format $DateFormat)] $($Job.Name): Completed in $($JobTypeJobTimeSpan.ToString()) ($($JobTypeJobCurrent)/$($JobTypeJobCount))"
            }
            $JobTypeTimeSpan = New-TimeSpan -Start $JobTypeStart -End (Get-Date)
            Write-Verbose "[$(Get-Date -Format $DateFormat)] $($JobType): Completed in $($JobTypeTimeSpan.ToString()) ($($JobTypeCurrent)/$($JobTypeCount))"
        }

        # Update SCSM DW Job Status
        Try
        {
            $Jobs = Get-SCDWJob
        }
        Catch
        {
            Throw $_.Exception.Message
        }

        # Enable all SCSM DW Jobs
        Write-Verbose "[$(Get-Date -Format $DateFormat)] Trying to Enable $($Jobs.Count) SCDW Job(s)."
        $ErrorCount = 0
        Foreach ($Job in $Jobs)
        {
            Try
            {
                If ($Job.IsEnabled -eq $false)
                {
                    Enable-SCDWJob -JobName $Job.Name
                }
                Enable-SCDWJobSchedule -JobName $Job.Name
            }
            Catch
            {
                Write-Error $_.Exception.Message
            }
        }

        Write-Verbose "[$(Get-Date -Format $DateFormat)] Enabled $($Jobs.Count) SCDW Job(s) with $($ErrorCount) Error(s)."
        Remove-Variable ErrorCount
    }
    END
    {
    }
}