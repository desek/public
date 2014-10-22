function Get-MSFT2014TechnicalPreview
{
    [CmdletBinding()]
    Param(
        [ValidateScript({Test-Path $_})]
        [string]$Path=(Get-Location),
        [Switch]$WithProgress
    )
    BEGIN
    {
        
        $WebClient = New-Object System.Net.WebClient
        $Uris = @{
            rsatWin10x64 = "http://download.microsoft.com/download/2/7/9/27916E59-B7B5-4462-B95F-89DF4CE291D3/WindowsTH-KB2693643-x64.msu"
            rsatWin10x86 = "http://download.microsoft.com/download/2/7/9/27916E59-B7B5-4462-B95F-89DF4CE291D3/WindowsTH-KB2693643-x86.msu"
            WindowsServer = "http://care.dlservice.microsoft.com/dl/download/F/5/7/F574727C-B145-4A7D-B85B-11C4E8DC894B/9841.0.140912-1613.FBL_RELEASE_SERVER_OEM_X64FRE_EN-US.ISO"
            SCDPM = "http://care.dlservice.microsoft.com/dl/download/evalx/sctp2014/SCTP_SCDPM.exe"
            SCOM = "http://care.dlservice.microsoft.com/dl/download/evalx/sctp2014/SCTP_SCOM.exe"
            SCVMM = "http://care.dlservice.microsoft.com/dl/download/evalx/sctp2014/SCTP_SCVMM.exe"
            SCO = "http://care.dlservice.microsoft.com/dl/download/evalx/sctp2014/SCTP_SCO.exe"
            SCSM = "http://care.dlservice.microsoft.com/dl/download/evalx/sctp2014/SCTP_SCSM.exe"
        }

        If ($WithProgress)
        {
            $DownloadSizeTotal = 0
            $i = 0
            Foreach ($Uri in $Uris.Keys)
            {
                $i++
                Write-Progress -Id 1 -Activity 'Calculating Total Download Size' -Status "Item $i of $($Uris.Count) - $Uri" -PercentComplete (($i/$Uris.Count) * 100)

                $WebRequest = [System.Net.WebRequest]::Create($Uris[$Uri])
                $WebResponse = $WebRequest.GetResponse()
                $DownloadSizeTotal += $WebResponse.ContentLength
                $WebResponse.Close()
                $WebRequest.Abort()
            }
            $DownloadSizeTotalMB = [System.Math]::Round(($DownloadSizeTotal/1024/1024),2)
        }
    }
    PROCESS
    {
        $i = 0
        $DownloadCurrentTotal = 0
        $DownloadCurrentTotalMB = 0
        Foreach ($Uri in $Uris.Keys)
        {
            $i++
            Write-Host "$($Uri): Starting download"
            $FileName = $Uris[$Uri].Split("/")[-1]
            $OutFile = "$Path\$FileName"
            
            $WebRequest = [net.WebRequest]::Create($Uris[$Uri])
            $WebResponse = $WebRequest.GetResponse()
            $DownloadSize = $WebResponse.ContentLength
            $WebResponse.Close()
            $WebRequest.Abort()
            $DownloadSizeMB = [System.Math]::Round(($DownloadSize/1024/1024),2)
            
            Try
            {
                $WebClient.DownloadFileAsync($Uris[$Uri],$OutFile)
            }
            Catch
            {
                Write-Host "$($Uri): Download failed" -ForegroundColor Red
            }

            While ((Get-Item $OutFile).Length -lt $DownloadSize) {
                $DownloadCurrentSize = (Get-Item $OutFile).Length
                $DownloadCurrentSizeMB = [System.Math]::Round(($DownloadCurrentSize/1024/1024),2)
                $DownloadCurrentTotal = $DownloadedSize + $DownloadCurrentSize
                $DownloadCurrentTotalMB = [System.Math]::Round(($DownloadCurrentTotal/1024/1024),2)
                If ($WithProgress)
                {
                    Write-Progress -id 1 -Activity "Downloading Item $i of $($Uris.Count)" -Status "$DownloadCurrentTotalMB of $DownloadSizeTotalMB MB" -PercentComplete (($DownloadCurrentTotal/$DownloadSizeTotal) * 100)
                    Write-Progress -id 2 -Activity "Downloading $Uri" -Status "$DownloadCurrentSizeMB of $DownloadSizeMB MB" -PercentComplete (((Get-Item $OutFile).Length / $DownloadSize)*100)
                    Start-Sleep 1
                }
            }
            $DownloadedSize = $DownloadedSize + (Get-Item $OutFile).Length
            Write-Host "$($Uri): Download completed" -ForegroundColor Green
        }
    }
    END {}
}