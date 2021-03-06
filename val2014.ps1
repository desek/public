﻿Add-Type -AssemblyName System.Web
$UserAgent = "Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.120 Safari/537.36"
$Uri = "http://www.val.se/val/val2014/valnatt/R/rike/index.html"

While ($true)
{
    Try
    {
        $WebContent = Invoke-WebRequest -Uri $Uri -TimeoutSec 30 -UseBasicParsing -UserAgent $UserAgent -ErrorAction Stop
        $ContinueProcessing = $true
    }
    Catch
    {
        $ContinueProcessing = $false
    }
    If ($ContinueProcessing -eq $true)
    {
        $FormatedContent = $WebContent.Content.Substring($WebContent.Content.LastIndexOf("<body>"),$WebContent.Content.Length-$WebContent.Content.LastIndexOf("<body>"))
        $EndOfBody = $FormatedContent.LastIndexOf("</body>")
        $FormatedContent = $FormatedContent.Substring(0,$EndOfBody+7)

        $WebXML = [xml]([system.web.httputility]::htmldecode($FormatedContent))
        $DataTable = ((($WebXML.body.div.div.div.div | Where-Object {$_.Id -eq "mitten"}).div | Where-Object {$_.Id -eq "sida"}).table | Where-Object {$_.Class -eq "sorteringsbar_tabell"})[-1]

        $Headers = $DataTable.thead.tr.th.'#text' | Where-Object {$_ -ne "Område"}
        $Numbers = $DataTable.tbody.tr[-1].td.'#text'

        $i = 0
        $Data = @()
        Foreach ($Header in $Headers)
        {
            If ($Header -notin $Data.Parti)
            {
                $Props = [ordered]@{}
                $Props.Parti = $Header
                $Props.Procent = $Numbers[$i]
                $i++
                $Props.Antal= $Numbers[$i]
                $i++

                $Data += New-Object -TypeName PSObject -Property $Props
            }
        }

        Clear-Host
        $Data

        Start-Sleep -Seconds 60
    }
    Clear-Host
    Write-Output "Failed to get website. Retrying in 15 seconds."
    Start-Sleep -Seconds 15
}